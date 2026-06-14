const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GreenCredits - ERC-20 Reward Token Tests", function () {
  let greenCredits;
  let deployer, minter, user1, user2, unauthorized;

  const MINTER_ROLE = ethers.id("MINTER_ROLE");
  const INITIAL_MINT_AMOUNT = ethers.parseEther("5000");

  beforeEach(async function () {
    [deployer, minter, user1, user2, unauthorized] = await ethers.getSigners();

    const GreenCredits = await ethers.getContractFactory("GreenCredits");
    greenCredits = await GreenCredits.deploy(minter.address);
  });

  describe("Initialization", function () {
    it("Should have correct name and symbol", async function () {
      expect(await greenCredits.name()).to.equal("Green Credits");
      expect(await greenCredits.symbol()).to.equal("GREEN");
    });

    it("Should have 18 decimals", async function () {
      expect(await greenCredits.decimals()).to.equal(18);
    });

    it("Should grant MINTER_ROLE to initial minter", async function () {
      expect(await greenCredits.hasRole(MINTER_ROLE, minter.address)).to.be.true;
    });

    it("Should start with zero total supply", async function () {
      expect(await greenCredits.totalSupply()).to.equal(0);
    });

    it("Should have correct max supply", async function () {
      const maxSupply = await greenCredits.MAX_SUPPLY();
      expect(maxSupply).to.equal(ethers.parseEther("1000000000")); // 1 billion
    });
  });

  describe("Minting Credits (MINTER_ROLE Only)", function () {
    it("Should allow minter to mint credits", async function () {
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "first_recycle"
      );

      expect(await greenCredits.balanceOf(user1.address)).to.equal(INITIAL_MINT_AMOUNT);
    });

    it("Should emit CreditsMinted event", async function () {
      await expect(
        greenCredits.connect(minter).mintCredits(
          user1.address,
          INITIAL_MINT_AMOUNT,
          "first_recycle"
        )
      )
        .to.emit(greenCredits, "CreditsMinted")
        .withArgs(user1.address, INITIAL_MINT_AMOUNT, "first_recycle");
    });

    it("Should update total minted credits", async function () {
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "test"
      );

      expect(await greenCredits.getTotalMintedCredits()).to.equal(INITIAL_MINT_AMOUNT);
    });

    it("Should prevent unauthorized user from minting", async function () {
      await expect(
        greenCredits.connect(unauthorized).mintCredits(
          user1.address,
          INITIAL_MINT_AMOUNT,
          "test"
        )
      ).to.be.reverted;
    });

    it("Should prevent minting to zero address", async function () {
      await expect(
        greenCredits.connect(minter).mintCredits(
          ethers.ZeroAddress,
          INITIAL_MINT_AMOUNT,
          "test"
        )
      ).to.be.revertedWith("Cannot mint to zero address");
    });

    it("Should prevent minting zero amount", async function () {
      await expect(
        greenCredits.connect(minter).mintCredits(user1.address, 0, "test")
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should prevent minting above max supply", async function () {
      const maxSupply = await greenCredits.MAX_SUPPLY();
      const overAmount = maxSupply + ethers.parseEther("1");

      await expect(
        greenCredits.connect(minter).mintCredits(
          user1.address,
          overAmount,
          "test"
        )
      ).to.be.revertedWith("Exceeds maximum supply");
    });

    it("Should allow multiple mints up to max supply", async function () {
      const maxSupply = await greenCredits.MAX_SUPPLY();
      const halfSupply = maxSupply / BigInt(2);

      // First mint: half supply
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        halfSupply,
        "mint1"
      );
      expect(await greenCredits.balanceOf(user1.address)).to.equal(halfSupply);

      // Second mint: other half
      await greenCredits.connect(minter).mintCredits(
        user2.address,
        halfSupply,
        "mint2"
      );
      expect(await greenCredits.getTotalMintedCredits()).to.equal(maxSupply);
    });
  });

  describe("Burning Credits", function () {
    beforeEach(async function () {
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "test"
      );
    });

    it("Should allow user to burn their own credits", async function () {
      const burnAmount = ethers.parseEther("1000");
      await greenCredits.connect(user1).burnCredits(burnAmount);

      expect(await greenCredits.balanceOf(user1.address)).to.equal(
        INITIAL_MINT_AMOUNT - burnAmount
      );
    });

    it("Should prevent burning zero amount", async function () {
      await expect(
        greenCredits.connect(user1).burnCredits(0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should prevent burning more than balance", async function () {
      const overAmount = INITIAL_MINT_AMOUNT + ethers.parseEther("1");

      await expect(
        greenCredits.connect(user1).burnCredits(overAmount)
      ).to.be.revertedWith("Insufficient balance");
    });
  });

  describe("Transfers", function () {
    beforeEach(async function () {
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "test"
      );
    });

    it("Should allow user to transfer credits", async function () {
      const transferAmount = ethers.parseEther("1000");
      await greenCredits.connect(user1).transfer(user2.address, transferAmount);

      expect(await greenCredits.balanceOf(user1.address)).to.equal(
        INITIAL_MINT_AMOUNT - transferAmount
      );
      expect(await greenCredits.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should emit CreditsTransferred event on transfer", async function () {
      const transferAmount = ethers.parseEther("500");

      await expect(greenCredits.connect(user1).transfer(user2.address, transferAmount))
        .to.emit(greenCredits, "CreditsTransferred")
        .withArgs(user1.address, user2.address, transferAmount);
    });

    it("Should allow transferFrom with approval", async function () {
      const transferAmount = ethers.parseEther("1000");

      // Approve
      await greenCredits.connect(user1).approve(user2.address, transferAmount);

      // Transfer
      await greenCredits
        .connect(user2)
        .transferFrom(user1.address, user2.address, transferAmount);

      expect(await greenCredits.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should prevent transfer to zero address", async function () {
      await expect(
        greenCredits.connect(user1).transfer(ethers.ZeroAddress, ethers.parseEther("100"))
      ).to.be.revertedWith("Cannot transfer to zero address");
    });

    it("Should prevent transfer of zero amount", async function () {
      await expect(
        greenCredits.connect(user1).transfer(user2.address, 0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should prevent transfer more than balance", async function () {
      const overAmount = INITIAL_MINT_AMOUNT + ethers.parseEther("1");

      await expect(
        greenCredits.connect(user1).transfer(user2.address, overAmount)
      ).to.be.revertedWith("Insufficient balance");
    });
  });

  describe("Query Functions", function () {
    it("Should correctly report total minted credits", async function () {
      expect(await greenCredits.getTotalMintedCredits()).to.equal(0);

      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "test"
      );

      expect(await greenCredits.getTotalMintedCredits()).to.equal(INITIAL_MINT_AMOUNT);
    });

    it("Should correctly calculate remaining mintable credits", async function () {
      const maxSupply = await greenCredits.MAX_SUPPLY();

      let remaining = await greenCredits.getRemainingMintableCredits();
      expect(remaining).to.equal(maxSupply);

      await greenCredits.connect(minter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "test"
      );

      remaining = await greenCredits.getRemainingMintableCredits();
      expect(remaining).to.equal(maxSupply - INITIAL_MINT_AMOUNT);
    });

    it("Should identify minters correctly", async function () {
      expect(await greenCredits.isMinter(minter.address)).to.be.true;
      expect(await greenCredits.isMinter(user1.address)).to.be.false;
    });

    it("Should return formatted balance correctly", async function () {
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        ethers.parseEther("1000"),
        "test"
      );

      const formatted = await greenCredits.getFormattedBalance(user1.address);
      expect(formatted).to.equal(ethers.parseEther("1000") / (10n ** 18n));
    });
  });

  describe("Role Management", function () {
    it("Should allow adding new minters", async function () {
      const newMinter = unauthorized;
      const role = MINTER_ROLE;

      await greenCredits.grantRole(role, newMinter.address);
      expect(await greenCredits.hasRole(role, newMinter.address)).to.be.true;

      // New minter should be able to mint
      await greenCredits.connect(newMinter).mintCredits(
        user1.address,
        INITIAL_MINT_AMOUNT,
        "new_minter_test"
      );

      expect(await greenCredits.balanceOf(user1.address)).to.equal(INITIAL_MINT_AMOUNT);
    });

    it("Should allow removing minters", async function () {
      const role = MINTER_ROLE;

      expect(await greenCredits.hasRole(role, minter.address)).to.be.true;

      await greenCredits.revokeRole(role, minter.address);
      expect(await greenCredits.hasRole(role, minter.address)).to.be.false;

      // Revoked minter should not be able to mint
      await expect(
        greenCredits.connect(minter).mintCredits(
          user1.address,
          INITIAL_MINT_AMOUNT,
          "test"
        )
      ).to.be.reverted;
    });
  });

  describe("Real-World Scenarios", function () {
    it("Should handle complete recycling reward workflow", async function () {
      // Step 1: Recycler completes deal, gets credited
      const rewardAmount = ethers.parseEther("50");
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        rewardAmount,
        "recycle_complete_001"
      );

      expect(await greenCredits.balanceOf(user1.address)).to.equal(rewardAmount);

      // Step 2: User transfers credits to another user
      const transferAmount = ethers.parseEther("30");
      await greenCredits.connect(user1).transfer(user2.address, transferAmount);

      expect(await greenCredits.balanceOf(user1.address)).to.equal(rewardAmount - transferAmount);
      expect(await greenCredits.balanceOf(user2.address)).to.equal(transferAmount);

      // Step 3: User burns remaining credits
      const remainingUser1 = await greenCredits.balanceOf(user1.address);
      await greenCredits.connect(user1).burnCredits(remainingUser1);

      expect(await greenCredits.balanceOf(user1.address)).to.equal(0);
    });

    it("Should handle multiple recyclers earning credits", async function () {
      const recycler1Reward = ethers.parseEther("100");
      const recycler2Reward = ethers.parseEther("150");
      const recycler3Reward = ethers.parseEther("75");

      // Multiple recyclers complete deals
      await greenCredits.connect(minter).mintCredits(
        user1.address,
        recycler1Reward,
        "recycle_001"
      );
      await greenCredits.connect(minter).mintCredits(
        user2.address,
        recycler2Reward,
        "recycle_002"
      );
      await greenCredits.connect(minter).mintCredits(
        unauthorized.address,
        recycler3Reward,
        "recycle_003"
      );

      const total = recycler1Reward + recycler2Reward + recycler3Reward;
      expect(await greenCredits.getTotalMintedCredits()).to.equal(total);
    });
  });
});
