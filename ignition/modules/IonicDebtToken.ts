import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { getCurrentNetworkConfig } from "../config/index.js";
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
  const masterPriceOracleAddress = networkConfig?.masterPriceOracleAddress;
  const usdcAddress = networkConfig?.usdcAddress;

  // Token configurations for calculating scale factors
  const tokenConfigs = networkConfig?.tokenConfigs;

  if (!tokenConfigs || !masterPriceOracleAddress || !usdcAddress) {
    throw new Error("Missing required parameters");
  }

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
  for (const token of tokenConfigs) {
    const totalSupplied = BigInt(token.totalSupplied);
    const illegitimateBorrowed = BigInt(token.illegitimateBorrowed);

    if (token.totalSupplied === "0") {
      throw new Error("Total supplied is 0");
    } else {
      // Use illegitimateBorrowed as numerator and totalSupplied as denominator
      // This means if 98.2% of tokens were illegitimately borrowed, users will get 98.2% of value
      const numerator = illegitimateBorrowed;
      const denominator = totalSupplied;

      // Whitelist the token with the calculated scale factors
      m.call(
        ionicDebtToken,
        "whitelistIonToken",
        [token.address, numerator.toString(), denominator.toString()],
        { id: `whitelist_${token.address}` }
      );

      // Calculate percentage of value that will be recognized
      const valuePercentage = (illegitimateBorrowed * 100n) / totalSupplied;

      console.log(
        `Whitelisted ${token.address} with scale factor ${numerator}/${denominator} (${valuePercentage}% of value)`
      );
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
