// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LogicV1.sol";

contract LogicV2 is LogicV1 {
    function decrement() public {
        require(counter > 0, "Counter is already zero");
        counter -= 1;
    }

    function reset() public {
        counter = 0;
    }
}