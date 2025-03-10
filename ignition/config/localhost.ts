/**
 * Configuration for localhost IonicDebtToken deployment
 */
export const localhostConfig = {
  // Core deployment parameters
  masterPriceOracleAddress: "0x5FbDB2315678afecb367f032d93F642f64180aa3", // Example address
  usdcAddress: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512", // Example address

  // Token configurations
  tokenConfigs: [
    // Example token with 70% legitimate value
    {
      address: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0", // Example address
      totalSupplied: "100000000000000000000", // 100 ETH in wei
      illegitimateBorrowed: "30000000000000000000", // 30 ETH in wei
    },
    // Example token with 80% legitimate value
    {
      address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9", // Example address
      totalSupplied: "500000000000000000000", // 500 ETH in wei
      illegitimateBorrowed: "100000000000000000000", // 100 ETH in wei
    },
  ],
};
