import { describe, it, beforeEach } from "node:test";
import { network } from "hardhat";
import assert from "node:assert/strict";
import { formatUnits, getAddress } from "viem";
import IonicDebtTokenModule from "../ignition/modules/IonicDebtToken.js";
import { modeMainnetConfig } from "../ignition/config/mode-mainnet.js";

const ION_USDC = "0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038";

/*
 * Tests for IonicDebtToken contract using Mode mainnet fork
 */
describe.only("IonicDebtToken (Mode Mainnet Fork)", async function () {
  const { viem, ignition, provider } = await network.connect();
  const publicClient = await viem.getPublicClient();
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
    ionToken = await viem.getContractAt("IIonToken", ION_USDC);
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

      await ionicDebtToken.write.whitelistIonToken([ION_USDC, scaleFactor]);

      const isWhitelisted = await ionicDebtToken.read.whitelistedIonTokens([
        ION_USDC,
      ]);

      const storedScaleFactor = await ionicDebtToken.read.ionTokenScaleFactors([
        ION_USDC,
      ]);

      assert.equal(isWhitelisted, true);
      assert.equal(storedScaleFactor, scaleFactor);
    });

    it("owner should be able to update a scale factor", async () => {
      // First whitelist the token
      const initialScaleFactor = 1000000000000000000n; // 1 ETH in wei
      await ionicDebtToken.write.whitelistIonToken([
        ION_USDC,
        initialScaleFactor,
      ]);

      const newScaleFactor = 2000000000000000000n; // 2 ETH in wei
      await ionicDebtToken.write.updateScaleFactor([ION_USDC, newScaleFactor]);

      const storedScaleFactor = await ionicDebtToken.read.ionTokenScaleFactors([
        ION_USDC,
      ]);

      assert.equal(storedScaleFactor, newScaleFactor);
    });
  });

  describe("Minting", () => {
    it.only("should allow minting with whitelisted ionToken", async () => {
      // Use a whale address that has ionTokens
      const whaleAddress = "0xE5859cbc7a5C954D33480E67266c2bbc919a966e";

      // Impersonate the whale account
      await provider.request({
        method: "hardhat_impersonateAccount",
        params: [whaleAddress],
      });

      const whale = await viem.getWalletClient(whaleAddress as `0x${string}`);

      console.log(`\nMinting debt tokens for whale address: ${whaleAddress}\n`);

      // Get initial debt token balance
      const initialDebtBalance = await ionicDebtToken.read.balanceOf([
        whaleAddress,
      ]);
      console.log(`Initial debt balance: ${initialDebtBalance}`);

      // Process each token from the config
      for (const tokenConfig of modeMainnetConfig.tokenConfigs) {
        const tokenAddress = getAddress(tokenConfig.address);
        const tokenContract = await viem.getContractAt(
          "IonicDebtToken",
          tokenAddress
        );

        const symbol = await tokenContract.read.symbol().catch(() => "Unknown");
        const decimals = Number(
          await tokenContract.read.decimals().catch(() => 18)
        );
        const balance = await tokenContract.read.balanceOf([whaleAddress]);

        if (balance === 0n) {
          continue;
        }

        console.log(`Processing ${symbol} (${tokenAddress})`);
        console.log(`Raw Balance: ${balance}`);
        console.log(`Formatted Balance: ${formatUnits(balance, decimals)}\n`);

        const initialDebtBalance = await ionicDebtToken.read.balanceOf([
          whaleAddress,
        ]);

        // Approve the IonicDebtToken contract to spend whale's entire balance
        let tx = await tokenContract.write.approve(
          [ionicDebtToken.address, balance],
          {
            account: whale.account,
          }
        );
        await publicClient.waitForTransactionReceipt({
          hash: tx,
        });

        // Mint dION tokens using entire balance
        tx = await ionicDebtToken.write.mint([tokenAddress, balance], {
          account: whale.account,
        });
        await publicClient.waitForTransactionReceipt({
          hash: tx,
        });

        // Check final debt token balance
        const finalDebtBalance = await ionicDebtToken.read.balanceOf([
          whaleAddress,
        ]);
        console.log(`Final debt balance: ${finalDebtBalance}`);
        console.log(
          `Increase: ${finalDebtBalance - initialDebtBalance} for ${symbol}\n`
        );
      }

      // Stop impersonating the whale
      await provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [whaleAddress],
      });

      // Check final debt token balance
      const finalDebtBalance = await ionicDebtToken.read.balanceOf([
        whaleAddress,
      ]);
      console.log(`Final debt balance: ${finalDebtBalance}`);
      console.log(`Increase: ${finalDebtBalance - initialDebtBalance}\n`);

      // Verify minting was successful
      assert.ok(
        finalDebtBalance > initialDebtBalance,
        `Should have received debt tokens`
      );
    });
  });

  describe("Owner Operations", () => {
    it("should allow owner to withdraw ionTokens", async () => {
      // First whitelist the token and do some minting to get tokens in the contract
      const scaleFactor = 1000000000000000000n;
      const mintAmount = 10000000000000000000n;

      await ionicDebtToken.write.whitelistIonToken([ION_USDC, scaleFactor]);

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
        ION_USDC,
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
      await ionicDebtToken.write.whitelistIonToken([ION_USDC, scaleFactor]);

      await ionicDebtToken.write.removeIonToken([ION_USDC]);

      const isWhitelisted = await ionicDebtToken.read.whitelistedIonTokens([
        ION_USDC,
      ]);

      assert.equal(isWhitelisted, false);
    });
  });
});
