/**
 * Configuration for Mode Mainnet IonicDebtToken deployment
 */
export const modeMainnetConfig = {
  // Core deployment parameters
  masterPriceOracleAddress: "0x1234567890123456789012345678901234567890", // Mode mainnet master price oracle address
  usdcAddress: "0xd988097fb8612ae244b87df08e2abe6c3f25b08b", // Mode mainnet USDC address

  // Token configurations
  tokenConfigs: [
    // Replace with actual Mode mainnet tokens
    {
      address: "0x2345678901234567890123456789012345678901", // Sample Ion Token address
      totalSupplied: "1000000000000000000000", // 1000 tokens (with 18 decimals)
      illegitimateBorrowed: "300000000000000000000", // 300 tokens (30% illegitimate)
    },
    // Add more tokens as needed
    {
      address: "0x3456789012345678901234567890123456789012", // Another token address
      totalSupplied: "500000000000000000000", // 500 tokens (with 18 decimals)
      illegitimateBorrowed: "100000000000000000000", // 100 tokens (20% illegitimate)
    },
  ],
};
