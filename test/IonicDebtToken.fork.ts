import { describe, it } from "node:test";
import { network } from "hardhat";
import assert from "node:assert/strict";
import { getAddress } from "viem";
import IonicDebtTokenModule from "../ignition/modules/IonicDebtToken.js";

/*
 * Tests for IonicDebtToken contract using Mode mainnet fork
 */
describe("IonicDebtToken (Mode Mainnet Fork)", async function () {
  const { viem, ignition } = await network.connect();
  const [walletClient] = await viem.getWalletClients();
  const owner = getAddress(walletClient.account.address);

  describe("Initialization", () => {
    it("should set correct initial values", async () => {
      const { ionicDebtToken } = await ignition.deploy(IonicDebtTokenModule);
      const contractOracle = await ionicDebtToken.read.masterPriceOracle();

      const contractUsdc = await ionicDebtToken.read.usdcAddress();

      const contractOwner = await ionicDebtToken.read.owner();

      assert.equal(contractOracle, contractOracle);
      assert.equal(contractUsdc, contractUsdc);
      assert.equal(contractOwner, contractOwner);
    });
  });

  // describe("IonToken Whitelisting", () => {
  //   it("owner should be able to whitelist an ionToken", async () => {
  //     // Use a scale factor of 1e18
  //     const scaleFactor = 1000000000000000000n; // 1 ETH in wei

  //     const { request } = await publicClient.simulateContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "whitelistIonToken",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN, scaleFactor],
  //       account: owner,
  //     });

  //     await walletClient.writeContract(request);

  //     const isWhitelisted = await publicClient.readContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "whitelistedIonTokens",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN],
  //     });

  //     const storedScaleFactor = await publicClient.readContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "ionTokenScaleFactors",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN],
  //     });

  //     assert.equal(isWhitelisted, true);
  //     assert.equal(storedScaleFactor, scaleFactor);
  //   });

  //   it("owner should be able to update a scale factor", async () => {
  //     const newScaleFactor = 2000000000000000000n; // 2 ETH in wei

  //     const { request } = await publicClient.simulateContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "updateScaleFactor",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN, newScaleFactor],
  //       account: owner,
  //     });

  //     await walletClient.writeContract(request);

  //     const storedScaleFactor = await publicClient.readContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "ionTokenScaleFactors",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN],
  //     });

  //     assert.equal(storedScaleFactor, newScaleFactor);
  //   });
  // });

  // describe("Minting", () => {
  //   it("should allow minting with whitelisted ionToken", async () => {
  //     try {
  //       // Amount of ion tokens to mint
  //       const mintAmount = 10000000000000000000n; // 10 tokens

  //       // Check whale's ionToken balance
  //       const whaleBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [whaleAddress],
  //       });

  //       console.log("Whale ionToken balance:", whaleBalance);

  //       // Skip if whale doesn't have enough tokens
  //       if (whaleBalance < mintAmount) {
  //         console.log("Whale doesn't have enough tokens, skipping test");
  //         return;
  //       }

  //       // Impersonate the whale account for transfers
  //       await provider.request({
  //         method: "hardhat_impersonateAccount",
  //         params: [whaleAddress],
  //       });

  //       // Get whale signer from hardhat
  //       const whaleSigner = await viem.getWalletClient({
  //         account: whaleAddress,
  //       });

  //       // Transfer tokens from whale to user
  //       const transferRequest = await publicClient.simulateContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "transfer",
  //         args: [user, mintAmount],
  //         account: whaleAddress,
  //       });

  //       await whaleSigner.writeContract(transferRequest.request);

  //       // Get user's balance
  //       const userBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [user],
  //       });

  //       assert.equal(userBalance, mintAmount);

  //       // Approve the IonicDebtToken contract to spend user's ionTokens
  //       const userSigner = await viem.getWalletClient({ account: user });

  //       const approveRequest = await publicClient.simulateContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "approve",
  //         args: [ionicDebtToken.address, mintAmount],
  //         account: user,
  //       });

  //       await userSigner.writeContract(approveRequest.request);

  //       // Check initial debt token balance
  //       const initialBalance = await publicClient.readContract({
  //         address: ionicDebtToken.address,
  //         abi: ionicDebtToken.abi,
  //         functionName: "balanceOf",
  //         args: [user],
  //       });

  //       // Mint dION tokens
  //       const mintRequest = await publicClient.simulateContract({
  //         address: ionicDebtToken.address,
  //         abi: ionicDebtToken.abi,
  //         functionName: "mint",
  //         args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN, mintAmount],
  //         account: user,
  //       });

  //       await userSigner.writeContract(mintRequest.request);

  //       // Check final debt token balance
  //       const finalBalance = await publicClient.readContract({
  //         address: ionicDebtToken.address,
  //         abi: ionicDebtToken.abi,
  //         functionName: "balanceOf",
  //         args: [user],
  //       });

  //       console.log(
  //         "User minted dION tokens:",
  //         Number(finalBalance - initialBalance)
  //       );
  //       assert.ok(
  //         finalBalance > initialBalance,
  //         "User should have received debt tokens"
  //       );
  //     } catch (error) {
  //       console.error("Error during minting test:", error);
  //       throw error;
  //     }
  //   });
  // });

  // describe("Owner Operations", () => {
  //   it("should allow owner to withdraw ionTokens", async () => {
  //     try {
  //       // Get the contract's ionToken balance
  //       const contractBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [ionicDebtToken.address],
  //       });

  //       if (contractBalance === 0n) {
  //         console.log("Contract has no ionTokens, skipping test");
  //         return;
  //       }

  //       // Get initial owner balance
  //       const initialOwnerBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [owner],
  //       });

  //       // Withdraw half of the tokens
  //       const withdrawAmount = contractBalance / 2n;

  //       const withdrawRequest = await publicClient.simulateContract({
  //         address: ionicDebtToken.address,
  //         abi: ionicDebtToken.abi,
  //         functionName: "withdrawIonTokens",
  //         args: [
  //           MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN,
  //           withdrawAmount,
  //           owner,
  //         ],
  //         account: owner,
  //       });

  //       await walletClient.writeContract(withdrawRequest.request);

  //       // Check owner received the tokens
  //       const finalOwnerBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [owner],
  //       });

  //       assert.equal(
  //         finalOwnerBalance - initialOwnerBalance,
  //         withdrawAmount,
  //         "Owner should have received the tokens"
  //       );

  //       // Check contract balance decreased
  //       const finalContractBalance = await publicClient.readContract({
  //         address: ionToken.address,
  //         abi: ionToken.abi,
  //         functionName: "balanceOf",
  //         args: [ionicDebtToken.address],
  //       });

  //       assert.equal(
  //         finalContractBalance,
  //         contractBalance - withdrawAmount,
  //         "Contract balance should have decreased"
  //       );
  //     } catch (error) {
  //       console.error("Error during withdrawal test:", error);
  //       throw error;
  //     }
  //   });
  // });

  // describe("IonToken Management", () => {
  //   it("should allow owner to remove an ionToken from whitelist", async () => {
  //     const removeRequest = await publicClient.simulateContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "removeIonToken",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN],
  //       account: owner,
  //     });

  //     await walletClient.writeContract(removeRequest.request);

  //     const isWhitelisted = await publicClient.readContract({
  //       address: ionicDebtToken.address,
  //       abi: ionicDebtToken.abi,
  //       functionName: "whitelistedIonTokens",
  //       args: [MODE_MAINNET_ADDRESSES.SAMPLE_ION_TOKEN],
  //     });

  //     assert.equal(isWhitelisted, false);
  //   });
  // });
});
