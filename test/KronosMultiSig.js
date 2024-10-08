const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Akron Multisig Governance", function () {
  let owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2;
  let kronosMultiSig;
  const initialSupply = ethers.parseEther("1000");

  beforeEach(async function () {
    [owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2] =
      await ethers.getSigners();

    const KronosMultiSig = await ethers.getContractFactory("KronosMultiSig");
    kronosMultiSig = await KronosMultiSig.deploy(
      [owner1.address, owner2.address, owner3.address],
      2
    ); // 2 confirmations needed
  });

  describe("Multisig and Governance", function () {
    it("should allow revoke a transaction", async function () {
      const addOwnerData = kronosMultiSig.interface.encodeFunctionData("addOwner", [
        nonOwner.address,
      ]);

      // Propose and approve adding a new owner
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await kronosMultiSig.getAddress(), addOwnerData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);

      const transaction = await kronosMultiSig.transactions(0);
      await kronosMultiSig.connect(owner2).revokeTransactionApproval(0);

      const newTransaction = await kronosMultiSig.transactions(0);
      expect(newTransaction.confirmations).to.equal(0n);
    });

    it("should allow adding a new owner", async function () {
      const addOwnerData = kronosMultiSig.interface.encodeFunctionData("addOwner", [
        nonOwner.address,
      ]);

      // Propose and approve adding a new owner
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await kronosMultiSig.getAddress(), addOwnerData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      const isOwner = await kronosMultiSig.isOwner(nonOwner.address);
      expect(isOwner).to.equal(true);
    });

    it("should allow removing an owner", async function () {
      const addOwnerData = kronosMultiSig.interface.encodeFunctionData("addOwner", [
        nonOwner.address,
      ]);

      // Add the non-owner first
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await kronosMultiSig.getAddress(), addOwnerData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      const removeOwnerData = kronosMultiSig.interface.encodeFunctionData(
        "removeOwner",
        [nonOwner.address]
      );

      // Propose and approve removing the owner
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await kronosMultiSig.getAddress(), removeOwnerData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(1);
      await kronosMultiSig.connect(owner3).approveTransaction(1);

      const isOwner = await kronosMultiSig.isOwner(nonOwner.address);
      expect(isOwner).to.equal(false);
    });

    it("should allow withdrawal of contract balance", async function () {
      await owner1.sendTransaction({
        to: await kronosMultiSig.getAddress(),
        value: ethers.parseEther("10"),
      });

      const holder1BalanceBefore = await ethers.provider.getBalance(
        holder1.address
      );
      const contractBalance = await ethers.provider.getBalance(
        await kronosMultiSig.getAddress()
      );

      const sewithdrawBalanceData = kronosMultiSig.interface.encodeFunctionData(
        "withdrawBalance",
        [holder1.address, contractBalance]
      );

      // Propose and approve adding a new owner
      await kronosMultiSig
        .connect(owner1)
        .proposeTransaction(await kronosMultiSig.getAddress(), sewithdrawBalanceData, 0);
      await kronosMultiSig.connect(owner2).approveTransaction(0);
      await kronosMultiSig.connect(owner3).approveTransaction(0);

      const holder1BalanceAfter = await ethers.provider.getBalance(
        holder1.address
      );

      expect(holder1BalanceAfter).to.equal(
        holder1BalanceBefore + contractBalance
      );
    });
  });
});
