const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("\n🚀 Starting E-Waste Marketplace Deployment...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`📋 Deploying from account: ${deployer.address}`);
  console.log(`💰 Account balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);

  // Define initial sellers and recyclers
  // In production, these should be loaded from environment variables
  const initialSellers = [
    deployer.address, // Deployer is also a seller for testing
    // Add seller addresses: "0x..."
  ];

  const initialRecyclers = [
    // Add recycler addresses: "0x..."
  ];

  console.log(`👥 Initial Sellers: ${initialSellers.length}`);
  console.log(`♻️  Initial Recyclers: ${initialRecyclers.length}\n`);

  // Deploy EWasteTransactions contract
  console.log("📦 Deploying EWasteTransactions contract...");
  const EWasteTransactions = await ethers.getContractFactory("EWasteTransactions");
  const eWasteTransactions = await EWasteTransactions.deploy(initialSellers, initialRecyclers);
  
  await eWasteTransactions.waitForDeployment();
  const eWasteAddress = await eWasteTransactions.getAddress();
  console.log(`✅ EWasteTransactions deployed to: ${eWasteAddress}\n`);

  // Save deployment info to file
  const deploymentInfo = {
    network: hre.network.name,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      EWasteTransactions: {
        address: eWasteAddress,
        type: "ERC-721",
        description: "E-Waste Marketplace Transaction Tracking"
      }
    },
    initialRoles: {
      sellers: initialSellers,
      recyclers: initialRecyclers
    }
  };

  const deploymentPath = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentPath)) {
    fs.mkdirSync(deploymentPath, { recursive: true });
  }

  const filename = `deployment-${hre.network.name}-${Date.now()}.json`;
  fs.writeFileSync(path.join(deploymentPath, filename), JSON.stringify(deploymentInfo, null, 2));
  console.log(`📄 Deployment info saved to: deployments/${filename}\n`);

  // Verify contract on Etherscan (if not on localhost)
  if (hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    console.log("⏳ Waiting 30 seconds before Etherscan verification...\n");
    await new Promise(resolve => setTimeout(resolve, 30000));

    try {
      console.log("🔍 Verifying contract on Etherscan...");
      await hre.run("verify:verify", {
        address: eWasteAddress,
        constructorArguments: [initialSellers, initialRecyclers]
      });
      console.log("✅ Contract verified on Etherscan!\n");
    } catch (err) {
      console.log(`⚠️  Etherscan verification skipped or failed: ${err.message}\n`);
    }
  }

  // Print summary
  console.log("=".repeat(55));
  console.log("✅ DEPLOYMENT SUCCESSFUL");
  console.log("=".repeat(55));
  console.log(`Network: ${hre.network.name}`);
  console.log(`EWasteTransactions: ${eWasteAddress}`);
  console.log("=".repeat(55) + "\n");

  return eWasteAddress;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
