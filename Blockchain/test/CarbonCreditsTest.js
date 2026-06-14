const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("CarbonCredits", function () {
  let carbonCredits;
  let owner, addr1, addr2;

  beforeEach(async function () {
    const CarbonCredits = await ethers.getContractFactory("CarbonCredits");
    [owner, addr1, addr2] = await ethers.getSigners();
    carbonCredits = await CarbonCredits.deploy();
  });

  it("Should register a node", async function () {
    await carbonCredits.registerNode(addr1.address);
    expect(await carbonCredits.isRegistered(addr1.address)).to.be.true;
  });

  it("Should assign credits to a registered node", async function () {
    await carbonCredits.registerNode(addr1.address);
    await carbonCredits.assignCredits(addr1.address, 100);
    expect(await carbonCredits.getCredits(addr1.address)).to.equal(100);
  });

  it("Should transfer credits between nodes", async function () {
    await carbonCredits.registerNode(addr1.address);
    await carbonCredits.registerNode(addr2.address);
    await carbonCredits.assignCredits(addr1.address, 100);

    await carbonCredits.connect(addr1).transferCredits(addr2.address, 50);
    expect(await carbonCredits.getCredits(addr1.address)).to.equal(50);
    expect(await carbonCredits.getCredits(addr2.address)).to.equal(50);
  });
});

describe("CarbonCreditsManager", function () {
  let carbonCredits;
  let carbonCreditsManager;
  let owner, addr1, addr2, assigner;

  beforeEach(async function () {
    const CarbonCredits = await ethers.getContractFactory("CarbonCredits");
    const CarbonCreditsManager = await ethers.getContractFactory("CarbonCreditsManager");

    [owner, addr1, addr2, assigner] = await ethers.getSigners();

    carbonCredits = await CarbonCredits.deploy();

    carbonCreditsManager = await CarbonCreditsManager.deploy(carbonCredits.address);
  });

  it("Should register a node through manager", async function () {
    await carbonCreditsManager.registerNode(addr1.address);
    expect(await carbonCredits.isRegistered(addr1.address)).to.be.true;
  });

  it("Should assign credits through manager", async function () {
    await carbonCreditsManager.registerNode(addr1.address);
    await carbonCreditsManager.assignCredits(addr1.address, 100);
    expect(await carbonCredits.getCredits(addr1.address)).to.equal(100);
  });
});