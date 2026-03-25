// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FixedVault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Not enough balance");

        // Effects first
        balances[msg.sender] -= amount;

        // Interaction last
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed");
    }

    receive() external payable {}
}