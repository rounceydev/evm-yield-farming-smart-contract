// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IController.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";

/**
 * @title Controller
 * @notice Manages vaults and their strategies
 */
contract Controller is IController, AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    /// @notice Mapping from vault to strategy
    mapping(address => address) public strategies;

    /// @notice Events
    event StrategySet(address indexed vault, address indexed oldStrategy, address indexed newStrategy);
    event Harvested(address indexed vault, uint256 amount);
    event StrategyMigrated(address indexed vault, address indexed oldStrategy, address indexed newStrategy);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
        _grantRole(STRATEGIST_ROLE, admin);
    }

    /**
     * @notice Set strategy for a vault
     */
    function setStrategy(address vault, address strategy) external override onlyRole(STRATEGIST_ROLE) {
        require(vault != address(0), "Controller: invalid vault");
        require(strategy == address(0) || IStrategy(strategy).vault() == vault, "Controller: invalid strategy");

        address oldStrategy = strategies[vault];
        strategies[vault] = strategy;

        emit StrategySet(vault, oldStrategy, strategy);
    }

    /**
     * @notice Get strategy for a vault
     */
    function getStrategy(address vault) external view override returns (address) {
        return strategies[vault];
    }

    /**
     * @notice Harvest rewards from a strategy
     */
    function harvest(address vault) external override onlyRole(KEEPER_ROLE) nonReentrant returns (uint256) {
        address strategy = strategies[vault];
        require(strategy != address(0), "Controller: no strategy");

        uint256 harvested = IStrategy(strategy).harvest();
        emit Harvested(vault, harvested);
        return harvested;
    }

    /**
     * @notice Migrate vault to a new strategy
     */
    function migrateStrategy(
        address vault,
        address newStrategy
    ) external override onlyRole(GOVERNANCE_ROLE) nonReentrant {
        require(vault != address(0), "Controller: invalid vault");
        require(newStrategy != address(0), "Controller: invalid new strategy");
        require(IStrategy(newStrategy).vault() == vault, "Controller: strategy vault mismatch");

        address oldStrategy = strategies[vault];
        require(oldStrategy != address(0), "Controller: no existing strategy");

        // Migrate assets
        IStrategy(oldStrategy).migrate(newStrategy);

        // Update strategy
        strategies[vault] = newStrategy;

        emit StrategyMigrated(vault, oldStrategy, newStrategy);
    }
}
