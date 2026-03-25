// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ChildContract.sol";

contract Factory {
    address[] public deployedContracts;

    function create(string memory _name) public payable returns (address) {
        ChildContract child = new ChildContract{value: msg.value}(msg.sender, _name);

        deployedContracts.push(address(child));

        return address(child);
    }

    function create2(string memory _name, bytes32 salt) public payable returns (address) {
        ChildContract child = new ChildContract{salt: salt, value: msg.value}(msg.sender, _name);

        deployedContracts.push(address(child));

        return address(child);
    }

    function getDeployedContracts() public view returns (address[] memory) {
        return deployedContracts;
    }
}