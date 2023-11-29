import { ethers } from "hardhat";

async function main() {
    let baseContract = "0x7570f9bD3E3621D2505EC4296153E83e8576c32c";
    let tokenContract = "0x6b3e60121B3C7be111A6763F76acfE0Ac17697f9";
  const droplinked = await ethers.deployContract("DroplinkedOperator", [baseContract, tokenContract], {
    value: 0,
  });
  await droplinked.waitForDeployment();
  console.log(
    `[ ✅ ] Droplinked deployed to: ${await droplinked.getAddress()} with fee: ${100}`
  );

  const base_t = await ethers.getContractAt("DroplinkedBase", baseContract);
  const base = new ethers.Contract(baseContract, base_t.interface.formatJson());
  
  const token_t = await ethers.getContractAt("DroplinkedToken", baseContract);
  const token = new ethers.Contract(baseContract, token_t.interface.formatJson());
  

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
