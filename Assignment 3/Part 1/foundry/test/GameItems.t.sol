// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameItems.sol";

contract GameItemsTest is Test {
    GameItems game;

    address owner = address(this);
    address user = address(0x1);
    address receiver = address(0x2); 

    function setUp() public {
        game = new GameItems();
    }

    function testMintSingle() public {
        game.mint(user, game.GOLD(), 100);
        assertEq(game.balanceOf(user, game.GOLD()), 100);
    }

    function testMintBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        ids[0] = game.GOLD();
        ids[1] = game.WOOD();
        ids[2] = game.IRON();

        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        game.mintBatch(user, ids, amounts);

        assertEq(game.balanceOf(user, game.WOOD()), 200);
    }

    function testCraftSword() public {
        game.mint(user, game.GOLD(), 100);
        game.mint(user, game.IRON(), 50);

        vm.prank(user);
        game.craftSword();

        assertEq(game.balanceOf(user, game.LEGENDARY_SWORD()), 1);
    }

    function testCraftSwordFailsWithoutResources() public {
        vm.prank(user);
        vm.expectRevert();
        game.craftSword();
    }

    function testSafeTransfer() public {
        game.mint(user, game.GOLD(), 100);

        vm.startPrank(user);
        game.setApprovalForAll(address(this), true);
        game.safeTransferFrom(user, receiver, game.GOLD(), 50, "");
        vm.stopPrank();

        assertEq(game.balanceOf(receiver, game.GOLD()), 50);
    }

    function testBatchTransfer() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = game.GOLD();
        ids[1] = game.WOOD();

        amounts[0] = 100;
        amounts[1] = 100;

        game.mintBatch(user, ids, amounts);

        uint256[] memory sendAmounts = new uint256[](2);
        sendAmounts[0] = 50;
        sendAmounts[1] = 50;

        vm.startPrank(user);
        game.setApprovalForAll(address(this), true);
        game.safeBatchTransferFrom(user, receiver, ids, sendAmounts, "");
        vm.stopPrank();

        assertEq(game.balanceOf(receiver, game.WOOD()), 50);
    }

    function testTransferReducesBalance() public {
        game.mint(user, game.GOLD(), 100);

        vm.startPrank(user);
        game.setApprovalForAll(address(this), true);
        game.safeTransferFrom(user, receiver, game.GOLD(), 50, "");
        vm.stopPrank();

        assertEq(game.balanceOf(user, game.GOLD()), 50);
    }

    function testURI() public view {
        string memory uri = game.uri(1);
        assertTrue(bytes(uri).length > 0);
    }
}