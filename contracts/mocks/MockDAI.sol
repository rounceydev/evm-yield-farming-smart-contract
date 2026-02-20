// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockUnderlying.sol";

/**
 * @title MockDAI
 * @notice Mock DAI token for testing
 */
contract MockDAI is MockUnderlying {
    constructor() MockUnderlying("Mock DAI", "mDAI", 18, 10000000 * 10**18) {}
}
