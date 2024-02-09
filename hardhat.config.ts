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
      accounts: [process.env.DEPLOY_PK as string]
    },
    baset: {
      url: "https://goerli.base.org",
      accounts: [process.env.PRIVATE_KEY as string]
    },
    baseMain: {
      url: "https://base.drpc.org",
      chainId: 8453,
      accounts: [process.env.DEPLOY_PK as string]
    },
    binance_testnet:{
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.MNEMONIC as string]
    },
    bsc:{
      url: "https://bsc-dataseed.binance.org/",
      accounts: [process.env.DEPLOY_PK as string]
    },
    aurora_testnet:{
      url: "https://testnet.aurora.dev",
      chainId: 1313161555,
      accounts: [process.env.MNEMONIC as string]
    },
    linea_t:{
      url: "https://rpc.goerli.linea.build",
      chainId: 59140,
      accounts: [process.env.LINEA_PK as string]
    },
    linea:{
      url: "https://1rpc.io/linea",
      chainId: 59144,
      accounts: [process.env.DEPLOY_PK as string],
      gasPrice: 3900000000
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
    // apiKey: (process.env.POLYGON_API_KEY) as string,
    apiKey:{
      linea: "7DE7Q8JRVWGK5A8X57DI85FC6EYGMBR59A",//(process.env.POLYGON_API_KEY) as string
      baseGoerli: (process.env.BASE_API_KEY) as string,
      auroraTestnet: (process.env.AURORA_API_KEY) as string,
      bscTestnet: (process.env.BINANCE_API_KEY) as string,
      bsc: (process.env.BINANCE_API_KEY) as string,
      polygonMumbai: (process.env.MUMBAI_API_KEY) as string,
      polygon: (process.env.MUMBAI_API_KEY) as string,
      baseMain: (process.env.BASE_API_KEY) as string
    },
    customChains: [
      {
        network: "xrpl",
        chainId: 1440002,
        urls: {
          apiURL: "https://evm-sidechain.xrpl.org/api",
          browserURL: "https://evm-sidechain.xrpl.org"
        }
      },
      {
        network: "linea",
        chainId: 59144,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://goerli.lineascan.build/",
        }
      }
    ]
  }
};

export default config;
