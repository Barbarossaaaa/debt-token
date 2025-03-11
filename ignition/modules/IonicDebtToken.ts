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
  const masterPriceOracleAddress = networkConfig?.masterPriceOracleAddress;
  console.log(
    "🚀 ~ IonicDebtTokenModule ~ masterPriceOracleAddress:",
    masterPriceOracleAddress
  );

  const usdcAddress = networkConfig?.usdcAddress;
  console.log("🚀 ~ IonicDebtTokenModule ~ usdcAddress:", usdcAddress);

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
    // Use SCALE_PRECISION (10000) for 4 decimal places of precision
    const SCALE_PRECISION = BigInt("10000");
    let scaleFactor;

    if (token.totalSupplied === "0") {
      throw new Error("Total supplied is 0");
    } else {
      // Use string math operations via BigInt
      const totalSupplied = BigInt(token.totalSupplied);
      const illegitimateBorrowed = BigInt(token.illegitimateBorrowed);

      // Calculate legitimate percentage with 4 decimal precision
      // Example: if 98.2% is legitimate, legitimatePercentage = 9820
      const legitimatePercentage =
        ((totalSupplied - illegitimateBorrowed) * SCALE_PRECISION) /
        totalSupplied;

      // Calculate scale factor
      // If 98.2% is legitimate (legitimatePercentage = 9820),
      // scaleFactor = (10000 * 10000) / 9820 ≈ 10183
      scaleFactor = (SCALE_PRECISION * SCALE_PRECISION) / legitimatePercentage;

      // Ensure scale factor is within valid range
      if (scaleFactor > SCALE_PRECISION * 100n) {
        console.log(
          `Warning: Scale factor ${scaleFactor} for ${
            token.address
          } exceeds maximum. Capping at ${SCALE_PRECISION * 100n}`
        );
        scaleFactor = SCALE_PRECISION * 100n;
      } else if (scaleFactor < SCALE_PRECISION) {
        console.log(
          `Warning: Scale factor ${scaleFactor} for ${token.address} is below minimum. Setting to ${SCALE_PRECISION}`
        );
        scaleFactor = SCALE_PRECISION;
      }
    }

    // Whitelist the token with the calculated scale factor
    m.call(
      ionicDebtToken,
      "whitelistIonToken",
      [token.address, scaleFactor.toString()],
      { id: `whitelist_${token.address}` }
    );

    console.log(
      `Whitelisted ${token.address} with scale factor ${scaleFactor} (${Number(
        BigInt("10000000000") / scaleFactor / 100n
      )}% of value)`
    );
  }

  return {
    implementation,
    proxyAdmin,
    proxy,
    ionicDebtToken,
  };
});

export default IonicDebtTokenModule;
