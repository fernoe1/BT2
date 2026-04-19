// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PriceDependentVault.sol";
import "../src/MockAggregator.sol";

contract VaultTest is Test {
    PriceDependentVault vault;
    MockAggregator mock;

    address user = address(1);

    function setUp() public {
        mock = new MockAggregator(2000e8);
        vault = new PriceDependentVault(address(mock), 1000e8);

        vm.deal(user, 10 ether);
    }

    function testDeposit() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(user), 1 ether);
    }

    function testWithdrawAboveThreshold() public {
        vm.startPrank(user);

        vault.deposit{value: 1 ether}();
        vault.withdraw(1 ether);

        vm.stopPrank();
    }

    function testRevertBelowThreshold() public {
        mock.setPrice(500e8); 

        vm.startPrank(user);

        vault.deposit{value: 1 ether}();

        vm.expectRevert("Price too low");
        vault.withdraw(1 ether);

        vm.stopPrank();
    }

    function testStalePrice() public {
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Stale price");
        vault.getLatestPrice();
    }
}