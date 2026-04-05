// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public amm;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        amm = msg.sender;
    }

    modifier onlyAMM() {
        require(msg.sender == amm, "Not AMM");
        _;
    }

    function mint(address to, uint amount) external onlyAMM {
        _mint(to, amount);
    }

    function burn(address from, uint amount) external onlyAMM {
        _burn(from, amount);
    }
}