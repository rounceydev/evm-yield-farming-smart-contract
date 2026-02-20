// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IController
 * @notice Interface for vault controller
 */
interface IController {
    /**
     * @notice Set strategy for a vault
     * @param vault Vault address
     * @param strategy Strategy address
     */
    function setStrategy(address vault, address strategy) external;

    /**
     * @notice Get strategy for a vault
     * @param vault Vault address
     * @return Strategy address
     */
    function getStrategy(address vault) external view returns (address);

    /**
     * @notice Harvest rewards from a strategy
     * @param vault Vault address
     * @return Amount harvested
     */
    function harvest(address vault) external returns (uint256);

    /**
     * @notice Migrate vault to a new strategy
     * @param vault Vault address
     * @param newStrategy New strategy address
     */
    function migrateStrategy(address vault, address newStrategy) external;
}
