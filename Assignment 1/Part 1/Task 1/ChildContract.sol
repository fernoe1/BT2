// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ChildContract {
    address public owner;
    string public name;

    constructor(address _owner, string memory _name) payable {
        owner = _owner;
        name = _name;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}