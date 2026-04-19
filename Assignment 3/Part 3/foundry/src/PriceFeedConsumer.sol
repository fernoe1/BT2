// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceFeedConsumer {
    AggregatorV3Interface public priceFeed;

    constructor(address _feed) {
        priceFeed = AggregatorV3Interface(_feed);
    }

    function getLatestPrice() public view returns (int256) {
        (
            ,
            int256 price,
            ,
            uint256 updatedAt,

        ) = priceFeed.latestRoundData();

        require(block.timestamp - updatedAt < 1 hours, "Stale price");

        return price;
    }

    function getDecimals() public view returns (uint8) {
        return priceFeed.decimals();
    }
}