// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Not enough balance");

        (bool sent, ) = msg.sender.call{value: amount}("");

        if (!sent) {
            return;
        }

        balances[msg.sender] -= amount;
    }

    receive() external payable {}
}