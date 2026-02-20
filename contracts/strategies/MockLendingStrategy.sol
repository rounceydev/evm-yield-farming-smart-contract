// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseStrategy.sol";
import "../interfaces/IStrategy.sol";
import "../mocks/MockRewardToken.sol";

/**
 * @title MockLendingStrategy
 * @notice Mock strategy that simulates yield generation via time-based accrual
 * @dev For testing purposes - simulates a lending protocol that accrues yield over time
 */
contract MockLendingStrategy is BaseStrategy {
    /// @notice Annual yield rate (in basis points, e.g., 500 = 5%)
    uint256 public yieldRate;

    /// @notice Last update timestamp
    uint256 public lastUpdate;

    /// @notice Deposited amount
    uint256 public depositedAmount;

    /// @notice Accrued yield
    uint256 public accruedYield;

    /// @notice Reward token (mock)
    MockRewardToken public rewardToken;

    /// @notice Events
    event YieldAccrued(uint256 amount);

    constructor(
        address _vault,
        address _rewardToken,
        uint256 _yieldRate
    ) BaseStrategy(_vault, "MockLendingStrategy") {
        require(_rewardToken != address(0), "MockLendingStrategy: invalid reward token");
        rewardToken = MockRewardToken(_rewardToken);
        yieldRate = _yieldRate;
        lastUpdate = block.timestamp;
    }

    /**
     * @notice Deposit assets
     */
    function _deposit(uint256 amount) internal override {
        depositedAmount += amount;
        lastUpdate = block.timestamp;
    }

    /**
     * @notice Withdraw assets
     */
    function _withdraw(uint256 amount) internal override returns (uint256) {
        _accrueYield();
        if (amount > depositedAmount) {
            amount = depositedAmount;
        }
        depositedAmount -= amount;
        underlying.safeTransfer(vault, amount);
        return amount;
    }

    /**
     * @notice Harvest rewards
     */
    function _harvest() internal override returns (uint256) {
        _accrueYield();
        uint256 yield = accruedYield;
        if (yield > 0) {
            // Mint reward tokens
            rewardToken.mint(address(this), yield);
            rewardToken.transfer(vault, yield);
            accruedYield = 0;
            lastUpdate = block.timestamp;
        }
        return yield;
    }

    /**
     * @notice Accrue yield based on time elapsed
     */
    function _accrueYield() internal {
        if (depositedAmount == 0) {
            lastUpdate = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 newYield = (depositedAmount * yieldRate * timeElapsed) / (10000 * 365 days);
        accruedYield += newYield;
        lastUpdate = block.timestamp;

        emit YieldAccrued(newYield);
    }

    /**
     * @notice Returns total assets managed
     */
    function balanceOf() public view override returns (uint256) {
        if (depositedAmount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 pendingYield = (depositedAmount * yieldRate * timeElapsed) / (10000 * 365 days);
        return depositedAmount + pendingYield;
    }

    /**
     * @notice Set yield rate
     */
    function setYieldRate(uint256 _yieldRate) external onlyOwner {
        _accrueYield();
        yieldRate = _yieldRate;
    }
}
