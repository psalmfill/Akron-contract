// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Akron {
    // Mapping to track paused wallets
    mapping(address => bool) public pausedWallets;

    // Mapping to track blacklisted wallets
    mapping(address => bool) public blacklistedWallets;

    // The address of the contract's multi-signature owner
    address multiSignOwner;

    // Total supply of Akron tokens
    uint public totalSupplyAkron;

    // Total revenue stored in the contract for distribution
    uint public totalRevenue;

    // Interval time required between revenue distributions (2 hours by default)
    uint public claimInterval = 2 hours;

    // Timestamp of the last revenue distribution event
    uint public lastClaimedTime;

    // Total amount of revenue distributed to token holders
    uint256 totalDistributed;

    // Events to track actions and state changes
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

    /**
     * @dev Constructor that sets the multi-signature owner and total supply of Akron tokens.
     * @param _multiSignOwner The address of the owner.
     * @param _totalSupplyAkron The total supply of Akron tokens.
     */
    constructor(address _multiSignOwner, uint _totalSupplyAkron) {
        multiSignOwner = _multiSignOwner;
        totalSupplyAkron = _totalSupplyAkron;
    }

    // Modifier to ensure that only the multi-signature owner can execute certain functions
    modifier onlyOwner() {
        require(msg.sender == multiSignOwner, "Not an owner");
        _;
    }

    // Modifier to prevent actions on blacklisted wallets
    modifier notBlacklisted(address wallet) {
        require(!blacklistedWallets[wallet], "Wallet is blacklisted");
        _;
    }

    /**
     * @dev Pauses a wallet, preventing it from receiving revenue.
     * @param wallet The address of the wallet to pause.
     */
    function pauseWallet(address wallet) external onlyOwner {
        pausedWallets[wallet] = true;
        emit WalletPaused(wallet);
    }

    /**
     * @dev Unpauses a wallet, allowing it to receive revenue again.
     * @param wallet The address of the wallet to unpause.
     */
    function unpauseWallet(address wallet) external onlyOwner {
        pausedWallets[wallet] = false;
        emit WalletUnpaused(wallet);
    }

    /**
     * @dev Blacklists a wallet, permanently blocking it from receiving revenue.
     * @param wallet The address of the wallet to blacklist.
     */
    function blacklistWallet(address wallet) external onlyOwner {
        blacklistedWallets[wallet] = true;
        emit WalletBlacklisted(wallet);
    }

    /**
     * @dev Removes a wallet from the blacklist, allowing it to receive revenue again.
     * @param wallet The address of the wallet to unblacklist.
     */
    function unblacklistWallet(address wallet) external onlyOwner {
        blacklistedWallets[wallet] = false;
        emit WalletBlacklisted(wallet);
    }

    /**
     * @dev Updates the time interval between revenue distributions.
     * @param newInterval The new claim interval in seconds.
     */
    function updateClaimInterval(uint256 newInterval) external onlyOwner {
        claimInterval = newInterval;
    }

    /**
     * @dev Distributes the total revenue among holders based on their token balances.
     * Skips blacklisted or paused wallets.
     * @param holders The list of token holder addresses.
     * @param balances The list of token balances corresponding to the holders.
     */
    function distributeRevenue(
        address[] calldata holders,
        uint[] calldata balances
    ) external onlyOwner {
        require(holders.length == balances.length, "Mismatched Size");

        // Ensure the required claim interval has passed
        require(
            block.timestamp >= lastClaimedTime + claimInterval,
            "Claim interval error"
        );

        // Loop through holders and distribute revenue
        for (uint256 i; i < holders.length; i++) {
            address holder = holders[i];

            // Skip holders with paused or blacklisted wallets
            if (!pausedWallets[holder] && !blacklistedWallets[holder]) {
                uint holderBalance = balances[i];

                // Skip holders with zero balances
                if (holderBalance > 0) {
                    // Calculate the revenue share for each holder
                    uint revenueShare = (holderBalance * totalRevenue) /
                        totalSupplyAkron;

                    // Ensure the revenue share is valid and within the contract's balance
                    if (
                        revenueShare > 0 &&
                        totalDistributed + revenueShare <= address(this).balance
                    ) {
                        totalDistributed += revenueShare;

                        // Transfer the revenue share to the holder
                        (bool success, ) = holder.call{value: revenueShare}("");
                        emit RevenueDistributed(holder, revenueShare, success);
                    }
                }
            }
        }

        // Update the last claimed time
        lastClaimedTime = block.timestamp;
    }

    /**
     * @dev Allows the contract to receive ETH and increase the total revenue.
     */
    receive() external payable {
        totalRevenue += msg.value;
    }
}
