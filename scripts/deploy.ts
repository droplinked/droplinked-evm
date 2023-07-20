import { ethers } from "hardhat";

async function main() {
  const fee = 100;
  const droplinked = await ethers.deployContract("Droplinked", [fee], {
    value: 0,
  });

  await droplinked.waitForDeployment();

  console.log(
    `Droplinked deployed to: ${await droplinked.getAddress()} with fee: ${fee}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
