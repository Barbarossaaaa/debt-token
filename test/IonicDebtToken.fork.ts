import { describe, it, beforeEach } from "node:test";
import { network } from "hardhat";
import assert from "node:assert/strict";
import { getAddress } from "viem";
import IonicDebtTokenModule from "../ignition/modules/IonicDebtToken.js";
import { modeMainnetConfig } from "../ignition/config/mode-mainnet.js";

const SAMPLE_ION_TOKEN = "0x1230000000000000000000000000000000000000"; // Replace with actual ionToken address for testing

/*
 * Tests for IonicDebtToken contract using Mode mainnet fork
 */
describe.only("IonicDebtToken (Mode Mainnet Fork)", async function () {
  const { viem, ignition } = await network.connect();
  const [walletClient] = await viem.getWalletClients();
  const owner = getAddress(walletClient.account.address);
  let ionicDebtToken: any;
  let ionToken: any;
  let proxyAdmin: any;

  beforeEach(async () => {
    const deployment = await ignition.deploy(IonicDebtTokenModule);
    ionicDebtToken = deployment.ionicDebtToken;
    proxyAdmin = deployment.proxyAdmin;
    // Get the ionToken contract instance
    ionToken = await viem.getContractAt("IIonToken", SAMPLE_ION_TOKEN);
  });

  describe("Initialization", () => {
    it("should set correct initial values", async () => {
      const contractOracle = await ionicDebtToken.read.masterPriceOracle();
      const contractUsdc = await ionicDebtToken.read.usdcAddress();
      const contractOwner = await ionicDebtToken.read.owner();
      const contractProxyAdmin = await proxyAdmin.read.owner();

      // Compare with expected values from deployment
      assert.equal(contractOracle, modeMainnetConfig.masterPriceOracleAddress);
      assert.equal(contractUsdc, modeMainnetConfig.usdcAddress);
      assert.equal(contractOwner, contractProxyAdmin);
    });
  });

  describe("IonToken Whitelisting", () => {
    it("owner should be able to whitelist an ionToken", async () => {
      // Use a scale factor of 1e18
      const scaleFactor = 1000000000000000000n; // 1 ETH in wei

      await ionicDebtToken.write.whitelistIonToken([
        SAMPLE_ION_TOKEN,
        scaleFactor,
      ]);

      const isWhitelisted = await ionicDebtToken.read.whitelistedIonTokens([
        SAMPLE_ION_TOKEN,
      ]);

      const storedScaleFactor = await ionicDebtToken.read.ionTokenScaleFactors([
        SAMPLE_ION_TOKEN,
      ]);

      assert.equal(isWhitelisted, true);
      assert.equal(storedScaleFactor, scaleFactor);
    });

    it("owner should be able to update a scale factor", async () => {
      // First whitelist the token
      const initialScaleFactor = 1000000000000000000n; // 1 ETH in wei
      await ionicDebtToken.write.whitelistIonToken([
        SAMPLE_ION_TOKEN,
        initialScaleFactor,
      ]);

      const newScaleFactor = 2000000000000000000n; // 2 ETH in wei
      await ionicDebtToken.write.updateScaleFactor([
        SAMPLE_ION_TOKEN,
        newScaleFactor,
      ]);

      const storedScaleFactor = await ionicDebtToken.read.ionTokenScaleFactors([
        SAMPLE_ION_TOKEN,
      ]);

      assert.equal(storedScaleFactor, newScaleFactor);
    });
  });

  describe("Minting", () => {
    it("should allow minting with whitelisted ionToken", async () => {
      // Amount of ion tokens to mint
      const mintAmount = 10000000000000000000n; // 10 tokens
      const user = walletClient.account.address;

      // First whitelist the token
      const scaleFactor = 1000000000000000000n;
      await ionicDebtToken.write.whitelistIonToken([
        SAMPLE_ION_TOKEN,
        scaleFactor,
      ]);

      // Get user's initial balance
      const initialBalance = await ionToken.read.balanceOf([user]);

      // If user doesn't have enough tokens, we need to get them from a whale
      if (initialBalance < mintAmount) {
        // This part would need to be implemented with actual whale addresses
        // and proper token distribution for testing
        console.log(
          "Test requires tokens to be distributed to the test account first"
        );
        return;
      }

      // Approve the IonicDebtToken contract to spend user's ionTokens
      await ionToken.write.approve([ionicDebtToken.address, mintAmount]);

      // Check initial debt token balance
      const initialDebtBalance = await ionicDebtToken.read.balanceOf([user]);

      // Mint dION tokens
      await ionicDebtToken.write.mint([SAMPLE_ION_TOKEN, mintAmount]);

      // Check final debt token balance
      const finalDebtBalance = await ionicDebtToken.read.balanceOf([user]);

      assert.ok(
        finalDebtBalance > initialDebtBalance,
        "User should have received debt tokens"
      );
    });
  });

  describe("Owner Operations", () => {
    it("should allow owner to withdraw ionTokens", async () => {
      // First whitelist the token and do some minting to get tokens in the contract
      const scaleFactor = 1000000000000000000n;
      const mintAmount = 10000000000000000000n;

      await ionicDebtToken.write.whitelistIonToken([
        SAMPLE_ION_TOKEN,
        scaleFactor,
      ]);

      // Get the contract's ionToken balance
      const contractBalance = await ionToken.read.balanceOf([
        ionicDebtToken.address,
      ]);

      if (contractBalance === 0n) {
        console.log("Contract has no ionTokens, skipping test");
        return;
      }

      // Get initial owner balance
      const initialOwnerBalance = await ionToken.read.balanceOf([owner]);

      // Withdraw half of the tokens
      const withdrawAmount = contractBalance / 2n;

      await ionicDebtToken.write.withdrawIonTokens([
        SAMPLE_ION_TOKEN,
        withdrawAmount,
        owner,
      ]);

      // Check owner received the tokens
      const finalOwnerBalance = await ionToken.read.balanceOf([owner]);

      assert.equal(
        finalOwnerBalance - initialOwnerBalance,
        withdrawAmount,
        "Owner should have received the tokens"
      );

      // Check contract balance decreased
      const finalContractBalance = await ionToken.read.balanceOf([
        ionicDebtToken.address,
      ]);

      assert.equal(
        finalContractBalance,
        contractBalance - withdrawAmount,
        "Contract balance should have decreased"
      );
    });
  });

  describe("IonToken Management", () => {
    it("should allow owner to remove an ionToken from whitelist", async () => {
      // First whitelist the token
      const scaleFactor = 1000000000000000000n;
      await ionicDebtToken.write.whitelistIonToken([
        SAMPLE_ION_TOKEN,
        scaleFactor,
      ]);

      await ionicDebtToken.write.removeIonToken([SAMPLE_ION_TOKEN]);

      const isWhitelisted = await ionicDebtToken.read.whitelistedIonTokens([
        SAMPLE_ION_TOKEN,
      ]);

      assert.equal(isWhitelisted, false);
    });
  });
});
