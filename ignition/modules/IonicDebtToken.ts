import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { getCurrentNetworkConfig } from "../config/index.js";
import { zeroAddress } from "viem";
/**
 * IonicDebtToken Ignition Module
 *
 * This module deploys:
 * 1. The IonicDebtToken implementation contract
 * 2. A TransparentUpgradeableProxy pointing to that implementation
 * 3. A ProxyAdmin to manage the proxy
 * 4. Initializes the contract with MasterPriceOracle and USDC addresses
 * 5. Configures whitelisted tokens with calculated scale factors
 */
const IonicDebtTokenModule = buildModule("IonicDebtTokenModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  // Get configuration for the current network
  const networkConfig = getCurrentNetworkConfig();

  // Core deployment parameters with defaults and overrides from config
  const masterPriceOracleAddress = m.getParameter(
    "masterPriceOracleAddress",
    networkConfig?.masterPriceOracleAddress || zeroAddress
  );

  const usdcAddress = m.getParameter(
    "usdcAddress",
    networkConfig?.usdcAddress || zeroAddress
  );

  // Token configurations for calculating scale factors
  const tokenConfigs = m.getParameter(
    "tokenConfigs",
    networkConfig?.tokenConfigs || []
  );

  // Deploy the implementation contract
  const implementation = m.contract("IonicDebtToken");

  const encodedFunctionCall = m.encodeFunctionCall(
    implementation,
    "initialize",
    [proxyAdminOwner, masterPriceOracleAddress, usdcAddress]
  );

  // Deploy the IonicDebtTokenProxy pointing to the implementation
  const proxy = m.contract("IonicDebtTokenProxy", [
    implementation,
    proxyAdminOwner,
    encodedFunctionCall,
  ]);

  const proxyAdminAddress = m.readEventArgument(
    proxy,
    "AdminChanged",
    "newAdmin"
  );

  const proxyAdmin = m.contractAt(
    "IonicDebtTokenProxyAdmin",
    proxyAdminAddress
  );

  // Cast the proxy to IonicDebtToken type for contract interactions
  const ionicDebtToken = m.contractAt("IonicDebtToken", proxy, {
    id: "IonicDebtTokenProxyInstance",
  });

  // No need to call initialize again since we already passed it in the constructor
  // The encodedFunctionCall already contains the initialize call

  // Calculate scale factors and whitelist tokens
  if (tokenConfigs && Array.isArray(tokenConfigs)) {
    for (const token of tokenConfigs) {
      // Base of 1e18 (18 decimal places)
      const BASE = "1000000000000000000";
      let scaleFactor;

      if (token.totalSupplied === "0") {
        // If total supplied is 0, use a scale factor of 1 (100%)
        scaleFactor = BASE;
      } else {
        // Use string math operations via BigInt
        const totalSupplied = BigInt(token.totalSupplied);
        const illegitimateBorrowed = BigInt(token.illegitimateBorrowed);
        const base = BigInt(BASE);

        // Calculate legitimate percentage: (totalSupplied - illegitimateBorrowed) * 1e18 / totalSupplied
        const legitimatePercentage =
          ((totalSupplied - illegitimateBorrowed) * base) / totalSupplied;

        // The scale factor is the inverse of the legitimate percentage
        // If 70% is legitimate, scale factor should be 1/0.7 ≈ 1.429
        scaleFactor = (base * base) / legitimatePercentage;
      }

      // Whitelist the token with the calculated scale factor
      m.call(ionicDebtToken, "whitelistIonToken", [
        token.address,
        scaleFactor.toString(),
      ]);
    }
  }

  return {
    implementation,
    proxyAdmin,
    proxy,
    ionicDebtToken,
  };
});

export default IonicDebtTokenModule;
