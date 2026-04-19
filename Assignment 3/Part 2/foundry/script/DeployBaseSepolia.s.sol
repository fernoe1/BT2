// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BaseToken.sol";
import "../src/SimpleAMM.sol";

contract DeployBaseSepolia is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 initialSupply = 1000000; // 1,000,000 BASE tokens
        
        console.log("\n=== Deploying to Base Sepolia L2 ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Deployer Balance:", deployer.balance, "wei");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BaseToken
        BaseToken token = new BaseToken(initialSupply);
        console.log("\n[1] BaseToken deployed at:", address(token));
        
        // Deploy SimpleAMM
        SimpleAMM amm = new SimpleAMM(address(token));
        console.log("[2] SimpleAMM deployed at:", address(amm));
        
        vm.stopBroadcast();
        
        // Save addresses
        string memory deploymentData = string(abi.encodePacked(
            "TOKEN_ADDRESS=", vm.toString(address(token)), "\n",
            "AMM_ADDRESS=", vm.toString(address(amm)), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "CHAIN_ID=", vm.toString(block.chainid)
        ));
        vm.writeFile("deployed_base_sepolia.txt", deploymentData);
        
        console.log("\n=== Deployment Complete ===");
        console.log("Token Address:", address(token));
        console.log("AMM Address:", address(amm));
        console.log("\nAddresses saved to: deployed_base_sepolia.txt");
    }
}