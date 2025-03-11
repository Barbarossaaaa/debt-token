import { localhostConfig } from "./localhost.js";
import { modeMainnetConfig } from "./mode-mainnet.js";

// Export configurations for different networks
export const config = {
  localhost: localhostConfig,
  "mode-mainnet": modeMainnetConfig,
  // Add more network configurations as needed
  // goerli: goerliConfig,
  // mainnet: mainnetConfig,
};

/**
 * Get the configuration for a specific network
 * @param network Network name (e.g., 'localhost', 'goerli', 'mainnet')
 * @returns Configuration object for the specified network or undefined if not found
 */
export function getNetworkConfig(network: string) {
  return config[network as keyof typeof config];
}

/**
 * Get the configuration for the current network based on the HARDHAT_NETWORK environment variable
 * @returns Configuration object for the current network or localhost config if not specified
 */
export function getCurrentNetworkConfig() {
  const network = process.env.HARDHAT_NETWORK || "mode-mainnet";
  return getNetworkConfig(network);
}
