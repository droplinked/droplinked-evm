# Droplinked Solidity Contracts
This repository contains the droplinked's smart-contract source code for EVM chains that droplinked integrates with, including : Polygon, Binance, Hedera and Ripple sidechain

## Run tests
To run the tests on the contract you can run the following command
```bash
npx hardhat test test/test.ts
```

## Deploy
To deploy the contract to a network, follow these steps: 
1. Add your network to the `hardhat.config.ts` file, by simply looking at the exapmles that are there
2. Put your etherscan api key in the `etherscan` part
3. Run the following command to deploy :
```bash
npx hardhat run scripts/deploy.ts --network $network_name_here$
```

For instance, running
```bash
npx hardhat run scripts/deploy.ts --network polygon_mumbai
```

or run
```bash
npm run deploy:mumbai
```

would result in something like this
```bash
[ ✅ ] Droplinked deployed to: 0x34C4db97cE4cA2cce48757F85C954C5647124106 with fee: 100
```
