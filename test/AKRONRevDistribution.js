const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Akron Merged Contract with Multisig Governance", function () {
  let owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2;
  let aKRONRevDistribution, kronosMultiSig;
  const initialSupply = ethers.parseEther("1000");

  beforeEach(async function () {
    [owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2] =
      await ethers.getSigners();

    const KronosMultiSig = await ethers.getContractFactory("KronosMultiSig");

    kronosMultiSig = await KronosMultiSig.deploy(
      [owner1.address, owner2.address, owner3.address],
      2
    );
    const AKRONRevDistribution = await ethers.getContractFactory("AKRONRevDistribution");
    aKRONRevDistribution = await AKRONRevDistribution.deploy(
      await kronosMultiSig.getAddress(),
      initialSupply
    ); // 2 confirmations needed
  });

  describe("Multisig and Governance", function () {
    it("should allow owners to propose and execute a pause wallet action", async function () {
      const pauseWalletData = aKRONRevDistribution.interface.encodeFunctionData(
        "pauseWallets",
        [[walletToPause.address]]
      );

      // Propose and approve pause action by two owners
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await aKRONRevDistribution.getAddress(), pauseWalletData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      const isPaused = await aKRONRevDistribution.pausedWallets(walletToPause.address);
      expect(isPaused).to.equal(true);
    });

    // it("should distribute revenue proportionally to token holders", async function () {
    //   // Token distribution to owners
    //   await akron.transfer(owner1.address, ethers.parseEther("600"));
    //   await akron.transfer(owner2.address, ethers.parseEther("400"));

    //   // Send funds to the contract
    //   await owner1.sendTransaction({ to: await akron.getAddress(), value: ethers.parseEther("10") });

    //   // Propose and approve revenue distribution
    //   const distributeRevenueData = akron.interface.encodeFunctionData("distributeRevenue", []);
    //   await akron.connect(owner1).proposeTransaction(await akron.getAddress(), distributeRevenueData);
    //   await akron.connect(owner2).approveTransaction(1);

    //   // Check balances after revenue distribution
    //   const balance1 = await ethers.provider.getBalance(owner1.address);
    //   const balance2 = await ethers.provider.getBalance(owner2.address);

    //   expect(balance1).to.be.closeTo(ethers.parseEther("6"), ethers.parseEther("0.1"));
    //   expect(balance2).to.be.closeTo(ethers.parseEther("4"), ethers.parseEther("0.1"));
    // });

    it("should allow pausing and unpausing a wallet", async function () {
      const pauseWalletData = aKRONRevDistribution.interface.encodeFunctionData(
        "pauseWallets",
        [[walletToPause.address]]
      );

      // Propose and approve pausing a wallet
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await aKRONRevDistribution.getAddress(), pauseWalletData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      let isPaused = await aKRONRevDistribution.pausedWallets(walletToPause.address);
      expect(isPaused).to.equal(true);

      const unpauseWalletData = aKRONRevDistribution.interface.encodeFunctionData(
        "unpauseWallets",
        [[walletToPause.address]]
      );

      // Propose and approve unpausing the wallet
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await aKRONRevDistribution.getAddress(), unpauseWalletData, 0);
      //   two approval
      await kronosMultiSig.connect(owner2).approveTransaction(1);
      await kronosMultiSig.connect(owner3).approveTransaction(1);

      isPaused = await aKRONRevDistribution.pausedWallets(walletToPause.address);
      expect(isPaused).to.equal(false);
    });

    it("should allow updating the claim interval", async function () {
      const newInterval = 3600; // 1 hour in seconds
      const updateClaimIntervalData = aKRONRevDistribution.interface.encodeFunctionData(
        "updateClaimInterval",
        [newInterval]
      );

      // Propose and approve updating the claim interval
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          updateClaimIntervalData,
          0
        );
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      const claimInterval = await aKRONRevDistribution.claimInterval();
      expect(claimInterval).to.equal(newInterval);
    });

    // it("should allow emergency pause of revenue distribution", async function () {
    //   const emergencyPauseData = akron.interface.encodeFunctionData(
    //     "pauseRevenueDistribution",
    //     []
    //   );

    //   // Propose and approve emergency pausing revenue distribution
    //   await akron
    //     .connect(owner1)
    //     .proposeTransaction(await akron.getAddress(), emergencyPauseData);
    //   await akron.connect(owner2).approveTransaction(0);
    //   await akron.connect(owner3).approveTransaction(0);

    //   const isPaused = await akron.revenueDistributionPaused();
    //   expect(isPaused).to.equal(true);

    //   const unpauseRevenueData = akron.interface.encodeFunctionData(
    //     "unpauseRevenueDistribution",
    //     []
    //   );

    //   // Propose and approve unpausing revenue distribution
    //   await akron
    //     .connect(owner1)
    //     .proposeTransaction(await akron.getAddress(), unpauseRevenueData);
    //   await akron.connect(owner2).approveTransaction(1);
    //   await akron.connect(owner3).approveTransaction(1);

    //   const isStillPaused = await akron.revenueDistributionPaused();
    //   expect(isStillPaused).to.equal(false);
    // });
    it("Should successfully blacklist a wallet", async function () {
      // Propose blacklisting addr1
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          aKRONRevDistribution.interface.encodeFunctionData("blacklistWallets", [
            [holder1.address],
          ]),
          0
        );

      // Approve by 2 owners to reach required confirmations
      await kronosMultiSig.connect(owner1).approveTransaction(0); // owner confirms
      await kronosMultiSig.connect(owner2).approveTransaction(0); // addr2 confirms and executes

      // Check if holder1 is blacklisted
      const isBlacklisted = await aKRONRevDistribution.blacklistedWallets(holder1.address);
      expect(isBlacklisted).to.be.true;
    });

    it("Should successfully unblacklist a wallet", async function () {
      // First, blacklist holder1
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          aKRONRevDistribution.interface.encodeFunctionData("blacklistWallets", [
            [holder1.address],
          ]),
          0
        );
      await kronosMultiSig.connect(owner1).approveTransaction(0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);

      // Confirm holder1 is blacklisted
      let isBlacklisted = await aKRONRevDistribution.blacklistedWallets(holder1.address);
      expect(isBlacklisted).to.be.true;

      // Propose unblacklisting holder1
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          aKRONRevDistribution.interface.encodeFunctionData("unblacklistWallets", [
           [ holder1.address],
          ]),
          0
        );

      // Approve the unblacklist action
      await kronosMultiSig.connect(owner1).approveTransaction(1);
      await kronosMultiSig.connect(owner2).approveTransaction(1);

      // Check if holder1 is unblacklisted
      isBlacklisted = await aKRONRevDistribution.blacklistedWallets(holder1.address);
      expect(isBlacklisted).to.be.false;
    });

    it("Should skip blacklisted wallets during revenue distribution", async function () {
      // Sending some ETH to the contract for distribution
      await owner1.sendTransaction({
        to: await aKRONRevDistribution.getAddress(),
        value: ethers.parseEther("10"),
      });

      const holder1BalanceBefore = await ethers.provider.getBalance(
        holder1.address
      );
      const holder2BalanceBefore = await ethers.provider.getBalance(
        holder2.address
      );
      // Blacklist addr1
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          aKRONRevDistribution.interface.encodeFunctionData("blacklistWallets", [
            [holder1.address],
          ]),
          0
        );
      await kronosMultiSig.connect(owner1).approveTransaction(0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);

      // Confirm addr1 is blacklisted
      const isBlacklisted = await aKRONRevDistribution.blacklistedWallets(holder1.address);
      expect(isBlacklisted).to.be.true;

      // Define holders and balances for revenue distribution
      const holders = [holder1.address, holder2.address];
      const balances = [ethers.parseEther("500"), ethers.parseEther("500")]; // Both hold 50% of the total supply

      // Propose revenue distribution action
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(
          await aKRONRevDistribution.getAddress(),
          aKRONRevDistribution.interface.encodeFunctionData("distributeRevenue", [
            holders,
            balances,
          ]),
          0
        );

      // Approve and execute the revenue distribution action
      await kronosMultiSig.connect(owner1).approveTransaction(1);
      await kronosMultiSig.connect(owner2).approveTransaction(1);

      const contractBalance = await ethers.provider.getBalance(
        await aKRONRevDistribution.getAddress()
      );

      // Verify that holder1 did not receive any funds (as it's blacklisted)
      const holder1BalanceAfter = await ethers.provider.getBalance(
        holder1.address
      );
      expect(holder1BalanceAfter).to.equal(holder1BalanceBefore); // holder1 should receive no ETH

      // Verify that addr2 received the funds
      const holder2BalanceAfter = await ethers.provider.getBalance(
        holder2.address
      );
      expect(holder2BalanceAfter).to.be.above(
        holder2BalanceBefore + contractBalance / 2n
      ); // holder2 should receive full 10 ETH
    });
  });
});
