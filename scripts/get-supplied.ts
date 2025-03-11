import { network } from "hardhat";
import { modeMainnetConfig } from "../ignition/config/mode-mainnet.js";
import { Address, formatUnits } from "viem";

// ABI fragment for token info and supply
const TOKEN_ABI = [
  {
    name: "getTotalUnderlyingSupplied",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "name",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "string" }],
  },
  {
    name: "symbol",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "string" }],
  },
  {
    name: "decimals",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint8" }],
  },
] as const;

async function main() {
  // Connect to the Mode mainnet network
  const { viem } = await network.connect("mode_mainnet");
  const publicClient = await viem.getPublicClient();

  console.log("Fetching token information and supply values:");

  // Iterate through each token config
  for (const tokenConfig of modeMainnetConfig.tokenConfigs) {
    const [name, symbol, decimals, totalSupplied] = await Promise.all([
      publicClient.readContract({
        address: tokenConfig.address as Address,
        abi: TOKEN_ABI,
        functionName: "name",
      }),
      publicClient.readContract({
        address: tokenConfig.address as Address,
        abi: TOKEN_ABI,
        functionName: "symbol",
      }),
      publicClient.readContract({
        address: tokenConfig.address as Address,
        abi: TOKEN_ABI,
        functionName: "decimals",
      }),
      publicClient.readContract({
        address: tokenConfig.address as Address,
        abi: TOKEN_ABI,
        functionName: "getTotalUnderlyingSupplied",
      }),
    ]);

    // Format the total supplied with proper decimals
    const formattedTotalSupplied = formatUnits(totalSupplied, decimals);
    const formattedIllegitimateBorrowed = formatUnits(
      tokenConfig.illegitimateBorrowed,
      decimals
    );

    // Calculate ratio
    const ratio =
      Number(formattedIllegitimateBorrowed) / Number(formattedTotalSupplied);

    console.log(`\nToken: ${name} (${symbol})`);
    console.log(`Decimals: ${decimals}`);
    console.log(`Address: ${tokenConfig.address}`);
    console.log(`Total Supplied: ${formattedTotalSupplied}`);
    console.log(`Illegitimate Borrowed: ${formattedIllegitimateBorrowed}`);
    console.log(
      `Illegitimate/Total Supply Ratio: ${ratio.toFixed(4)} (${(
        ratio * 100
      ).toFixed(2)}%)`
    );
  }
}

// Execute the script
await main();
