// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Akron {
    struct Action {
        address target;
        bytes data;
        uint confirmations;
        bool executed;
    }

    mapping(uint => Action) public actions;
    mapping(uint => mapping(address => bool)) public confirmations;
    mapping(address => bool) public pausedWallets;
    mapping(address => bool) public blacklistedWallets;
    mapping(address => bool) public isOwner;
    mapping(address => uint) public akronBalances;

    address[] public owners;
    // Array to store holder addresses for iteration purposes
    address[] public holderAddresses;

    uint public requiredConfirmations;
    uint public actionCounter;
    uint public totalSupplyAkron;
    uint public totalRevenue;
    uint public claimInterval = 2 hours;
    uint public lastClaimedTime;

    event ActionProposed(uint actionId, address target, bytes data);
    event ActionConfirmed(uint actionId, address owner);
    event ActionExecuted(uint actionId, address target, bytes data);
    event WalletPaused(address wallet);
    event WalletUnpaused(address wallet);
    event WalletBlacklisted(address wallet);

    constructor(
        address[] memory _owners,
        uint _requiredConfirmations,
        uint _totalSupplyAkron
    ) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 &&
                _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmations = _requiredConfirmations;
        totalSupplyAkron = _totalSupplyAkron;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlySelf() {
        require(
            msg.sender == address(this),
            "Only the contract can call this function"
        );
        _;
    }

    modifier notExecuted(uint actionId) {
        require(!actions[actionId].executed, "Action already executed");
        _;
    }

    modifier notBlacklisted(address wallet) {
        require(!blacklistedWallets[wallet], "Wallet is blacklisted");
        _;
    }

    function proposeAction(
        address target,
        bytes memory data
    ) external onlyOwner {
        Action storage newAction = actions[actionCounter];
        newAction.target = target;
        newAction.data = data;
        newAction.confirmations = 0;
        newAction.executed = false;

        emit ActionProposed(actionCounter, target, data);
        actionCounter++;
    }

    function approveAction(
        uint actionId
    ) external onlyOwner notExecuted(actionId) {
        require(
            !confirmations[actionId][msg.sender],
            "Action already confirmed by this owner"
        );

        confirmations[actionId][msg.sender] = true;
        actions[actionId].confirmations++;

        emit ActionConfirmed(actionId, msg.sender);

        if (actions[actionId].confirmations >= requiredConfirmations) {
            executeAction(actionId);
        }
    }

    function executeAction(
        uint actionId
    ) public onlyOwner notExecuted(actionId) {
        require(
            actions[actionId].confirmations >= requiredConfirmations,
            "Not enough confirmations"
        );

        Action storage action = actions[actionId];
        (bool success, ) = action.target.call(action.data);
        require(success, "Action execution failed");

        action.executed = true;

        emit ActionExecuted(actionId, action.target, action.data);
    }

    function pauseWallet(address wallet) external onlySelf {
        pausedWallets[wallet] = true;
        emit WalletPaused(wallet);
    }

    function unpauseWallet(address wallet) external onlySelf {
        pausedWallets[wallet] = false;
        emit WalletUnpaused(wallet);
    }

    function blacklistWallet(address wallet) external onlySelf {
        blacklistedWallets[wallet] = true;
        emit WalletBlacklisted(wallet);
    }

    function unblacklistWallet(address wallet) external onlySelf {
        blacklistedWallets[wallet] = false;
        emit WalletBlacklisted(wallet);
    }

    function updateClaimInterval(uint256 newInterval) external onlySelf {
        claimInterval = newInterval; // Update the claim interval
    }

    function distributeRevenue() external onlySelf {
        require(
            block.timestamp >= lastClaimedTime + claimInterval,
            "Claim interval not met"
        );

        uint contractBalance = address(this).balance;

        require(
            contractBalance >= totalRevenue,
            "Not enough balance to distribute"
        );

        // Iterate over holder addresses and distribute revenue based on balances
        for (uint i = 0; i < holderAddresses.length; i++) {
            address holder = holderAddresses[i];

            // Skip holders with paused or blacklisted wallets
            if (pausedWallets[holder] || blacklistedWallets[holder]) continue;

            uint holderBalance = akronBalances[holder]; // Get balance from mapping
            if (holderBalance == 0) continue; // Skip if the holder has no balance

            // Calculate the revenue share
            uint revenueShare = (holderBalance * totalRevenue) /
                totalSupplyAkron;
            if (revenueShare > 0) {
                // Transfer revenue share to the holder
                (bool success, ) = holder.call{value: revenueShare}("");
                require(success, "Transfer to holder failed");
            }
        }

        lastClaimedTime = block.timestamp;
    }

    function addOwner(address newOwner) external onlySelf {
        require(!isOwner[newOwner], "Already an owner");
        isOwner[newOwner] = true;
        owners.push(newOwner);
    }

    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "Not an owner");
        isOwner[owner] = false;

        // Remove owner from array
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
    }

    receive() external payable {
        totalRevenue += msg.value;
    }

    function addHolders(
        address[] memory holders,
        uint[] memory balances
    ) external onlySelf {
        require(
            holders.length == balances.length,
            "Holders and balances length mismatch"
        );

        for (uint i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint balance = balances[i];

            // Only add holder if their balance is greater than zero
            if (balance > 0 && akronBalances[holder] == 0) {
                holderAddresses.push(holder); // Add holder to the array
            }

            // Set the holder's balance
            akronBalances[holder] = balance;
        }
    }

    function removeHolders(address[] memory holders) external onlySelf {
        for (uint i = 0; i < holders.length; i++) {
            address holder = holders[i];

            // Only remove holder if their balance is zero
            if (akronBalances[holder] == 0) {
                for (uint j = 0; j < holderAddresses.length; j++) {
                    if (holderAddresses[j] == holder) {
                        holderAddresses[j] = holderAddresses[
                            holderAddresses.length - 1
                        ]; // Move last element to the deleted spot
                        holderAddresses.pop(); // Remove the last element
                        break;
                    }
                }
            }
        }
    }
}
