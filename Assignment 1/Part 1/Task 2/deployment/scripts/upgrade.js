const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6"; 
  
  console.log("upgrading from V1 to V2");
  console.log("proxy address:", proxyAddress);
  
  const implementationV1 = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("current implementation (V1):", implementationV1);
  
  const logicV1 = await ethers.getContractAt("LogicV1", proxyAddress);
  const counterBefore = await logicV1.getCounter();
  console.log("counter value before upgrade:", counterBefore.toString());
  
  const LogicV2 = await ethers.getContractFactory("LogicV2");
  console.log("deploying LogicV2 implementation");
  
  const upgraded = await upgrades.upgradeProxy(proxyAddress, LogicV2);
  console.log("upgrade completed");
  
  const implementationV2 = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("new implementation:", implementationV2);
  
  const logicV2 = await ethers.getContractAt("LogicV2", proxyAddress);
  
  const counterAfter = await logicV2.getCounter();
  console.log("\nstate verification:");
  console.log("counter value after upgrade:", counterAfter.toString());
  console.log("state preserved:", counterBefore.toString() === counterAfter.toString());
  
  console.log("\ntesting V2 new functions...");
  await logicV2.decrement();
  console.log("after decrement:", await logicV2.getCounter());
  
  await logicV2.reset();
  console.log("after reset:", await logicV2.getCounter());
  
  console.log("\nupgrade and testing completed successfully");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});