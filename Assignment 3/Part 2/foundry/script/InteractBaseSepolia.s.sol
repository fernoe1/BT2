// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BaseToken.sol";
import "../src/SimpleAMM.sol";

contract InteractBaseSepolia is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(pk);
        
        string memory deploymentData = vm.readFile("deployed_base_sepolia.txt");
        
        string[] memory lines = vm.split(deploymentData, "\n");
        
        string memory tokenLine = lines[0];
        string[] memory tokenParts = vm.split(tokenLine, "=");
        address tokenAddr = vm.parseAddress(tokenParts[1]);
        
        string memory ammLine = lines[1];
        string[] memory ammParts = vm.split(ammLine, "=");
        address ammAddr = vm.parseAddress(ammParts[1]);
        
        BaseToken token = BaseToken(tokenAddr);
        SimpleAMM amm = SimpleAMM(payable(ammAddr));
        
        console.log("\n=== Starting Interactions on Base Sepolia ===");
        console.log("Chain ID:", block.chainid);
        console.log("User:", user);
        console.log("Token:", tokenAddr);
        console.log("AMM:", ammAddr);
        console.log("Initial ETH Balance:", user.balance / 1e18, "ETH");
        
        vm.startBroadcast(pk);
        
        console.log("\n[TX 1] Minting 10,000 BASE tokens...");
        token.mint(10000);
        uint256 mintAmount = 10000 * 10**18;
        console.log("Minted! Balance:", token.balanceOf(user) / 1e18, "BASE");
        
        console.log("\n[TX 2] Approving AMM to spend 5,000 BASE...");
        token.approve(ammAddr, 5000 * 10**18);
        console.log("Approval granted for 5,000 BASE");
        
        console.log("\n[TX 3] Adding liquidity with 0.01 ETH and 5,000 BASE...");
        uint256 liquidityValue = 0.01 ether;
        amm.addLiquidity{value: liquidityValue}(5000 * 10**18);
        console.log("Liquidity added!");
        console.log("  ETH Reserve:", amm.ethReserve() / 1e18, "ETH");
        console.log("  Token Reserve:", amm.tokenReserve() / 1e18, "BASE");
        
        console.log("\n[TX 4] Swapping 0.001 ETH for BASE tokens...");
        uint256 swapValue = 0.001 ether;
        uint256 expectedTokens = amm.getTokenAmount(swapValue, amm.ethReserve(), amm.tokenReserve());
        amm.ethToToken{value: swapValue}(expectedTokens * 90 / 100);
        console.log("Swap completed!");
        console.log("  Expected tokens:", expectedTokens / 1e18, "BASE");
        console.log("  New Token Balance:", token.balanceOf(user) / 1e18, "BASE");
        
        console.log("\n[TX 5] Transferring 100 BASE to test address...");
        address testAddr = address(0x0000000000000000000000000000000000000001);
        token.transfer(testAddr, 100 * 10**18);
        console.log("Transfer completed!");
        console.log("  Sent 100 BASE to:", testAddr);
        
        vm.stopBroadcast();
        
        console.log("\n=== Final State ===");
        console.log("User's Token Balance:", token.balanceOf(user) / 1e18, "BASE");
        console.log("AMM ETH Reserve:", amm.ethReserve() / 1e18, "ETH");
        console.log("AMM Token Reserve:", amm.tokenReserve() / 1e18, "BASE");
        console.log("\n All 5 transactions executed successfully on Base Sepolia!");
    }
}