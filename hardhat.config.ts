import { task } from "hardhat/config";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";

import { HardhatUserConfig, NetworkUserConfig } from "hardhat/types";
import * as dotenv from "dotenv";

dotenv.config();
const isTestEnv = process.env.NODE_ENV === "test";

const netWorkConfig: NetworkUserConfig | undefined = isTestEnv
  ? ({
      mainnet: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API}`,
        accounts: [`${process.env.MAINNET_DEPLOYER_PRIV_KEY}`],
      },
      sepolia: {
        url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API}`,
        accounts: [`${process.env.MAINNET_DEPLOYER_PRIV_KEY}`],
      },
    } as NetworkUserConfig)
  : undefined;

const apiKeys = isTestEnv
  ? {
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
    }
  : undefined;

const loadConfig = (): HardhatUserConfig => {
  const config = {
    defaultNetwork: "hardhat",
    solidity: {
      compilers: [
        {
          version: "0.8.20",
          settings: {
            optimizer: {
              enabled: true,
              runs: 1000,
            },
          },
        },
      ],
    },
    networks: {
      hardhat: {
        accounts: {
          accountsBalance: "1000000000000000000000000",
        },
      },
      localhost: {
        url: "http://localhost:8545",
        /*
          notice no env vars here? it will just use account 0 of the hardhat node to deploy
          (you can put in a mnemonic here to set the deployer locally)
        */
      },
    },
    etherscan: {
      apiKey: apiKeys,
    },
    // mocha options can be set here
    mocha: {
      // timeout: "300s",
    },
  };
  if (isTestEnv) {
    return config;
  } else {
    return {
      ...config,
      ...apiKeys,
      ...netWorkConfig,
    };
  }
};

const config = loadConfig();

export default config;
