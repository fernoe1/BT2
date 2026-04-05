// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockPriceOracle.sol";
import "../src/MockERC20.sol"; 
import "../src/LendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

contract LendingPoolTest is Test {
    LendingPool pool;
    MockERC20 token;
    MockPriceOracle oracle;

    address user = address(1);
    address liquidator = address(2);

    function setUp() public {
        token = new MockERC20();
        oracle = new MockPriceOracle();
        pool = new LendingPool(address(token), address(oracle));

        token.mint(user, 1000 ether);
        token.mint(liquidator, 1000 ether);

        vm.startPrank(user);
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.prank(user);
        pool.deposit(100 ether);

        (uint256 collateral,,) = pool.positions(user);
        assertEq(collateral, 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.withdraw(50 ether);
        vm.stopPrank();

        (uint256 collateral,,) = pool.positions(user);
        assertEq(collateral, 50 ether);
    }

    function testBorrowWithinLTV() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        (,uint256 debt,) = pool.positions(user);
        assertEq(debt, 50 ether);
    }

    function testBorrowExceedLTV() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        vm.expectRevert();
        pool.borrow(80 ether);
        vm.stopPrank();
    }

    function testRepayPartial() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(20 ether);
        vm.stopPrank();

        (,uint256 debt,) = pool.positions(user);
        assertEq(debt, 30 ether);
    }

    function testRepayFull() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(50 ether);
        vm.stopPrank();

        (,uint256 debt,) = pool.positions(user);
        assertEq(debt, 0);
    }

    function testLiquidation() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(70 ether);
        vm.stopPrank();

        oracle.setPrice(5e17); // price drops 50%

        vm.prank(liquidator);
        pool.liquidate(user);

        (uint256 collateral,uint256 debt,) = pool.positions(user);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function testInterestAccrual() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);

        vm.warp(block.timestamp + 365 days);

        pool.repay(1 ether);
        vm.stopPrank();

        (,uint256 debt,) = pool.positions(user);
        assertGt(debt, 50 ether);
    }

    function testBorrowZeroCollateral() public {
        vm.prank(user);
        vm.expectRevert();
        pool.borrow(10 ether);
    }

    function testWithdrawWithDebtFails() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(70 ether);

        vm.expectRevert();
        pool.withdraw(50 ether);
        vm.stopPrank();
    }
}