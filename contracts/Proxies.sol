// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// We import these here to force Hardhat to compile them.
// This ensures that their artifacts are available for Hardhat Ignition to use.
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Create contract interfaces that extend the OpenZeppelin contracts
// This ensures they'll be compiled and artifacts will be generated
contract IonicDebtTokenProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, admin_, _data) {}
}

contract IonicDebtTokenProxyAdmin is ProxyAdmin {
    constructor(address initialOwner) ProxyAdmin(initialOwner) {}
}