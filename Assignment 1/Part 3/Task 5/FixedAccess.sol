// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FixedAccess is Ownable {

    constructor() Ownable(msg.sender) {}

    function setOwner(address newOwner) external onlyOwner {
        transferOwnership(newOwner);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}