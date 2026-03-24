const { ethers, upgrades } = require("hardhat");

async function main() {
  const LogicV1 = await ethers.getContractFactory("LogicV1");
  console.log("deploying LogicV1");
  
  const proxy = await upgrades.deployProxy(LogicV1, [], {
    initializer: "initialize",
    kind: "uups"
  });
  
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log("proxy deployed to:", proxyAddress);
  
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("implementation address:", implementationAddress);
  
  const logicV1 = await ethers.getContractAt("LogicV1", proxyAddress);
  
  console.log("\ntesting V1 functionality");
  console.log("initial counter:", await logicV1.getCounter());
  
  await logicV1.increment();
  console.log("after increment:", await logicV1.getCounter());
  
  await logicV1.increment();
  console.log("after second increment:", await logicV1.getCounter());
  
  console.log("\ndeployment completed. proxy address:", proxyAddress);
  return proxyAddress;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});