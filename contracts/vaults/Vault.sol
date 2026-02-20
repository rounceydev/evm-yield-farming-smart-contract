// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IController.sol";

/**
 * @title Vault
 * @notice Yearn Finance-inspired yield farming vault
 * @dev Users deposit underlying tokens and receive shares that accrue yield
 */
contract Vault is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IVault
{
    using SafeERC20 for IERC20;

    /// @dev Role identifiers
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Underlying token
    IERC20 public underlying;

    /// @notice Controller contract
    IController public controller;

    /// @notice Performance fee (in basis points, e.g., 2000 = 20%)
    uint256 public performanceFee;

    /// @notice Management fee (annual, in basis points, e.g., 200 = 2%)
    uint256 public managementFee;

    /// @notice Withdrawal fee (in basis points)
    uint256 public withdrawalFee;

    /// @notice Treasury address for fees
    address public treasury;

    /// @notice Last harvest timestamp
    uint256 public lastHarvest;

    /// @notice Total assets at last harvest
    uint256 public lastTotalAssets;

    /// @notice Emergency shutdown flag
    bool public emergencyShutdown;

    /// @notice Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    event Harvest(uint256 amount, uint256 performanceFee, uint256 managementFee);
    event StrategySet(address indexed oldStrategy, address indexed newStrategy);
    event EmergencyShutdown(bool active);
    event FeesUpdated(uint256 performanceFee, uint256 managementFee, uint256 withdrawalFee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the vault
     * @param _underlying Underlying token address
     * @param _controller Controller address
     * @param _performanceFee Performance fee in basis points
     * @param _managementFee Management fee in basis points
     * @param _withdrawalFee Withdrawal fee in basis points
     * @param _treasury Treasury address
     * @param admin Admin address
     */
    function initialize(
        address _underlying,
        address _controller,
        uint256 _performanceFee,
        uint256 _managementFee,
        uint256 _withdrawalFee,
        address _treasury,
        address admin
    ) public initializer {
        require(_underlying != address(0), "Vault: invalid underlying");
        require(_controller != address(0), "Vault: invalid controller");
        require(_treasury != address(0), "Vault: invalid treasury");
        require(admin != address(0), "Vault: invalid admin");

        string memory name = string.concat("Vault ", IERC20(_underlying).symbol());
        string memory symbol = string.concat("yv", IERC20(_underlying).symbol());

        __ERC20_init(name, symbol);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        underlying = IERC20(_underlying);
        controller = IController(_controller);
        performanceFee = _performanceFee;
        managementFee = _managementFee;
        withdrawalFee = _withdrawalFee;
        treasury = _treasury;
        lastHarvest = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
        _grantRole(STRATEGIST_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /**
     * @notice Deposit underlying tokens and receive vault shares
     */
    function deposit(uint256 amount) external override returns (uint256) {
        return deposit(amount, msg.sender);
    }

    /**
     * @notice Deposit underlying tokens for a specific recipient
     */
    function deposit(
        uint256 amount,
        address recipient
    ) public override nonReentrant whenNotPaused returns (uint256) {
        require(!emergencyShutdown, "Vault: emergency shutdown");
        require(amount > 0, "Vault: invalid amount");
        require(recipient != address(0), "Vault: invalid recipient");

        uint256 shares = _deposit(amount, recipient);
        emit Deposit(recipient, amount, shares);
        return shares;
    }

    /**
     * @notice Internal deposit function
     */
    function _deposit(uint256 amount, address recipient) internal returns (uint256) {
        uint256 totalAssetsBefore = totalAssets();
        underlying.safeTransferFrom(msg.sender, address(this), amount);

        // Deploy to strategy if exists
        address strategy = controller.getStrategy(address(this));
        if (strategy != address(0)) {
            underlying.safeApprove(strategy, amount);
            IStrategy(strategy).deposit(amount);
            underlying.safeApprove(strategy, 0);
        }

        uint256 totalAssetsAfter = totalAssets();
        uint256 shares = 0;

        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply()) / totalAssetsBefore;
        }

        _mint(recipient, shares);
        return shares;
    }

    /**
     * @notice Withdraw underlying tokens by burning shares
     */
    function withdraw(uint256 shares) external override returns (uint256) {
        return withdraw(shares, 0);
    }

    /**
     * @notice Withdraw underlying tokens with minimum amount protection
     */
    function withdraw(
        uint256 shares,
        uint256 minAmountOut
    ) public override nonReentrant whenNotPaused returns (uint256) {
        require(shares > 0, "Vault: invalid shares");
        require(balanceOf(msg.sender) >= shares, "Vault: insufficient shares");

        uint256 amount = _withdraw(shares);
        require(amount >= minAmountOut, "Vault: insufficient output");

        emit Withdraw(msg.sender, shares, amount);
        return amount;
    }

    /**
     * @notice Internal withdraw function
     */
    function _withdraw(uint256 shares) internal returns (uint256) {
        uint256 totalAssetsBefore = totalAssets();
        uint256 amount = (shares * totalAssetsBefore) / totalSupply();

        // Withdraw from strategy if needed
        address strategy = controller.getStrategy(address(this));
        if (strategy != address(0)) {
            uint256 strategyBalance = IStrategy(strategy).balanceOf();
            if (amount > underlying.balanceOf(address(this))) {
                uint256 needed = amount - underlying.balanceOf(address(this));
                if (needed > strategyBalance) {
                    needed = strategyBalance;
                }
                IStrategy(strategy).withdraw(needed);
            }
        }

        // Apply withdrawal fee
        uint256 fee = (amount * withdrawalFee) / 10000;
        if (fee > 0) {
            underlying.safeTransfer(treasury, fee);
            amount -= fee;
        }

        _burn(msg.sender, shares);
        underlying.safeTransfer(msg.sender, amount);
        return amount;
    }

    /**
     * @notice Returns the total assets managed by the vault
     */
    function totalAssets() public view override returns (uint256) {
        uint256 balance = underlying.balanceOf(address(this));
        address strategy = controller.getStrategy(address(this));
        if (strategy != address(0)) {
            balance += IStrategy(strategy).balanceOf();
        }
        return balance;
    }

    /**
     * @notice Returns the underlying token address
     */
    function underlying() external view override returns (address) {
        return address(underlying);
    }

    /**
     * @notice Returns the price per share
     */
    function pricePerShare() public view override returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return (totalAssets() * 1e18) / totalSupply();
    }

    /**
     * @notice Harvest rewards from strategy
     */
    function harvest() external onlyRole(KEEPER_ROLE) {
        address strategy = controller.getStrategy(address(this));
        require(strategy != address(0), "Vault: no strategy");

        uint256 beforeBalance = underlying.balanceOf(address(this));
        uint256 harvested = controller.harvest(address(this));
        uint256 afterBalance = underlying.balanceOf(address(this));

        uint256 profit = afterBalance - beforeBalance;
        if (profit > 0) {
            // Calculate fees
            uint256 perfFee = (profit * performanceFee) / 10000;
            uint256 mgmtFee = _calculateManagementFee();

            if (perfFee > 0) {
                underlying.safeTransfer(treasury, perfFee);
                profit -= perfFee;
            }

            if (mgmtFee > 0) {
                underlying.safeTransfer(treasury, mgmtFee);
            }

            // Reinvest remaining profit
            underlying.safeApprove(strategy, profit);
            IStrategy(strategy).deposit(profit);
            underlying.safeApprove(strategy, 0);

            lastHarvest = block.timestamp;
            lastTotalAssets = totalAssets();

            emit Harvest(harvested, perfFee, mgmtFee);
        }
    }

    /**
     * @notice Calculate management fee
     */
    function _calculateManagementFee() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvest;
        uint256 assets = totalAssets();
        return (assets * managementFee * timeElapsed) / (10000 * 365 days);
    }

    /**
     * @notice Emergency withdraw all assets
     */
    function emergencyWithdraw() external onlyRole(GOVERNANCE_ROLE) {
        emergencyShutdown = true;
        address strategy = controller.getStrategy(address(this));
        if (strategy != address(0)) {
            IStrategy(strategy).withdrawAll();
        }
        emit EmergencyShutdown(true);
    }

    /**
     * @notice Set fees
     */
    function setFees(
        uint256 _performanceFee,
        uint256 _managementFee,
        uint256 _withdrawalFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_performanceFee <= 5000, "Vault: performance fee too high");
        require(_managementFee <= 1000, "Vault: management fee too high");
        require(_withdrawalFee <= 1000, "Vault: withdrawal fee too high");

        performanceFee = _performanceFee;
        managementFee = _managementFee;
        withdrawalFee = _withdrawalFee;

        emit FeesUpdated(_performanceFee, _managementFee, _withdrawalFee);
    }

    /**
     * @notice Set treasury address
     */
    function setTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        require(_treasury != address(0), "Vault: invalid treasury");
        treasury = _treasury;
    }

    /**
     * @notice Pause all operations
     */
    function pause() external onlyRole(GOVERNANCE_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause all operations
     */
    function unpause() external onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    /**
     * @notice Authorizes upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
