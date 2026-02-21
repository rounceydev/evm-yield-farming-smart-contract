const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Vault", function () {
    async function deployVaultFixture() {
        const [owner, user1, user2, keeper, treasury] = await ethers.getSigners();

        // Deploy mock tokens
        const MockDAI = await ethers.getContractFactory("MockDAI");
        const mockDAI = await MockDAI.deploy();
        await mockDAI.waitForDeployment();

        const MockRewardToken = await ethers.getContractFactory("MockRewardToken");
        const mockRewardToken = await MockRewardToken.deploy();
        await mockRewardToken.waitForDeployment();

        // Deploy Controller
        const Controller = await ethers.getContractFactory("Controller");
        const controller = await Controller.deploy(owner.address);
        await controller.waitForDeployment();

        // Deploy Vault first
        const Vault = await ethers.getContractFactory("Vault");
        const vault = await upgrades.deployProxy(
            Vault,
            [
                mockDAI.target,
                controller.target,
                2000, // 20% performance fee
                200, // 2% management fee
                0, // 0% withdrawal fee
                treasury.address,
                owner.address,
            ],
            { initializer: "initialize" }
        );
        await vault.waitForDeployment();

        // Deploy Strategy with vault address
        const MockLendingStrategy = await ethers.getContractFactory("MockLendingStrategy");
        const strategy = await MockLendingStrategy.deploy(
            vault.target,
            mockRewardToken.target,
            500 // 5% APY
        );
        await strategy.waitForDeployment();

        // Set strategy in controller
        await controller.setStrategy(vault.target, strategy.target);

        // Grant keeper role
        const KEEPER_ROLE = await vault.KEEPER_ROLE();
        await vault.grantRole(KEEPER_ROLE, keeper.address);

        return {
            owner,
            user1,
            user2,
            keeper,
            treasury,
            mockDAI,
            mockRewardToken,
            controller,
            strategy,
            vault,
        };
    }

    describe("Deployment", function () {
        it("Should initialize correctly", async function () {
            const { vault, mockDAI, controller, treasury } = await loadFixture(deployVaultFixture);

            expect(await vault.underlying()).to.equal(mockDAI.target);
            expect(await vault.controller()).to.equal(controller.target);
            expect(await vault.treasury()).to.equal(treasury.address);
            expect(await vault.performanceFee()).to.equal(2000);
            expect(await vault.managementFee()).to.equal(200);
        });
    });

    describe("Deposit", function () {
        it("Should allow users to deposit", async function () {
            const { vault, mockDAI, user1 } = await loadFixture(deployVaultFixture);

            const amount = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user1.address, amount);
            await mockDAI.connect(user1).approve(vault.target, amount);

            await vault.connect(user1).deposit(amount);

            const shares = await vault.balanceOf(user1.address);
            expect(shares).to.be.gt(0);
        });

        it("Should mint shares proportionally", async function () {
            const { vault, mockDAI, user1, user2 } = await loadFixture(deployVaultFixture);

            const amount1 = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user1.address, amount1);
            await mockDAI.connect(user1).approve(vault.target, amount1);
            await vault.connect(user1).deposit(amount1);

            const shares1 = await vault.balanceOf(user1.address);

            const amount2 = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user2.address, amount2);
            await mockDAI.connect(user2).approve(vault.target, amount2);
            await vault.connect(user2).deposit(amount2);

            const shares2 = await vault.balanceOf(user2.address);
            expect(shares2).to.equal(shares1);
        });
    });

    describe("Withdraw", function () {
        it("Should allow users to withdraw", async function () {
            const { vault, mockDAI, user1 } = await loadFixture(deployVaultFixture);

            const depositAmount = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user1.address, depositAmount);
            await mockDAI.connect(user1).approve(vault.target, depositAmount);
            await vault.connect(user1).deposit(depositAmount);

            const shares = await vault.balanceOf(user1.address);
            const balanceBefore = await mockDAI.balanceOf(user1.address);

            await vault.connect(user1).withdraw(shares);

            const balanceAfter = await mockDAI.balanceOf(user1.address);
            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should revert if insufficient shares", async function () {
            const { vault, user1 } = await loadFixture(deployVaultFixture);

            await expect(vault.connect(user1).withdraw(ethers.parseUnits("1000", 18))).to.be.revertedWith(
                "Vault: insufficient shares"
            );
        });
    });

    describe("Yield Accrual", function () {
        it("Should accrue yield over time", async function () {
            const { vault, mockDAI, user1, keeper } = await loadFixture(deployVaultFixture);

            const amount = ethers.parseUnits("10000", 18);
            await mockDAI.transfer(user1.address, amount);
            await mockDAI.connect(user1).approve(vault.target, amount);
            await vault.connect(user1).deposit(amount);

            const shares = await vault.balanceOf(user1.address);
            const priceBefore = await vault.pricePerShare();

            // Fast forward 1 year
            await time.increase(365 * 24 * 60 * 60);
            await ethers.provider.send("evm_mine", []);

            // Harvest
            await vault.connect(keeper).harvest();

            const priceAfter = await vault.pricePerShare();
            expect(priceAfter).to.be.gt(priceBefore);
        });
    });

    describe("Fees", function () {
        it("Should charge performance fee on harvest", async function () {
            const { vault, mockDAI, mockRewardToken, user1, keeper, treasury } = await loadFixture(
                deployVaultFixture
            );

            const amount = ethers.parseUnits("10000", 18);
            await mockDAI.transfer(user1.address, amount);
            await mockDAI.connect(user1).approve(vault.target, amount);
            await vault.connect(user1).deposit(amount);

            // Fast forward and harvest
            await time.increase(365 * 24 * 60 * 60);
            await ethers.provider.send("evm_mine", []);

            const treasuryBalanceBefore = await mockDAI.balanceOf(treasury.address);
            await vault.connect(keeper).harvest();
            const treasuryBalanceAfter = await mockDAI.balanceOf(treasury.address);

            expect(treasuryBalanceAfter).to.be.gt(treasuryBalanceBefore);
        });
    });

    describe("Emergency Shutdown", function () {
        it("Should allow emergency withdrawal", async function () {
            const { vault, mockDAI, user1, owner } = await loadFixture(deployVaultFixture);

            const amount = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user1.address, amount);
            await mockDAI.connect(user1).approve(vault.target, amount);
            await vault.connect(user1).deposit(amount);

            await vault.connect(owner).emergencyWithdraw();
            expect(await vault.emergencyShutdown()).to.be.true;

            await expect(vault.connect(user1).deposit(amount)).to.be.revertedWith(
                "Vault: emergency shutdown"
            );
        });
    });

    describe("Pausability", function () {
        it("Should pause and unpause correctly", async function () {
            const { vault, owner } = await loadFixture(deployVaultFixture);

            await vault.connect(owner).pause();
            expect(await vault.paused()).to.be.true;

            await vault.connect(owner).unpause();
            expect(await vault.paused()).to.be.false;
        });

        it("Should prevent operations when paused", async function () {
            const { vault, mockDAI, user1, owner } = await loadFixture(deployVaultFixture);

            await vault.connect(owner).pause();

            const amount = ethers.parseUnits("1000", 18);
            await mockDAI.transfer(user1.address, amount);
            await mockDAI.connect(user1).approve(vault.target, amount);

            await expect(vault.connect(user1).deposit(amount)).to.be.revertedWith("Pausable: paused");
        });
    });
});
