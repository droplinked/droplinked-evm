import { HardhatUserConfig } from "hardhat/config";
require("dotenv").config();
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
    },
    polygonMumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY as string]
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: [process.env.POLYGON_PK as string]
    },
    baset: {
      url: "https://goerli.base.org",
      accounts: [process.env.PRIVATE_KEY as string]
    },
    binance_testnet:{
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.MNEMONIC as string]
    },
    HederaTest: {
      //HashIO testnet endpoint from the TESTNET_ENDPOINT variable in the project .env the file
      url: process.env.HEDERA_TESTNET_ENDPOINT,
      //the Hedera testnet account ECDSA private
      //the public address for the account is derived from the private key
      accounts: [
        process.env.HEDERA_TESTNET_OPERATOR_PRIVATE_KEY as string,
      ],
    },
    xrpl: {
      url: `https://rpc-evm-sidechain.xrpl.org`,
      accounts: [process.env.XRP_TESTNET_OPERATOR_PRIVATE_KEY as string],
      chainId: 1440002,
    },
  },
  solidity: {
    version: "0.8.18",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  etherscan:{
    apiKey: (process.env.POLYGONSCAN_API_KEY) as string,
    customChains: [
      {
        network: "xrpl",
        chainId: 1440002,
        urls: {
          apiURL: "https://evm-sidechain.xrpl.org/api",
          browserURL: "https://evm-sidechain.xrpl.org"
        }
      }
    ]
  }
};

export default config;
