const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    // Deploy Mock Tokens
    console.log("\n=== Deploying Mock Tokens ===");
    const MockDAI = await ethers.getContractFactory("MockDAI");
    const mockDAI = await MockDAI.deploy();
    await mockDAI.waitForDeployment();
    console.log("MockDAI deployed to:", mockDAI.target);

    const MockRewardToken = await ethers.getContractFactory("MockRewardToken");
    const mockRewardToken = await MockRewardToken.deploy();
    await mockRewardToken.waitForDeployment();
    console.log("MockRewardToken deployed to:", mockRewardToken.target);

    // Deploy Controller
    console.log("\n=== Deploying Controller ===");
    const Controller = await ethers.getContractFactory("Controller");
    const controller = await Controller.deploy(deployer.address);
    await controller.waitForDeployment();
    console.log("Controller deployed to:", controller.target);

    // Deploy Vault (UUPS Proxy)
    console.log("\n=== Deploying Vault (UUPS Proxy) ===");
    const Vault = await ethers.getContractFactory("Vault");
    const vault = await upgrades.deployProxy(
        Vault,
        [
            mockDAI.target,
            controller.target,
            2000, // 20% performance fee
            200, // 2% management fee
            0, // 0% withdrawal fee
            deployer.address, // treasury
            deployer.address, // admin
        ],
        { initializer: "initialize" }
    );
    await vault.waitForDeployment();
    console.log("Vault (proxy) deployed to:", vault.target);

    const vaultImplementation = await upgrades.erc1967.getImplementationAddress(vault.target);
    console.log("Vault (implementation) deployed to:", vaultImplementation);

    // Deploy Strategy
    console.log("\n=== Deploying Strategy ===");
    const MockLendingStrategy = await ethers.getContractFactory("MockLendingStrategy");
    const strategy = await MockLendingStrategy.deploy(
        vault.target,
        mockRewardToken.target,
        500 // 5% APY
    );
    await strategy.waitForDeployment();
    console.log("MockLendingStrategy deployed to:", strategy.target);

    // Set strategy in controller
    console.log("\n=== Configuring Strategy ===");
    await controller.setStrategy(vault.target, strategy.target);
    console.log("Strategy set for vault");

    // Grant roles
    const KEEPER_ROLE = await vault.KEEPER_ROLE();
    await vault.grantRole(KEEPER_ROLE, deployer.address);
    console.log("Keeper role granted to deployer");

    console.log("\n=== Deployment Summary ===");
    console.log("Mock Tokens:");
    console.log("  DAI:", mockDAI.target);
    console.log("  Reward Token:", mockRewardToken.target);
    console.log("\nController:", controller.target);
    console.log("\nVault:");
    console.log("  Proxy:", vault.target);
    console.log("  Implementation:", vaultImplementation);
    console.log("\nStrategy:", strategy.target);

    console.log("\n=== Next Steps ===");
    console.log("1. Deposit: vault.deposit(amount)");
    console.log("2. Harvest: vault.harvest()");
    console.log("3. Withdraw: vault.withdraw(shares)");
    console.log("4. Check price: vault.pricePerShare()");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
