// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BaseToken.sol";
import "../src/SimpleAMM.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=========================================");
        console.log("Deploying to Base Sepolia L2");
        console.log("=========================================");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Deployer Balance:", deployer.balance / 1e18, "ETH");
        
        vm.startBroadcast(deployerPrivateKey);
        
        BaseToken token = new BaseToken(1000000);
        console.log("\n Token deployed at:", address(token));
        
        SimpleAMM amm = new SimpleAMM(address(token));
        console.log("AMM deployed at:", address(amm));
        
        vm.stopBroadcast();
        
        string memory data = string(abi.encodePacked(
            "TOKEN=", vm.toString(address(token)), "\n",
            "AMM=", vm.toString(address(amm)), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "CHAIN=Base_Sepolia\n",
            "CHAIN_ID=", vm.toString(block.chainid)
        ));
        vm.writeFile("deployed_addresses.txt", data);
        
        console.log("\n=========================================");
        console.log("Deployment Complete!");
        console.log("=========================================");
        console.log("Addresses saved to: deployed_addresses.txt");
        console.log("\nVerify on BaseScan:");
        console.log("https://sepolia.basescan.org/address/", address(token));
        console.log("https://sepolia.basescan.org/address/", address(amm));
    }
}