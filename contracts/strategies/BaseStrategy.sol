// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";

/**
 * @title BaseStrategy
 * @notice Abstract base contract for yield farming strategies
 */
abstract contract BaseStrategy is IStrategy, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Vault address
    address public override vault;

    /// @notice Underlying token
    IERC20 public underlying;

    /// @notice Strategy name
    string public override name;

    /// @notice Events
    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);
    event Harvested(uint256 amount);
    event Migrated(address indexed newStrategy);

    constructor(address _vault, string memory _name) Ownable(msg.sender) {
        require(_vault != address(0), "BaseStrategy: invalid vault");
        vault = _vault;
        underlying = IERC20(IVault(_vault).underlying());
        name = _name;
    }

    /**
     * @notice Deposit assets into the strategy
     */
    function deposit(uint256 amount) external override {
        require(msg.sender == vault, "BaseStrategy: only vault");
        _deposit(amount);
        emit Deposited(amount);
    }

    /**
     * @notice Internal deposit function (to be implemented by child)
     */
    function _deposit(uint256 amount) internal virtual;

    /**
     * @notice Withdraw assets from the strategy
     */
    function withdraw(uint256 amount) external override nonReentrant returns (uint256) {
        require(msg.sender == vault, "BaseStrategy: only vault");
        uint256 withdrawn = _withdraw(amount);
        emit Withdrawn(withdrawn);
        return withdrawn;
    }

    /**
     * @notice Internal withdraw function (to be implemented by child)
     */
    function _withdraw(uint256 amount) internal virtual returns (uint256);

    /**
     * @notice Withdraw all assets
     */
    function withdrawAll() external override nonReentrant returns (uint256) {
        require(msg.sender == vault, "BaseStrategy: only vault");
        uint256 balance = balanceOf();
        return withdraw(balance);
    }

    /**
     * @notice Harvest rewards (to be implemented by child)
     */
    function harvest() external virtual override returns (uint256) {
        require(msg.sender == vault || msg.sender == owner(), "BaseStrategy: unauthorized");
        uint256 harvested = _harvest();
        emit Harvested(harvested);
        return harvested;
    }

    /**
     * @notice Internal harvest function (to be implemented by child)
     */
    function _harvest() internal virtual returns (uint256);

    /**
     * @notice Migrate to a new strategy
     */
    function migrate(address newStrategy) external override {
        require(msg.sender == owner(), "BaseStrategy: only owner");
        require(newStrategy != address(0), "BaseStrategy: invalid new strategy");

        uint256 balance = balanceOf();
        if (balance > 0) {
            uint256 withdrawn = _withdraw(balance);
            IERC20(underlying).safeTransfer(newStrategy, withdrawn);
        }

        emit Migrated(newStrategy);
    }

    /**
     * @notice Returns total assets managed (to be implemented by child)
     */
    function balanceOf() public view virtual override returns (uint256);
}
