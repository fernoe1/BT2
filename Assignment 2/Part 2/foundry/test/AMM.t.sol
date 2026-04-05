// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";

contract AMMTest is Test {
    AMM amm;
    TokenA tokenA;
    TokenB tokenB;

    address user = address(1);

    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();

        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(user, 1000 ether);
        tokenB.transfer(user, 1000 ether);

        vm.startPrank(user);
        tokenA.approve(address(amm), type(uint).max);
        tokenB.approve(address(amm), type(uint).max);
        vm.stopPrank();
    }

    function testAddLiquidityFirst() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        assertEq(amm.reserveA(), 100 ether);
        assertEq(amm.reserveB(), 100 ether);
    }

    function testAddLiquiditySecond() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);
        amm.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        assertEq(amm.reserveA(), 200 ether);
    }

    function testRemoveLiquidityPartial() public {
        vm.startPrank(user);
        uint liquidity = amm.addLiquidity(100 ether, 100 ether);
        amm.removeLiquidity(liquidity / 2);
        vm.stopPrank();

        assertGt(amm.reserveA(), 0);
    }

    function testRemoveLiquidityFull() public {
        vm.startPrank(user);
        uint liquidity = amm.addLiquidity(100 ether, 100 ether);
        amm.removeLiquidity(liquidity);
        vm.stopPrank();

        assertEq(amm.reserveA(), 0);
    }

    function testSwapAtoB() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);
        amm.swap(address(tokenA), 10 ether, 1);
        vm.stopPrank();

        assertLt(amm.reserveB(), 100 ether);
    }

    function testSwapBtoA() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);
        amm.swap(address(tokenB), 10 ether, 1);
        vm.stopPrank();

        assertLt(amm.reserveA(), 100 ether);
    }

    function testInvariantIncrease() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);

        uint kBefore = amm.reserveA() * amm.reserveB();

        amm.swap(address(tokenA), 10 ether, 1);

        uint kAfter = amm.reserveA() * amm.reserveB();
        vm.stopPrank();

        assertGe(kAfter, kBefore);
    }

    function testSlippageRevert() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);

        vm.expectRevert();
        amm.swap(address(tokenA), 10 ether, 100 ether);
        vm.stopPrank();
    }

    function testZeroInputRevert() public {
        vm.startPrank(user);
        vm.expectRevert();
        amm.swap(address(tokenA), 0, 0);
        vm.stopPrank();
    }

    function testLargeSwap() public {
        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);
        amm.swap(address(tokenA), 90 ether, 1);
        vm.stopPrank();

        assertTrue(true);
    }

    function testFuzzSwap(uint amount) public {
        vm.assume(amount > 1 ether && amount < 100 ether);

        vm.startPrank(user);
        amm.addLiquidity(100 ether, 100 ether);

        uint kBefore = amm.reserveA() * amm.reserveB();
        amm.swap(address(tokenA), amount, 1);
        uint kAfter = amm.reserveA() * amm.reserveB();

        vm.stopPrank();

        assertGe(kAfter, kBefore);
    }
}