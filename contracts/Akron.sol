// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Akron {
    mapping(address => bool) public pausedWallets;
    mapping(address => bool) public blacklistedWallets;
    address multiSignOwner;

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

    constructor(address _multiSignOwner, uint _totalSupplyAkron) {
        multiSignOwner = _multiSignOwner;
        totalSupplyAkron = _totalSupplyAkron;
    }

    modifier onlyOwner() {
        require(msg.sender == multiSignOwner, "Not an owner");
        _;
    }

    modifier notBlacklisted(address wallet) {
        require(!blacklistedWallets[wallet], "Wallet is blacklisted");
        _;
    }

    function pauseWallet(address wallet) external onlyOwner {
        pausedWallets[wallet] = true;
        emit WalletPaused(wallet);
    }

    function unpauseWallet(address wallet) external onlyOwner {
        pausedWallets[wallet] = false;
        emit WalletUnpaused(wallet);
    }

    function blacklistWallet(address wallet) external onlyOwner {
        blacklistedWallets[wallet] = true;
        emit WalletBlacklisted(wallet);
    }

    function unblacklistWallet(address wallet) external onlyOwner {
        blacklistedWallets[wallet] = false;
        emit WalletBlacklisted(wallet);
    }

    function updateClaimInterval(uint256 newInterval) external onlyOwner {
        claimInterval = newInterval;
    }

    function distributeRevenue(
        address[] calldata holders,
        uint[] calldata balances
    ) external onlyOwner {
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
                // Skip if the holder has no balance
                if (holderBalance > 0) {
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

    receive() external payable {
        totalRevenue += msg.value;
    }
}
