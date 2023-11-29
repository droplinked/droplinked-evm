import { ethers } from "hardhat";

async function main() {
  const droplinked = await ethers.deployContract("DroplinkedOperator", [], {
    value: 0,
  });
  await droplinked.waitForDeployment();
  console.log(
    `[ ✅ ] Droplinked deployed to: ${await droplinked.getAddress()} with fee: ${100}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
