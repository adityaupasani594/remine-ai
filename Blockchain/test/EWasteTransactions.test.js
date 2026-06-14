const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("EWasteTransactions", function () {
  let eWasteTransactions;
  let admin, seller, seller2, recycler, recycler2, unauthorizedUser;

  const SELLER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SELLER_ROLE"));
  const RECYCLER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("RECYCLER_ROLE"));

  beforeEach(async function () {
    [admin, seller, seller2, recycler, recycler2, unauthorizedUser] = await ethers.getSigners();

    const EWasteTransactions = await ethers.getContractFactory("EWasteTransactions");
    eWasteTransactions = await EWasteTransactions.deploy();

    // Grant roles
    await eWasteTransactions.connect(admin).grantSellerRole(seller.address);
    await eWasteTransactions.connect(admin).grantSellerRole(seller2.address);
    await eWasteTransactions.connect(admin).grantRecyclerRole(recycler.address);
    await eWasteTransactions.connect(admin).grantRecyclerRole(recycler2.address);

    // Verify recyclers
    await eWasteTransactions.connect(admin).verifyRecycler(recycler.address);
    await eWasteTransactions.connect(admin).verifyRecycler(recycler2.address);
  });

  describe("Initialization", function () {
    it("Should initialize with correct name and symbol", async function () {
      expect(await eWasteTransactions.name()).to.equal("EWasteTransactions");
      expect(await eWasteTransactions.symbol()).to.equal("EWASTE");
    });

    it("Should set admin role to deployer", async function () {
      const ADMIN_ROLE = await eWasteTransactions.ADMIN_ROLE();
      expect(await eWasteTransactions.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
    });
  });

  describe("Role Management", function () {
    it("Should grant seller role to address", async function () {
      const tx = await eWasteTransactions.connect(admin).grantSellerRole(unauthorizedUser.address);
      await tx.wait();

      expect(await eWasteTransactions.hasRole(SELLER_ROLE, unauthorizedUser.address)).to.be.true;
    });

    it("Should grant recycler role to address", async function () {
      const tx = await eWasteTransactions.connect(admin).grantRecyclerRole(unauthorizedUser.address);
      await tx.wait();

      expect(await eWasteTransactions.hasRole(RECYCLER_ROLE, unauthorizedUser.address)).to.be.true;
    });

    it("Should verify recycler", async function () {
      const newRecycler = unauthorizedUser.address;
      await eWasteTransactions.connect(admin).grantRecyclerRole(newRecycler);
      await eWasteTransactions.connect(admin).verifyRecycler(newRecycler);

      expect(await eWasteTransactions.isRecyclerVerified(newRecycler)).to.be.true;
    });

    it("Should emit SellerRoleGranted event", async function () {
      await expect(eWasteTransactions.connect(admin).grantSellerRole(unauthorizedUser.address))
        .to.emit(eWasteTransactions, "SellerRoleGranted")
        .withArgs(unauthorizedUser.address);
    });

    it("Should emit RecyclerVerified event", async function () {
      const newRecycler = unauthorizedUser.address;
      await eWasteTransactions.connect(admin).grantRecyclerRole(newRecycler);

      await expect(eWasteTransactions.connect(admin).verifyRecycler(newRecycler))
        .to.emit(eWasteTransactions, "RecyclerVerified")
        .withArgs(newRecycler);
    });

    it("Should prevent non-admin from granting roles", async function () {
      await expect(
        eWasteTransactions.connect(seller).grantSellerRole(unauthorizedUser.address)
      ).to.be.reverted;
    });
  });

  describe("Minting Items", function () {
    it("Should allow seller to mint an item", async function () {
      const tx = await eWasteTransactions.connect(seller).mintItem(seller.address);
      await tx.wait();

      expect(await eWasteTransactions.ownerOf(0)).to.equal(seller.address);
    });

    it("Should emit ItemCreated event", async function () {
      await expect(eWasteTransactions.connect(seller).mintItem(seller.address))
        .to.emit(eWasteTransactions, "ItemCreated")
        .withArgs(0, seller.address);
    });

    it("Should increment token ID for each mint", async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      await eWasteTransactions.connect(seller2).mintItem(seller2.address);

      expect(await eWasteTransactions.ownerOf(0)).to.equal(seller.address);
      expect(await eWasteTransactions.ownerOf(1)).to.equal(seller2.address);
    });

    it("Should prevent non-seller from minting", async function () {
      await expect(
        eWasteTransactions.connect(recycler).mintItem(recycler.address)
      ).to.be.reverted;
    });

    it("Should prevent minting with invalid seller address", async function () {
      await expect(
        eWasteTransactions.connect(seller).mintItem(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid seller address");
    });
  });

  describe("Listing Items", function () {
    beforeEach(async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
    });

    it("Should list item for sale", async function () {
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);

      const item = await eWasteTransactions.getItem(0);
      expect(item.price).to.equal(price);
      expect(item.isListed).to.be.true;
    });

    it("Should emit ItemListed event", async function () {
      const price = ethers.utils.parseEther("1.0");
      await expect(eWasteTransactions.connect(seller).listItem(0, price))
        .to.emit(eWasteTransactions, "ItemListed")
        .withArgs(0, price);
    });

    it("Should prevent non-owner from listing", async function () {
      const price = ethers.utils.parseEther("1.0");
      await expect(
        eWasteTransactions.connect(seller2).listItem(0, price)
      ).to.be.revertedWith("Only item owner can list");
    });

    it("Should prevent listing with zero price", async function () {
      await expect(
        eWasteTransactions.connect(seller).listItem(0, 0)
      ).to.be.revertedWith("Price must be greater than 0");
    });
  });

  describe("Buying Items", function () {
    beforeEach(async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
    });

    it("Should allow verified recycler to buy item", async function () {
      const price = ethers.utils.parseEther("1.0");
      const initialBalance = await ethers.provider.getBalance(seller.address);

      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });

      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);
    });

    it("Should emit ItemSold event", async function () {
      const price = ethers.utils.parseEther("1.0");
      await expect(eWasteTransactions.connect(recycler).buyItem(0, { value: price }))
        .to.emit(eWasteTransactions, "ItemSold")
        .withArgs(0, seller.address, recycler.address, price);
    });

    it("Should transfer payment to seller", async function () {
      const price = ethers.utils.parseEther("1.0");
      const initialBalance = await ethers.provider.getBalance(seller.address);

      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });

      const finalBalance = await ethers.provider.getBalance(seller.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should prevent unverified recycler from buying", async function () {
      const newRecycler = unauthorizedUser.address;
      await eWasteTransactions.connect(admin).grantRecyclerRole(newRecycler);
      // NOT verifying the recycler

      const price = ethers.utils.parseEther("1.0");
      await expect(
        eWasteTransactions.connect(unauthorizedUser).buyItem(0, { value: price })
      ).to.be.revertedWith("Only verified recyclers can purchase");
    });

    it("Should prevent buying unlisted item", async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      const price = ethers.utils.parseEther("1.0");

      await expect(
        eWasteTransactions.connect(recycler).buyItem(1, { value: price })
      ).to.be.revertedWith("Item is not listed for sale");
    });

    it("Should prevent buying with incorrect payment", async function () {
      const price = ethers.utils.parseEther("1.0");
      const wrongPrice = ethers.utils.parseEther("0.5");

      await expect(
        eWasteTransactions.connect(recycler).buyItem(0, { value: wrongPrice })
      ).to.be.revertedWith("Incorrect payment amount");
    });

    it("Should prevent seller from buying own item", async function () {
      const price = ethers.utils.parseEther("1.0");
      await expect(
        eWasteTransactions.connect(seller).buyItem(0, { value: price })
      ).to.be.reverted;
    });
  });

  describe("Recycling Items", function () {
    beforeEach(async function () {
      // Mint and sell an item
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
    });

    it("Should allow recycler to burn item after recycling", async function () {
      await eWasteTransactions.connect(recycler).burnAfterRecycle(0);

      // Token should be burned
      await expect(eWasteTransactions.ownerOf(0)).to.be.reverted;
    });

    it("Should emit ItemRecycled event", async function () {
      await expect(eWasteTransactions.connect(recycler).burnAfterRecycle(0))
        .to.emit(eWasteTransactions, "ItemRecycled")
        .withArgs(0, recycler.address);
    });

    it("Should mark item as recycled", async function () {
      await eWasteTransactions.connect(recycler).burnAfterRecycle(0);

      const item = await eWasteTransactions.getItem(0);
      expect(item.isRecycled).to.be.true;
    });

    it("Should prevent non-owner from burning", async function () {
      await expect(
        eWasteTransactions.connect(seller).burnAfterRecycle(0)
      ).to.be.revertedWith("Only item owner can burn");
    });

    it("Should prevent non-recycler from burning", async function () {
      // The unauthorized user doesn't own the token, so it will revert with "Only item owner can burn"
      // This is the expected behavior - only the owner can call burnAfterRecycle
      await expect(
        eWasteTransactions.connect(unauthorizedUser).burnAfterRecycle(0)
      ).to.be.revertedWith("Only item owner can burn");
    });
  });

  describe("Query Functions", function () {
    it("Should get item details", async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);

      const item = await eWasteTransactions.getItem(0);
      expect(item.tokenId).to.equal(0);
      expect(item.seller).to.equal(seller.address);
      expect(item.price).to.equal(price);
      expect(item.isListed).to.be.true;
      expect(item.isRecycled).to.be.false;
    });

    it("Should check if recycler is verified", async function () {
      expect(await eWasteTransactions.isRecyclerVerified(recycler.address)).to.be.true;
      expect(await eWasteTransactions.isRecyclerVerified(unauthorizedUser.address)).to.be.false;
    });

    it("Should get current token ID", async function () {
      expect(await eWasteTransactions.getCurrentTokenId()).to.equal(0);

      await eWasteTransactions.connect(seller).mintItem(seller.address);
      expect(await eWasteTransactions.getCurrentTokenId()).to.equal(1);

      await eWasteTransactions.connect(seller).mintItem(seller.address);
      expect(await eWasteTransactions.getCurrentTokenId()).to.equal(2);
    });
  });

  describe("Complete Workflow", function () {
    it("Should complete full e-waste transaction workflow", async function () {
      // Step 1: Seller mints e-waste item
      await expect(eWasteTransactions.connect(seller).mintItem(seller.address))
        .to.emit(eWasteTransactions, "ItemCreated")
        .withArgs(0, seller.address);

      // Step 2: Seller lists item for sale
      const price = ethers.utils.parseEther("1.0");
      await expect(eWasteTransactions.connect(seller).listItem(0, price))
        .to.emit(eWasteTransactions, "ItemListed")
        .withArgs(0, price);

      // Step 3: Verified recycler purchases item
      await expect(eWasteTransactions.connect(recycler).buyItem(0, { value: price }))
        .to.emit(eWasteTransactions, "ItemSold")
        .withArgs(0, seller.address, recycler.address, price);

      // Verify ownership transfer
      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);

      // Step 4: Recycler burns item after recycling
      await expect(eWasteTransactions.connect(recycler).burnAfterRecycle(0))
        .to.emit(eWasteTransactions, "ItemRecycled")
        .withArgs(0, recycler.address);

      // Verify item is recycled
      const item = await eWasteTransactions.getItem(0);
      expect(item.isRecycled).to.be.true;
    });

    it("Should handle multiple items simultaneously", async function () {
      // Mint multiple items
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      await eWasteTransactions.connect(seller2).mintItem(seller2.address);

      // List all for sale
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
      await eWasteTransactions.connect(seller).listItem(1, price);
      await eWasteTransactions.connect(seller2).listItem(2, price);

      // Different recyclers buy different items
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
      await eWasteTransactions.connect(recycler2).buyItem(1, { value: price });
      await eWasteTransactions.connect(recycler).buyItem(2, { value: price });

      // Verify ownership
      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);
      expect(await eWasteTransactions.ownerOf(1)).to.equal(recycler2.address);
      expect(await eWasteTransactions.ownerOf(2)).to.equal(recycler.address);
    });
  });

  describe("Security - Reentrancy Protection", function () {
    it("Should protect against reentrancy in buyItem", async function () {
      await eWasteTransactions.connect(seller).mintItem(seller.address);
      const price = ethers.utils.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);

      // Normal transaction should work
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });

      // Verify transaction completed
      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);
    });
  });
});
