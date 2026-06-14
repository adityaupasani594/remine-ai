const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting Dual Contract Deployment (ERC-20 + ERC-721)...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deploying from account:", deployer.address);

  // Get account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  const balanceInEth = ethers.formatEther(balance);
  console.log("💰 Account balance:", balanceInEth, "ETH\n");

  // ============ Deploy GreenCredits (ERC-20) ============
  console.log("📦 Deploying GreenCredits (ERC-20)...");

  const GreenCredits = await ethers.getContractFactory("GreenCredits");
  const greenCredits = await GreenCredits.deploy(deployer.address);

  console.log("✅ GreenCredits deployed to:", greenCredits.target);

  // Verify deployment
  const greenCreditsName = await greenCredits.name();
  const greenCreditsSymbol = await greenCredits.symbol();
  console.log(`   Name: ${greenCreditsName} (${greenCreditsSymbol})`);
  console.log(`   Decimals: 18`);
  console.log(`   Max Supply: 1,000,000,000 tokens\n`);

  // ============ Deploy RecyclerBadge (ERC-721) ============
  console.log("📦 Deploying RecyclerBadge (ERC-721 Soulbound)...");

  const RecyclerBadge = await ethers.getContractFactory("RecyclerBadge");
  const recyclerBadge = await RecyclerBadge.deploy(deployer.address);

  console.log("✅ RecyclerBadge deployed to:", recyclerBadge.target);

  // Verify deployment
  const badgeName = await recyclerBadge.name();
  const badgeSymbol = await recyclerBadge.symbol();
  console.log(`   Name: ${badgeName} (${badgeSymbol})`);
  console.log(`   Type: Non-Transferable (Soulbound)\n`);

  // ============ Save Deployment Info ============
  const deploymentDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true });
  }

  const timestamp = Date.now();
  const network = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(
    deploymentDir,
    `deployment-dual-${network}-${timestamp}.json`
  );

  const deploymentInfo = {
    network: network,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      GreenCredits: {
        address: greenCredits.target,
        type: "ERC-20",
        name: "Green Credits",
        symbol: "GREEN",
        description: "Reward tokens for e-waste recycling",
        features: ["Mint rewards", "Transfer", "Burn", "AccessControl"]
      },
      RecyclerBadge: {
        address: recyclerBadge.target,
        type: "ERC-721 Soulbound",
        name: "Recycler Badge",
        symbol: "RECYCLE",
        description: "Verification and achievement badges for recyclers",
        features: [
          "Non-transferable",
          "Badge types (Verified, Top, Champion, Pioneer)",
          "Verification tracking",
          "AccessControl"
        ]
      }
    },
    roles: {
      deployer: deployer.address,
      greenCreditsMinter: deployer.address,
      badgeMinter: deployer.address
    },
    totalDeployed: 2
  };

  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("📄 Deployment info saved to:", deploymentFile);

  // ============ Deployment Summary ============
  console.log("\n=======================================================");
  console.log("✅ DUAL CONTRACT DEPLOYMENT SUCCESSFUL");
  console.log("=======================================================");
  console.log(`Network: ${network}`);
  console.log(`GreenCredits (ERC-20): ${greenCredits.target}`);
  console.log(`RecyclerBadge (ERC-721): ${recyclerBadge.target}`);
  console.log("=======================================================\n");

  // ============ Initial Setup (Optional) ============
  console.log("🔧 Optional: Performing initial setup...\n");

  // Mint a test badge
  try {
    console.log("📌 Minting test badge for deployer...");
    const badgeTx = await recyclerBadge.mintBadge(
      deployer.address,
      0, // VERIFIED_RECYCLER
      "Deployer - Initial Setup"
    );
    await badgeTx.wait();
    console.log("✅ Test badge minted successfully\n");
  } catch (error) {
    console.log("⚠️  Could not mint test badge:", error.message, "\n");
  }

  // Mint test credits
  try {
    console.log("💚 Minting test credits for deployer...");
    const amount = ethers.parseEther("1000"); // 1000 GREEN tokens
    const creditsTx = await greenCredits.mintCredits(
      deployer.address,
      amount,
      "deployment_test"
    );
    await creditsTx.wait();

    const balance = await greenCredits.balanceOf(deployer.address);
    const balanceReadable = ethers.formatEther(balance);
    console.log(`✅ Test credits minted: ${balanceReadable} GREEN tokens\n`);
  } catch (error) {
    console.log("⚠️  Could not mint test credits:", error.message, "\n");
  }

  console.log("🚀 Ready for integration with your E-Waste Marketplace!\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error.message);
    process.exit(1);
  });
