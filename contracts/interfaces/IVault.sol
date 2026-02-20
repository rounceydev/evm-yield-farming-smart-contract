// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @notice Interface for yield farming vaults
 */
interface IVault {
    /**
     * @notice Deposit underlying tokens and receive vault shares
     * @param amount Amount of underlying tokens to deposit
     * @return shares Amount of vault shares minted
     */
    function deposit(uint256 amount) external returns (uint256);

    /**
     * @notice Deposit underlying tokens for a specific recipient
     * @param amount Amount of underlying tokens to deposit
     * @param recipient Address to receive vault shares
     * @return shares Amount of vault shares minted
     */
    function deposit(uint256 amount, address recipient) external returns (uint256);

    /**
     * @notice Withdraw underlying tokens by burning shares
     * @param shares Amount of shares to burn
     * @return amount Amount of underlying tokens withdrawn
     */
    function withdraw(uint256 shares) external returns (uint256);

    /**
     * @notice Withdraw underlying tokens with minimum amount protection
     * @param shares Amount of shares to burn
     * @param minAmountOut Minimum amount of underlying tokens to receive
     * @return amount Amount of underlying tokens withdrawn
     */
    function withdraw(uint256 shares, uint256 minAmountOut) external returns (uint256);

    /**
     * @notice Returns the total assets managed by the vault
     * @return Total assets in underlying token units
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Returns the underlying token address
     * @return Address of the underlying token
     */
    function underlying() external view returns (address);

    /**
     * @notice Returns the price per share
     * @return Price per share in underlying token units
     */
    function pricePerShare() external view returns (uint256);
}
