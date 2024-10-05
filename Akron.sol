// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Akron {
    struct Transaction {
        address target;
        uint value;
        bytes data;
        uint256 confirmations;
        bool executed;
        address proposedBy;
    }

    mapping(uint => Transaction) public transactons;
    mapping(uint => mapping(address => bool)) public confirmations;
    mapping(address => bool) public pausedWallets;
    mapping(address => bool) public blacklistedWallets;
    mapping(address => bool) public isOwner;

    address[] public owners;
    uint public requiredConfirmations;
    uint public actionCounter;
    uint public totalSupplyAkron;
    uint public totalRevenue;
    uint public claimInterval = 2 hours;
    uint public lastClaimedTime;

    uint256 totalDistributed;

    event ActionProposed(uint actionId, address target, bytes data);
    event ActionConfirmed(uint actionId, address owner);
    event ActionExecuted(
        uint actionId,
        address target,
        bytes data,
        bool status
    );
    event WalletPaused(address wallet);
    event WalletUnpaused(address wallet);
    event WalletBlacklisted(address wallet);
    event RevenueDistributed(address wallet, uint256 amount, bool status);

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

        for (uint256 i; i < _owners.length; i++) {
            // require(_owners[i] != address(0), "Invalid owner");
            // require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
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
        require(!transactons[actionId].executed, "Action already executed");
        _;
    }

    modifier notBlacklisted(address wallet) {
        require(!blacklistedWallets[wallet], "Wallet is blacklisted");
        _;
    }

    function proposeAction(
        address target,
        bytes memory data,
        uint _value
    ) external onlyOwner {
        Transaction storage newAction = transactons[actionCounter];
        newAction.target = target;
        newAction.data = data;
        newAction.proposedBy = msg.sender;
        newAction.value = _value;

        emit ActionProposed(actionCounter, target, data);
        actionCounter++;
    }

    function approveAction(
        uint actionId
    ) external onlyOwner notExecuted(actionId) {
        require(!confirmations[actionId][msg.sender], "Action confirmed");

        confirmations[actionId][msg.sender] = true;
        Transaction storage action = transactons[actionId];

        action.confirmations++;

        emit ActionConfirmed(actionId, msg.sender);

        if (action.confirmations >= requiredConfirmations) {
            executeAction(actionId);
        }
    }

    function executeAction(
        uint actionId
    ) public onlyOwner notExecuted(actionId) {
        Transaction storage transaction = transactons[actionId];

        require(
            transaction.confirmations >= requiredConfirmations,
            "low confirmations"
        );

        (bool success, ) = transaction.target.call{value: transaction.value}(transaction.data);
        // require(success, "Execution failed");

        transaction.executed = success;

        emit ActionExecuted(actionId, transaction.target, transaction.data, success);
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
        claimInterval = newInterval;
    }

    function distributeRevenue(
        address[] calldata holders,
        uint[] calldata balances
    ) external onlySelf {
        require(holders.length == balances.length, "Mismatched Size");

        require(
            block.timestamp >= lastClaimedTime + claimInterval,
            "Claim interval error"
        );

        // Distribute revenue based on balances
        for (uint256 i; i < holders.length; i++) {
            address holder = holders[i];

            // Skip holders with paused or blacklisted wallets
            if (!pausedWallets[holder] && !blacklistedWallets[holder]) {
                uint holderBalance = balances[i];
                if (holderBalance > 0) {
                    // Skip if the holder has no balance

                    // Calculate the revenue share
                    uint revenueShare = (holderBalance * totalRevenue) /
                        totalSupplyAkron;
                    if (
                        revenueShare > 0 &&
                        totalDistributed + revenueShare <= address(this).balance
                    ) {
                        totalDistributed += revenueShare;
                        // Transfer revenue share to the holder
                        (bool success, ) = holder.call{value: revenueShare}("");
                        emit RevenueDistributed(holder, revenueShare, success);
                    }
                }
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
        for (uint256 i; i < owners.length; i++) {
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
}
