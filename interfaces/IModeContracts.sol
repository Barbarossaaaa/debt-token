// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IIonToken Interface
 * @notice Interface for ionTokens (similar to Compound's cTokens)
 */
interface IIonToken is IERC20 {
    function exchangeRateCurrent() external returns (uint256);
    function underlying() external view returns (address);
}

/**
 * @title IMasterPriceOracle Interface
 * @notice Interface for the price oracle that provides price feeds
 */
interface IMasterPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
    function price(address underlying) external view returns (uint256);
} 