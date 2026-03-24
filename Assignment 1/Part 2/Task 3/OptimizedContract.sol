// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OptimizedContract {
    // 1. Storage packing: reorder variables to fit into fewer slots
    uint256 public count;
    uint256 public fee;
    bool public isActive;
    address public owner;

    mapping(address => uint256) public balances;

    // 2. Event-based logging: used for increment instead of writing in storage repeatedly
    event CountIncremented(address indexed user, uint256 newCount);

    // 3. Immutable: owner is set at deploy-time and never changes
    address public immutable deployer;

    constructor() {
        deployer = msg.sender; // cheaper than storage owner
        owner = msg.sender;
        fee = 1 ether;
        isActive = true;
        count = 0;
    }

    // 4. Calldata optimization: use calldata for external read-only array/uint inputs
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        uint256 userBalance = balances[msg.sender]; // 5. Cache storage read
        require(amount <= userBalance, "Insufficient balance");
        balances[msg.sender] = userBalance - amount; // use cached variable
        payable(msg.sender).transfer(amount);
    }

    function increment(uint256 times) external {
        uint256 currentCount = count; // 5. Cache storage read
        for (uint256 i = 0; i < times; ) {
            unchecked { // 6. Unchecked arithmetic: no overflow risk
                currentCount += 1;
                i++;
            }
            emit CountIncremented(msg.sender, currentCount); // 7. Event-based logging
        }
        count = currentCount; // write once at the end
    }

    function toggleActive() external {
        // 8. Short-circuiting: check owner first
        require(msg.sender == owner, "Not owner");
        isActive = !isActive; // simpler toggle
    }

    function setFee(uint256 newFee) external {
        require(msg.sender == owner, "Not owner");
        fee = newFee;
    }
}