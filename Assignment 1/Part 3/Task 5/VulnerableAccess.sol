// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VulnerableAccess {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // No access control
    function setOwner(address newOwner) external {
        owner = newOwner;
    }

    // Anyone can withdraw
    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}