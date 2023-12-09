import { ethers } from "hardhat";

async function main() {
  const droplinked = await ethers.deployContract("DroplinkedOperator", ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], {
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
