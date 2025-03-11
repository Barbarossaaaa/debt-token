import { getAddress, parseUnits } from "viem";

/**
 * Configuration for Mode Mainnet IonicDebtToken deployment
 */
export const modeMainnetConfig = {
  // Core deployment parameters
  masterPriceOracleAddress: getAddress(
    "0x1234567890123456789012345678901234567890"
  ), // Mode mainnet master price oracle address
  usdcAddress: getAddress("0xd988097fb8612ae244b87df08e2abe6c3f25b08b"), // Mode mainnet USDC address

  // Token configurations
  tokenConfigs: [
    // ionuniBTC
    {
      address: "0xa48750877a83f7dEC11f722178C317b54a44d142",
      totalSupplied: parseUnits("39.54389903", 8),
      illegitimateBorrowed: parseUnits("39.5017", 8),
    },
    // ionwrsETH
    {
      address: "0x49950319aBE7CE5c3A6C90698381b45989C99b46",
      totalSupplied: parseUnits("242.951519406048997355", 18),
      illegitimateBorrowed: parseUnits("238.4285", 18),
    },
    // ionWETH
    {
      address: "0x71ef7EDa2Be775E5A7aa8afD02C45F059833e9d2",
      totalSupplied: parseUnits("433.822454462637139154", 18),
      illegitimateBorrowed: parseUnits("195.581", 18),
    },
    // ionweETH.mode
    {
      address: "0xA0D844742B4abbbc43d8931a6Edb00C56325aA18",
      totalSupplied: parseUnits("162.545523226895754146", 18),
      illegitimateBorrowed: parseUnits("157.3945", 18),
    },
    // ionWBTC
    {
      address: "0xd70254C3baD29504789714A7c69d60Ec1127375C",
      totalSupplied: parseUnits("2.5308917", 8),
      illegitimateBorrowed: parseUnits("2.3762", 8),
    },
    // ionSTONE
    {
      address: "0x959fa710ccbb22c7ce1e59da82a247e686629310",
      totalSupplied: parseUnits("98.229499907501992876", 18),
      illegitimateBorrowed: parseUnits("96.4513", 18),
    },
    // ionUSDC
    {
      address: "0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038",
      totalSupplied: parseUnits("692393.588153", 6),
      illegitimateBorrowed: parseUnits("150068.2597", 6),
    },
    // ionUSDT
    {
      address: "0x94812F2eEa03A49869f95e1b5868C6f3206ee3D3",
      totalSupplied: parseUnits("145235.014021", 6),
      illegitimateBorrowed: parseUnits("55020.487", 6),
    },
    // ionweETH (OLD)
    {
      address: "0x9a9072302B775FfBd3Db79a7766E75Cf82bcaC0A",
      totalSupplied: parseUnits("26.909897310645108597", 18),
      illegitimateBorrowed: parseUnits("13.8343", 18),
    },
  ],
};
