import { ethers, run } from "hardhat";

const delay = (delayInms: number) => {
  return new Promise(resolve => setTimeout(resolve, delayInms));
};

async function main() {
  const droplinked = await ethers.deployContract("DroplinkedOperator", ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], {
    value: 0,
  });
  console.log(
    `[ ☕️ ] Deploying the contract to chain ...`
  );
  await droplinked.waitForDeployment();
  console.log(
    `[ ✅ ] Droplinked deployed to: ${await droplinked.getAddress()} with fee: ${100}`
  );
  console.log(
    `[ ☕️ ] Waiting 20 seconds ...`
  );
  await delay(20000);
  console.log(
    `[ ☕️ ] Verifying the contract's source code on block explorer ...`
  );

  await run('verify:verify', {
    address: await droplinked.getAddress(),
    constructorArguments: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"]
  });

  await run('verify:verify', {
    address: await droplinked.droplinkedBase(),
    constructorArguments: []
  });

  await run('verify:verify', {
    address: await droplinked.droplinkedToken(),
    constructorArguments: []
  });

  console.log(
    `[ ✅ ] Contract's source code verified on block explorer.`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
