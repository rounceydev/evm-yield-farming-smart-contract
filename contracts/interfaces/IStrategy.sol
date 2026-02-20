// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStrategy
 * @notice Interface for yield farming strategies
 */
interface IStrategy {
    /**
     * @notice Returns the name of the strategy
     * @return Strategy name
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the vault address
     * @return Vault address
     */
    function vault() external view returns (address);

    /**
     * @notice Returns the total assets managed by the strategy
     * @return Total assets
     */
    function balanceOf() external view returns (uint256);

    /**
     * @notice Deposit assets into the strategy
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw assets from the strategy
     * @param amount Amount to withdraw
     * @return Amount actually withdrawn
     */
    function withdraw(uint256 amount) external returns (uint256);

    /**
     * @notice Withdraw all assets from the strategy
     * @return Amount withdrawn
     */
    function withdrawAll() external returns (uint256);

    /**
     * @notice Harvest rewards and return to vault
     * @return Amount harvested
     */
    function harvest() external returns (uint256);

    /**
     * @notice Migrate to a new strategy
     * @param newStrategy Address of new strategy
     */
    function migrate(address newStrategy) external;
}
