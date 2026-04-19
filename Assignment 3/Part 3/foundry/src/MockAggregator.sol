// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAggregator {
    int256 private price;
    uint8 public decimals = 8;
    uint256 public updatedAt;

    constructor(int256 _price) {
        price = _price;
        updatedAt = block.timestamp;
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, price, 0, updatedAt, 0);
    }
}