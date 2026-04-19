// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceDependentVault {
    AggregatorV3Interface public priceFeed;
    uint256 public threshold; 

    mapping(address => uint256) public balances;

    constructor(address _feed, uint256 _threshold) {
        priceFeed = AggregatorV3Interface(_feed);
        threshold = _threshold;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function getLatestPrice() public view returns (int256 price) {
        uint256 updatedAt;
        (, price, , updatedAt, ) = priceFeed.latestRoundData();

        require(block.timestamp - updatedAt < 1 hours, "Stale price");
    }

    function getUSDValue(uint256 ethAmount) public view returns (uint256) {
        int256 price = getLatestPrice();

        return (ethAmount * uint256(price)) / 1e18;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        uint256 usdValue = getUSDValue(amount);
        require(usdValue >= threshold, "Price too low");

        balances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
}