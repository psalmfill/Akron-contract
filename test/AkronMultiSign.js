const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Akron Multisig Governance", function () {
  let owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2;
  let akron;
  const initialSupply = ethers.parseEther("1000");

  beforeEach(async function () {
    [owner1, owner2, owner3, nonOwner, walletToPause, holder1, holder2] =
      await ethers.getSigners();

    const Akron = await ethers.getContractFactory("AkronMultiSign");
    akron = await Akron.deploy(
      [owner1.address, owner2.address, owner3.address],
      2
    ); // 2 confirmations needed
  });

  describe("Multisig and Governance", function () {
    it("should allow revoke a transaction", async function () {
      const addOwnerData = akron.interface.encodeFunctionData("addOwner", [
        nonOwner.address,
      ]);

      // Propose and approve adding a new owner
      await akron
        .connect(owner1)
        .proposeTransaction(await akron.getAddress(), addOwnerData, 0);
      await akron.connect(owner2).approveTransaction(0);

      const transaction = await akron.transactions(0)
      console.log("transaction", transaction.confirmations)
      await akron.connect(owner2).revokeTransactionApproval(0);

      const newTransaction = await akron.transactions(0);
      expect(newTransaction.confirmations).to.equal(0n);
    });

    it("should allow adding a new owner", async function () {
        const addOwnerData = akron.interface.encodeFunctionData("addOwner", [
          nonOwner.address,
        ]);
  
        // Propose and approve adding a new owner
        await akron
          .connect(owner1)
          .proposeTransaction(await akron.getAddress(), addOwnerData, 0);
        await akron.connect(owner2).approveTransaction(0);
        await akron.connect(owner3).approveTransaction(0);
  
        const isOwner = await akron.isOwner(nonOwner.address);
        expect(isOwner).to.equal(true);
      });

    it("should allow removing an owner", async function () {
      const addOwnerData = akron.interface.encodeFunctionData("addOwner", [
        nonOwner.address,
      ]);

      // Add the non-owner first
      await akron
        .connect(owner1)
        .proposeTransaction(await akron.getAddress(), addOwnerData, 0);
      await akron.connect(owner2).approveTransaction(0);
      await akron.connect(owner3).approveTransaction(0);

      const removeOwnerData = akron.interface.encodeFunctionData(
        "removeOwner",
        [nonOwner.address]
      );

      // Propose and approve removing the owner
      await akron
        .connect(owner1)
        .proposeTransaction(await akron.getAddress(), removeOwnerData, 0);
      await akron.connect(owner2).approveTransaction(1);
      await akron.connect(owner3).approveTransaction(1);

      const isOwner = await akron.isOwner(nonOwner.address);
      expect(isOwner).to.equal(false);
    });
  });
});
