import { ethers } from "hardhat";

async function main() {
  const token = await ethers.deployContract("DroplinkedToken", [], {
    value: 0,
  });
  await token.waitForDeployment();
  console.log(`[ ✅ ] Token Contract deployed to: ${await token.getAddress()}`);
  const base = await ethers.deployContract("DroplinkedBase", [], {
    value: 0,
  });
  await base.waitForDeployment();
  console.log(`[ ✅ ] Base Contract deployed to: ${await base.getAddress()}`);
  
  const droplinked = await ethers.deployContract("DroplinkedOperator", [await base.getAddress(), await token.getAddress()], {
    value: 0,
  });
  await droplinked.waitForDeployment();
  console.log(
    `[ ✅ ] Droplinked deployed to: ${await droplinked.getAddress()} with fee: ${100}`
  );

  const baseResult = await base.setOperator(await droplinked.getAddress());
  baseResult.wait();
  console.log(
    `[ ✅ ] Operator for DroplinkedBase set. Tx: ${(await baseResult.getTransaction())?.hash}`
  );

  const tokenResult = await token.setOperator(await droplinked.getAddress());
  tokenResult.wait();
  console.log(
    `[ ✅ ] Operator for DroplinkedToken set. Tx: ${(await tokenResult.getTransaction())?.hash}`
  );

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
