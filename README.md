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

would result in something like this
```bash
[ ✅ ] Payment Contract deployed to: 0x5b080b9dDAc04FAD620a92Cd3484767a38a10593
[ ✅ ] Droplinked deployed to: 0x34C4db97cE4cA2cce48757F85C954C5647124106 with fee: 100
```

## Contracts
You can find the contract source codes for 2 types of chains in the Contracts folder, 
- `DrpPayment.sol` file contains the payment contract source code
- `DrpPolygon.sol` file contains the Droplinked-contract source code for chains which ChainLink has price feeds on them which are : Polygon & Binance
- `DrpPolygonSg.sol` file contains the Droplinked-contract source code for chains which ChainLink doen't have price feeds on them, It relies on price signing and signature verification for payments
