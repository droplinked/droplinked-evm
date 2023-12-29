# Droplinked Solidity Contracts
This repository contains the droplinked's smart-contract source code for EVM chains that droplinked integrates with, including : Polygon, Binance, Hedera and Ripple sidechain

## Run tests
To run the tests on the contract you can run the following command
```bash
droplinked-evm-hardhat on   main
> npx hardhat test test/test.ts


Droplinked
    Deployment
      ✔ Should set the right owner (2296ms)
      ✔ Should set the right fee (91ms)
    Set & Update heartbeat
      ✔ Should update the heartbeat with owner account (93ms)
      ✔ should not update the heartbeat with other account (90ms)
    Set & update fee
      ✔ Should update the fee to given number using owner account (85ms)
      ✔ Should not update the fee to given number using other account (79ms)
    Mint
      ✔ Should mint 5000 tokens (105ms)
      ✔ Should mint the same product with the same token_id (114ms)
      ✔ Should set the right product metadata (98ms)
      ✔ should set the right beneficiaries when minting (153ms)
    PublishRequest
      ✔ Should publish a request (113ms)
      ✔ Should publish publish a request with the right data (125ms)
      ✔ Should publish a request and put it in the incoming requests of producer (105ms)
      ✔ Should publish a request and put it in the outgoing requests of publisher (117ms)
      ✔ Should not publish a request twice (110ms)
    CancelRequest
      ✔ Should cancel a request (123ms)
      ✔ Should not cancel a request if it is not the publisher (108ms)
      ✔ Should not cancel a request if it is approved (116ms)
    AcceptRequest
      ✔ Should accept a request (111ms)
      ✔ Should not accept a request if it is not the producer (104ms)
    DisapproveRequest
      ✔ Should disapprove a request (118ms)
      ✔ Should not disapprove a request if it is not the producer (108ms)
    ERC20 Tokens
      ✔ should add an erc20 token to the contract (82ms)
      ✔ should remove an erc20 token to the contract (85ms)
      ✔ should not accept a non erc20 contract (77ms)
    Royalty check
      ✔ should add royalty for a product while minting (88ms)
      ✔ should not update issuer info for the same product in minting (107ms)
    Set Metadata for purchased products
      ✔ should error if we want to set metadata on a product which already have one (95ms)
      ✔ should remove metadata (100ms)
    Coupon
      ✔ Should add a coupon (84ms)
      ✔ Should not add a coupon twice
      ✔ should remove a coupon (92ms)
    Payment
      ✔ Should divide funds among people ( Test1: just TBD ) (227ms)
      ✔ Should divide funds among people ( Test2: 1 minted product without TBD ) (238ms)
      ✔ Should not divide funds among people ( Test3: 1 minted product with wrong tokenId without TBD ) (241ms)
      ✔ Should not divide funds among people ( Test4: 1 minted product with more than valid amount without TBD ) (231ms)
      ✔ Should not divide funds among people ( Test5: 1 affiliate POD with without TBD ) (245ms)
      ✔ Should divide funds among people ( Test6: more than 1 minted product without TBD ) (259ms)
      ✔ Should divide funds among people ( Test7: 1 minted product with one beneficiary with percentage without TBD ) (237ms)
      ✔ Should divide funds among people ( Test8: 1 minted product with one beneficiary with value without TBD ) (238ms)
      ✔ Should divide funds among people ( Test9: 1 minted product with one beneficiary with value and another with percent without TBD ) (247ms)
      ✔ Should divide funds among people ( Test10: 1 affiliated with one beneficiary with percentage without TBD ) (265ms)
      ✔ Should divide funds among people ( Test10: royalty test without TBD ) (285ms)


  43 passing (8s)
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
