// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UnoptimizedContract {
    uint256 public count;
    address public owner;
    uint256 public fee;
    bool public isActive;

    mapping(address => uint256) public balances;

    event CountIncremented(address indexed user, uint256 newCount);

    constructor() {
        owner = msg.sender;
        fee = 1 ether;
        isActive = true;
        count = 0;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function increment(uint256 times) external {
        for (uint256 i = 0; i < times; i++) {
            count += 1;
            emit CountIncremented(msg.sender, count);
        }
    }

    function toggleActive() external {
        require(msg.sender == owner, "Not owner");
        if (isActive) {
            isActive = false;
        } else {
            isActive = true;
        }
    }

    function setFee(uint256 newFee) external {
        require(msg.sender == owner, "Not owner");
        fee = newFee;
    }
}