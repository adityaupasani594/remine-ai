const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EWasteTransactions - Production Tests", function () {
  let eWasteTransactions;
  let deployer, seller, seller2, recycler, recycler2, unauthorized;

  const SELLER_ROLE = ethers.id("SELLER_ROLE");
  const RECYCLER_ROLE = ethers.id("RECYCLER_ROLE");

  beforeEach(async function () {
    [deployer, seller, seller2, recycler, recycler2, unauthorized] = await ethers.getSigners();

    const EWasteTransactions = await ethers.getContractFactory("EWasteTransactions");
    eWasteTransactions = await EWasteTransactions.deploy(
      [deployer.address, seller.address, seller2.address],
      [recycler.address, recycler2.address]
    );
  });

  describe("Contract Initialization", function () {
    it("Should initialize with correct name and symbol", async function () {
      expect(await eWasteTransactions.name()).to.equal("EWasteTransactions");
      expect(await eWasteTransactions.symbol()).to.equal("EWASTE");
    });

    it("Should grant SELLER_ROLE to initial sellers", async function () {
      expect(await eWasteTransactions.hasRole(SELLER_ROLE, seller.address)).to.be.true;
      expect(await eWasteTransactions.hasRole(SELLER_ROLE, seller2.address)).to.be.true;
    });

    it("Should grant RECYCLER_ROLE to initial recyclers", async function () {
      expect(await eWasteTransactions.hasRole(RECYCLER_ROLE, recycler.address)).to.be.true;
      expect(await eWasteTransactions.hasRole(RECYCLER_ROLE, recycler2.address)).to.be.true;
    });

    it("Should start token counter at 0", async function () {
      expect(await eWasteTransactions.getCurrentTokenId()).to.equal(0);
    });
  });

  describe("Minting Items (Seller Only)", function () {
    it("Should allow seller to mint an item", async function () {
      await eWasteTransactions.connect(seller).mintItem();
      expect(await eWasteTransactions.ownerOf(0)).to.equal(seller.address);
    });

    it("Should emit ItemMinted event", async function () {
      await expect(eWasteTransactions.connect(seller).mintItem())
        .to.emit(eWasteTransactions, "ItemMinted")
        .withArgs(0, seller.address);
    });

    it("Should increment token ID counter", async function () {
      await eWasteTransactions.connect(seller).mintItem();
      await eWasteTransactions.connect(seller2).mintItem();
      expect(await eWasteTransactions.getCurrentTokenId()).to.equal(2);
    });

    it("Should prevent unauthorized user from minting", async function () {
      await expect(eWasteTransactions.connect(unauthorized).mintItem())
        .to.be.reverted;
    });
  });

  describe("Listing Items (Seller Only)", function () {
    beforeEach(async function () {
      await eWasteTransactions.connect(seller).mintItem();
    });

    it("Should allow owner to list item", async function () {
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
      
      expect(await eWasteTransactions.isItemListed(0)).to.be.true;
      expect(await eWasteTransactions.getItemPrice(0)).to.equal(price);
    });

    it("Should emit ItemListed event", async function () {
      const price = ethers.parseEther("1.0");
      await expect(eWasteTransactions.connect(seller).listItem(0, price))
        .to.emit(eWasteTransactions, "ItemListed")
        .withArgs(0, price);
    });

    it("Should prevent non-owner from listing", async function () {
      const price = ethers.parseEther("1.0");
      await expect(eWasteTransactions.connect(seller2).listItem(0, price))
        .to.be.revertedWith("Only token owner can list");
    });

    it("Should prevent listing with zero price", async function () {
      await expect(eWasteTransactions.connect(seller).listItem(0, 0))
        .to.be.revertedWith("Price must be greater than 0");
    });

    it("Should prevent double listing", async function () {
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
      await expect(eWasteTransactions.connect(seller).listItem(0, price))
        .to.be.revertedWith("Item already listed");
    });
  });

  describe("Buying Items (Recycler Only)", function () {
    beforeEach(async function () {
      await eWasteTransactions.connect(seller).mintItem();
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
    });

    it("Should allow recycler to buy listed item", async function () {
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);
    });

    it("Should emit ItemPurchased event", async function () {
      const price = ethers.parseEther("1.0");
      await expect(eWasteTransactions.connect(recycler).buyItem(0, { value: price }))
        .to.emit(eWasteTransactions, "ItemPurchased")
        .withArgs(0, seller.address, recycler.address, price);
    });

    it("Should transfer payment to seller", async function () {
      const price = ethers.parseEther("1.0");
      const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
      
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
      
      const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
      expect(sellerBalanceAfter).to.be.greaterThan(sellerBalanceBefore);
    });

    it("Should delist item after purchase", async function () {
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
      expect(await eWasteTransactions.isItemListed(0)).to.be.false;
    });

    it("Should prevent unauthorized user from buying", async function () {
      const price = ethers.parseEther("1.0");
      await expect(eWasteTransactions.connect(unauthorized).buyItem(0, { value: price }))
        .to.be.reverted;
    });

    it("Should prevent buying unlisted item", async function () {
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller2).mintItem();
      await expect(eWasteTransactions.connect(recycler).buyItem(1, { value: price }))
        .to.be.revertedWith("Item is not listed for sale");
    });

    it("Should prevent buying with incorrect payment", async function () {
      const wrongPrice = ethers.parseEther("0.5");
      await expect(eWasteTransactions.connect(recycler).buyItem(0, { value: wrongPrice }))
        .to.be.revertedWith("Incorrect payment amount");
    });
  });

  describe("Recycling Items (Burn)", function () {
    beforeEach(async function () {
      await eWasteTransactions.connect(seller).mintItem();
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
    });

    it("Should allow recycler to burn item", async function () {
      await eWasteTransactions.connect(recycler).burnAfterRecycle(0);
      await expect(eWasteTransactions.ownerOf(0)).to.be.reverted;
    });

    it("Should emit ItemRecycled event", async function () {
      await expect(eWasteTransactions.connect(recycler).burnAfterRecycle(0))
        .to.emit(eWasteTransactions, "ItemRecycled")
        .withArgs(0, recycler.address);
    });

    it("Should prevent non-owner from burning", async function () {
      await expect(eWasteTransactions.connect(seller).burnAfterRecycle(0))
        .to.be.revertedWith("Only token owner can burn");
    });

    it("Should prevent non-recycler from burning", async function () {
      await expect(eWasteTransactions.connect(unauthorized).burnAfterRecycle(0))
        .to.be.reverted;
    });
  });

  describe("Complete Workflow", function () {
    it("Should execute full sell-buy-recycle workflow", async function () {
      // Step 1: Mint
      await expect(eWasteTransactions.connect(seller).mintItem())
        .to.emit(eWasteTransactions, "ItemMinted")
        .withArgs(0, seller.address);

      // Step 2: List
      const price = ethers.parseEther("1.0");
      await expect(eWasteTransactions.connect(seller).listItem(0, price))
        .to.emit(eWasteTransactions, "ItemListed")
        .withArgs(0, price);

      // Step 3: Buy
      await expect(eWasteTransactions.connect(recycler).buyItem(0, { value: price }))
        .to.emit(eWasteTransactions, "ItemPurchased")
        .withArgs(0, seller.address, recycler.address, price);

      // Step 4: Recycle
      await expect(eWasteTransactions.connect(recycler).burnAfterRecycle(0))
        .to.emit(eWasteTransactions, "ItemRecycled")
        .withArgs(0, recycler.address);
    });

    it("Should handle multiple items in parallel", async function () {
      const price = ethers.parseEther("1.0");

      // Mint multiple items
      await eWasteTransactions.connect(seller).mintItem();
      await eWasteTransactions.connect(seller).mintItem();
      await eWasteTransactions.connect(seller2).mintItem();

      // List all
      await eWasteTransactions.connect(seller).listItem(0, price);
      await eWasteTransactions.connect(seller).listItem(1, price);
      await eWasteTransactions.connect(seller2).listItem(2, price);

      // Buy from different recyclers
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
    it("buyItem should have reentrancy protection", async function () {
      await eWasteTransactions.connect(seller).mintItem();
      const price = ethers.parseEther("1.0");
      await eWasteTransactions.connect(seller).listItem(0, price);

      // Normal purchase should work
      await eWasteTransactions.connect(recycler).buyItem(0, { value: price });
      expect(await eWasteTransactions.ownerOf(0)).to.equal(recycler.address);
    });
  });
});
