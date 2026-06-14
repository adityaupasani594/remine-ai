import { ethers } from "hardhat";

async function main() {
  console.log("Deploying Smart Contracts...\n");

  // Deploy EWasteTransactions contract
  console.log("Deploying EWasteTransactions contract...");
  const EWasteTransactions = await ethers.getContractFactory("EWasteTransactions");
  const eWasteTransactions = await EWasteTransactions.deploy();
  await eWasteTransactions.waitForDeployment();
  const eWasteAddress = await eWasteTransactions.getAddress();
  console.log("✓ EWasteTransactions deployed to:", eWasteAddress);

  // Deploy CarbonCredits contract
  console.log("\nDeploying Carbon Credits contracts...");
  const CarbonCredits = await ethers.getContractFactory("CarbonCredits");
  const carbonCredits = await CarbonCredits.deploy();
  await carbonCredits.waitForDeployment();
  const carbonCreditsAddress = await carbonCredits.getAddress();
  console.log("✓ CarbonCredits deployed to:", carbonCreditsAddress);

  // Deploy CarbonCreditsManager contract
  const CarbonCreditsManager = await ethers.getContractFactory("CarbonCreditsManager");
  const carbonCreditsManager = await CarbonCreditsManager.deploy(carbonCreditsAddress);
  await carbonCreditsManager.waitForDeployment();
  const managerAddress = await carbonCreditsManager.getAddress();
  console.log("✓ CarbonCreditsManager deployed to:", managerAddress);

  console.log("\n=== Deployment Summary ===");
  console.log("EWasteTransactions:", eWasteAddress);
  console.log("CarbonCredits:", carbonCreditsAddress);
  console.log("CarbonCreditsManager:", managerAddress);
  console.log("========================\n");
  console.log("All contracts deployed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });