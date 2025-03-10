# Hardhat 3 Alpha: `node:test` and `viem` example project

> **WARNING**: This example project uses Hardhat 3, which is still in development. Hardhat 3 is not yet intended for production use.

Welcome to the Hardhat 3 alpha version! This project showcases some of the changes and new features coming in Hardhat 3.

To learn more about the Hardhat 3 Alpha, please visit [its tutorial](https://hardhat.org/hardhat3-alpha). To share your feedback, join our [Hardhat 3 Alpha](https://hardhat.org/hardhat3-alpha-telegram-group) Telegram group or [open an issue](https://github.com/NomicFoundation/hardhat/issues/new?template=hardhat-3-alpha.yml) in our GitHub issue tracker.

## Project Overview

This example project includes:

- A simple Hardhat configuration file.
- Foundry-compatible Solidity unit tests.
- TypeScript integration tests using [`node:test`](nodejs.org/api/test.html), the new Node.js native test runner, and [`viem`](https://viem.sh/).
- Examples demonstrating how to connect to different types of networks, including locally simulating OP mainnet.

## Navigating the Project

To get the most out of this example project, we recommend exploring the files in the following order:

1. Read the `hardhat.config.ts` file, which contains the project configuration and explains multiple changes.
2. Review the "Running Tests" section and explore the files in the `contracts/` and `test/` directories.
3. Read the "Make a deployment to Sepolia" section and follow the instructions.

Each file includes inline explanations of its purpose and highlights the changes and new features introduced in Hardhat 3.

## Usage

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

You can also selectively run the Solidity or `node:test` tests:

```shell
npx hardhat test solidity
npx hardhat test node
```

### Make a deployment to Sepolia

This project includes an example Ignition module to deploy the contract. You can deploy this module to a locally simulated chain or to Sepolia.

To run the deployment to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/Counter.ts
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable.

To set the `SEPOLIA_PRIVATE_KEY` config variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```

---

Feel free to explore the project and provide feedback on your experience with Hardhat 3 Alpha!

# Ionic Recovery Project - Mode Mainnet Fork Testing

This project contains a test suite for the IonicDebtToken contract that uses a forked Mode mainnet for testing interactions with existing contracts.

## Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- A Mode mainnet RPC URL (default uses public endpoint but may be rate-limited)

## Setup

1. Clone the repository:
```bash
git clone https://github.com/your-username/ionic-recovery.git
cd ionic-recovery
```

2. Install dependencies:
```bash
npm install
```

3. Set up your environment variables by creating a `.env` file:
```bash
MODE_MAINNET_RPC_URL=https://mainnet.mode.network
# Or use your own RPC provider:
# MODE_MAINNET_RPC_URL=https://your-mode-rpc-provider.com
```

## Running the Mode Mainnet Fork Tests

To run the tests on a forked Mode mainnet:

```bash
npx hardhat test test/IonicDebtToken.fork.ts
```

## About the Test Approach

The tests use Hardhat's network forking capability to create a local copy of the Mode mainnet. This allows:

1. Interaction with existing deployed contracts
2. Impersonating accounts that hold tokens needed for testing
3. Testing of contract functionalities in a realistic mainnet environment
4. Verifying contract behavior with actual token pricing and exchange rates

## Test Configuration

The Mode mainnet fork test uses the following configuration:

- Forks from a specific block for consistent testing
- Impersonates a whale account to obtain ion tokens for testing
- Tests the full lifecycle of the IonicDebtToken contract:
  - Whitelisting ion tokens
  - Setting and updating scale factors
  - Minting debt tokens by providing whitelisted ion tokens
  - Withdrawing collected ion tokens

## Modifying the Tests

If you need to test with different token addresses or configurations:

1. Update the Mode mainnet addresses in `test/IonicDebtToken.fork.ts`:
```typescript
const MODE_MAINNET_ADDRESSES = {
  USDC: "0xd988097fb8612ae244b87df08e2abe6c3f25b08b", // Mode USDC address
  MASTER_PRICE_ORACLE: "your-oracle-address", 
  SAMPLE_ION_TOKEN: "your-ion-token-address",
  WHALE_ADDRESS: "address-with-ion-tokens",
};
```

2. Adjust the test parameters as needed for your specific testing scenario.

## Note on ABIs

The test attempts to use the ABIs from compiled artifacts. Make sure to compile your contracts first:

```bash
npx hardhat compile
```
