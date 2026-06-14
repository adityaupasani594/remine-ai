const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RecyclerBadge - ERC-721 Soulbound NFT Tests", function () {
  let recyclerBadge;
  let deployer, minter, recycler1, recycler2, unauthorized;

  const MINTER_ROLE = ethers.id("MINTER_ROLE");
  const BURNER_ROLE = ethers.id("BURNER_ROLE");
  const BadgeType = {
    VERIFIED_RECYCLER: 0,
    TOP_RECYCLER: 1,
    GREEN_CHAMPION: 2,
    ECO_PIONEER: 3
  };

  beforeEach(async function () {
    [deployer, minter, recycler1, recycler2, unauthorized] = await ethers.getSigners();

    const RecyclerBadge = await ethers.getContractFactory("RecyclerBadge");
    recyclerBadge = await RecyclerBadge.deploy(minter.address);
  });

  describe("Initialization", function () {
    it("Should have correct name and symbol", async function () {
      expect(await recyclerBadge.name()).to.equal("Recycler Badge");
      expect(await recyclerBadge.symbol()).to.equal("RECYCLE");
    });

    it("Should grant MINTER_ROLE to initial minter", async function () {
      expect(await recyclerBadge.hasRole(MINTER_ROLE, minter.address)).to.be.true;
    });

    it("Should grant BURNER_ROLE to initial minter", async function () {
      expect(await recyclerBadge.hasRole(BURNER_ROLE, minter.address)).to.be.true;
    });

    it("Should start with zero badges", async function () {
      expect(await recyclerBadge.getTotalBadges()).to.equal(0);
    });
  });

  describe("Minting Badges (MINTER_ROLE Only)", function () {
    it("Should allow minter to mint badge", async function () {
      const tx = await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "First Verification"
      );

      await tx.wait();

      expect(await recyclerBadge.ownerOf(0)).to.equal(recycler1.address);
    });

    it("Should emit BadgeMinted event", async function () {
      await expect(
        recyclerBadge.connect(minter).mintBadge(
          recycler1.address,
          BadgeType.VERIFIED_RECYCLER,
          "First Verification"
        )
      )
        .to.emit(recyclerBadge, "BadgeMinted")
        .withArgs(
          0,
          recycler1.address,
          BadgeType.VERIFIED_RECYCLER,
          "First Verification"
        );
    });

    it("Should emit RecyclerVerified event on first badge", async function () {
      await expect(
        recyclerBadge.connect(minter).mintBadge(
          recycler1.address,
          BadgeType.VERIFIED_RECYCLER,
          "First Verification"
        )
      )
        .to.emit(recyclerBadge, "RecyclerVerified")
        .withArgs(recycler1.address, 0);
    });

    it("Should prevent unauthorized user from minting", async function () {
      await expect(
        recyclerBadge.connect(unauthorized).mintBadge(
          recycler1.address,
          BadgeType.VERIFIED_RECYCLER,
          "Unauthorized"
        )
      ).to.be.reverted;
    });

    it("Should prevent minting to zero address", async function () {
      await expect(
        recyclerBadge.connect(minter).mintBadge(
          ethers.ZeroAddress,
          BadgeType.VERIFIED_RECYCLER,
          "Test"
        )
      ).to.be.revertedWith("Cannot mint to zero address");
    });

    it("Should prevent minting with empty metadata", async function () {
      await expect(
        recyclerBadge.connect(minter).mintBadge(recycler1.address, BadgeType.VERIFIED_RECYCLER, "")
      ).to.be.revertedWith("Metadata cannot be empty");
    });

    it("Should return correct token ID", async function () {
      const tx = await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Test"
      );

      const receipt = await tx.wait();

      // Check that ownerOf works with token 0
      expect(await recyclerBadge.ownerOf(0)).to.equal(recycler1.address);
    });

    it("Should increment token counter properly", async function () {
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Badge 1"
      );
      await recyclerBadge.connect(minter).mintBadge(
        recycler2.address,
        BadgeType.TOP_RECYCLER,
        "Badge 2"
      );

      expect(await recyclerBadge.getTotalBadges()).to.equal(2);
    });

    it("Should allow minting all badge types", async function () {
      const badgeTypes = [
        BadgeType.VERIFIED_RECYCLER,
        BadgeType.TOP_RECYCLER,
        BadgeType.GREEN_CHAMPION,
        BadgeType.ECO_PIONEER
      ];

      for (let i = 0; i < badgeTypes.length; i++) {
        await recyclerBadge.connect(minter).mintBadge(
          recycler1.address,
          badgeTypes[i],
          `Badge Type ${i}`
        );
      }

      expect(await recyclerBadge.getTotalBadges()).to.equal(4);
      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(4);
    });
  });

  describe("Soulbound (Non-Transferable)", function () {
    beforeEach(async function () {
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Test Badge"
      );
    });

    it("Should prevent transferFrom", async function () {
      await expect(
        recyclerBadge.connect(recycler1).transferFrom(recycler1.address, recycler2.address, 0)
      ).to.be.revertedWith("Soulbound: Badges cannot be transferred");
    });

    it("Should prevent safeTransferFrom", async function () {
      await expect(
        recyclerBadge.connect(recycler1).safeTransferFrom(recycler1.address, recycler2.address, 0)
      ).to.be.revertedWith("Soulbound: Badges cannot be transferred");
    });

    it("Should prevent safeTransferFrom with data", async function () {
      await expect(
        recyclerBadge
          .connect(recycler1)
          ["safeTransferFrom(address,address,uint256,bytes)"](recycler1.address, recycler2.address, 0, "0x")
      ).to.be.revertedWith("Soulbound: Badges cannot be transferred");
    });

    it("Should prevent approval", async function () {
      await expect(recyclerBadge.connect(recycler1).approve(recycler2.address, 0)).to.be
        .revertedWith("Soulbound: Badges cannot be transferred");
    });

    it("Should prevent approval for all", async function () {
      await expect(
        recyclerBadge.connect(recycler1).setApprovalForAll(recycler2.address, true)
      ).to.be.revertedWith("Soulbound: Badges cannot be transferred");
    });
  });

  describe("Burning Badges (BURNER_ROLE Only)", function () {
    beforeEach(async function () {
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Test Badge"
      );
      await recyclerBadge.connect(minter).mintBadge(
        recycler2.address,
        BadgeType.TOP_RECYCLER,
        "Top Badge"
      );
    });

    it("Should allow burner to burn badge", async function () {
      await recyclerBadge.connect(minter).burnBadge(0);

      await expect(recyclerBadge.ownerOf(0)).to.be.reverted;
    });

    it("Should emit BadgeBurned event", async function () {
      await expect(recyclerBadge.connect(minter).burnBadge(0))
        .to.emit(recyclerBadge, "BadgeBurned")
        .withArgs(0, recycler1.address);
    });

    it("Should update badge count", async function () {
      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(1);

      await recyclerBadge.connect(minter).burnBadge(0);

      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(0);
    });

    it("Should prevent unauthorized user from burning", async function () {
      await expect(recyclerBadge.connect(unauthorized).burnBadge(0)).to.be.reverted;
    });

    it("Should prevent burning non-existent badge", async function () {
      await expect(recyclerBadge.connect(minter).burnBadge(999)).to.be.revertedWith(
        "Badge does not exist"
      );
    });
  });

  describe("Query Functions", function () {
    beforeEach(async function () {
      // Mint multiple badges
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Verified"
      );
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.TOP_RECYCLER,
        "Top"
      );
      await recyclerBadge.connect(minter).mintBadge(
        recycler2.address,
        BadgeType.GREEN_CHAMPION,
        "Champion"
      );
    });

    it("Should get badges of recycler", async function () {
      const badges = await recyclerBadge.getBadgesOfRecycler(recycler1.address);
      expect(badges.length).to.equal(2);
      expect(badges[0]).to.equal(0);
      expect(badges[1]).to.equal(1);
    });

    it("Should get badge count", async function () {
      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(2);
      expect(await recyclerBadge.getBadgeCount(recycler2.address)).to.equal(1);
    });

    it("Should get badge type", async function () {
      expect(await recyclerBadge.getBadgeType(0)).to.equal(BadgeType.VERIFIED_RECYCLER);
      expect(await recyclerBadge.getBadgeType(1)).to.equal(BadgeType.TOP_RECYCLER);
      expect(await recyclerBadge.getBadgeType(2)).to.equal(BadgeType.GREEN_CHAMPION);
    });

    it("Should get badge metadata", async function () {
      expect(await recyclerBadge.getBadgeMetadata(0)).to.equal("Verified");
      expect(await recyclerBadge.getBadgeMetadata(1)).to.equal("Top");
    });

    it("Should get total badges", async function () {
      expect(await recyclerBadge.getTotalBadges()).to.equal(3);
    });

    it("Should check verification status", async function () {
      expect(await recyclerBadge.isVerifiedRecycler(recycler1.address)).to.be.true;
      expect(await recyclerBadge.isVerifiedRecycler(recycler2.address)).to.be.true;
      expect(await recyclerBadge.isVerifiedRecycler(unauthorized.address)).to.be.false;
    });

    it("Should check if recycler has badge type", async function () {
      expect(
        await recyclerBadge.hasBadgeType(recycler1.address, BadgeType.VERIFIED_RECYCLER)
      ).to.be.true;
      expect(await recyclerBadge.hasBadgeType(recycler1.address, BadgeType.TOP_RECYCLER)).to.be
        .true;
      expect(await recyclerBadge.hasBadgeType(recycler1.address, BadgeType.GREEN_CHAMPION)).to
        .be.false;
    });

    it("Should get badge type name", async function () {
      expect(await recyclerBadge.getBadgeTypeName(BadgeType.VERIFIED_RECYCLER)).to.equal(
        "Verified Recycler"
      );
      expect(await recyclerBadge.getBadgeTypeName(BadgeType.TOP_RECYCLER)).to.equal(
        "Top Recycler"
      );
      expect(await recyclerBadge.getBadgeTypeName(BadgeType.GREEN_CHAMPION)).to.equal(
        "Green Champion"
      );
      expect(await recyclerBadge.getBadgeTypeName(BadgeType.ECO_PIONEER)).to.equal("Eco Pioneer");
    });
  });

  describe("Real-World Scenarios", function () {
    it("Should handle recycler progression through badge types", async function () {
      // Step 1: New recycler gets verified
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Initial Verification"
      );

      expect(await recyclerBadge.isVerifiedRecycler(recycler1.address)).to.be.true;
      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(1);

      // Step 2: After 100 deals, gets Top Recycler badge
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.TOP_RECYCLER,
        "100+ Recycling Deals"
      );

      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(2);
      expect(
        await recyclerBadge.hasBadgeType(recycler1.address, BadgeType.TOP_RECYCLER)
      ).to.be.true;

      // Step 3: After 500 deals, gets Green Champion
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.GREEN_CHAMPION,
        "500+ Deals & Environmental Leader"
      );

      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(3);
      expect(
        await recyclerBadge.hasBadgeType(recycler1.address, BadgeType.GREEN_CHAMPION)
      ).to.be.true;

      // Verify all badges are soulbound
      const badges = await recyclerBadge.getBadgesOfRecycler(recycler1.address);
      for (const badgeId of badges) {
        expect(await recyclerBadge.ownerOf(badgeId)).to.equal(recycler1.address);
      }
    });

    it("Should handle multiple recyclers with different badges", async function () {
      // Recycler 1: Multiple badges
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Verified"
      );
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.TOP_RECYCLER,
        "Top"
      );

      // Recycler 2: Single badge
      await recyclerBadge.connect(minter).mintBadge(
        recycler2.address,
        BadgeType.VERIFIED_RECYCLER,
        "Verified"
      );

      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(2);
      expect(await recyclerBadge.getBadgeCount(recycler2.address)).to.equal(1);
      expect(await recyclerBadge.getTotalBadges()).to.equal(3);
    });

    it("Should handle badge removal after revocation", async function () {
      // Mint badge
      await recyclerBadge.connect(minter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Verified"
      );

      expect(await recyclerBadge.isVerifiedRecycler(recycler1.address)).to.be.true;

      // Burn badge (revocation)
      await recyclerBadge.connect(minter).burnBadge(0);

      expect(await recyclerBadge.getBadgeCount(recycler1.address)).to.equal(0);
      // After burning, recycler still has verified status (it was earned)
      // To fully revoke verification, you'd need to burn all badges
      // This is by design - verification is not automatically revoked
    });
  });

  describe("Access Control", function () {
    it("Should allow granting additional minter roles", async function () {
      const newMinter = unauthorized;

      await recyclerBadge.grantRole(MINTER_ROLE, newMinter.address);
      expect(await recyclerBadge.hasRole(MINTER_ROLE, newMinter.address)).to.be.true;

      // New minter should be able to mint
      await recyclerBadge.connect(newMinter).mintBadge(
        recycler1.address,
        BadgeType.VERIFIED_RECYCLER,
        "Minted by New Minter"
      );

      expect(await recyclerBadge.ownerOf(0)).to.equal(recycler1.address);
    });

    it("Should allow revoking minter roles", async function () {
      await recyclerBadge.revokeRole(MINTER_ROLE, minter.address);
      expect(await recyclerBadge.hasRole(MINTER_ROLE, minter.address)).to.be.false;

      // Revoked minter should not be able to mint
      await expect(
        recyclerBadge.connect(minter).mintBadge(
          recycler1.address,
          BadgeType.VERIFIED_RECYCLER,
          "Should Fail"
        )
      ).to.be.reverted;
    });
  });
});
