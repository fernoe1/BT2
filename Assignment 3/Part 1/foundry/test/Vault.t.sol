// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

contract YieldVaultTest is Test {
    YieldVault public vault;
    MockToken public asset;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public owner = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        asset = new MockToken();
        vault = new YieldVault(asset, "Yield Vault", "yVault");
        
        asset.mint(alice, 100_000 * 10 ** 18);
        asset.mint(bob, 100_000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_Deposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), depositAmount);
        assertApproxEqAbs(vault.convertToAssets(shares), depositAmount, 1);
        vm.stopPrank();
    }

    function test_Mint() public {
        uint256 sharesToMint = 100 * 10 ** 18;
        
        vm.startPrank(alice);
        uint256 assetsNeeded = vault.previewMint(sharesToMint);
        asset.approve(address(vault), assetsNeeded);
        uint256 assetsUsed = vault.mint(sharesToMint, alice);
        
        assertEq(vault.balanceOf(alice), sharesToMint);
        assertEq(assetsUsed, assetsNeeded);
        assertEq(vault.totalAssets(), assetsNeeded);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        uint256 withdrawAmount = 500 * 10 ** 18;
        uint256 sharesBurned = vault.withdraw(withdrawAmount, alice, alice);
        
        assertEq(vault.balanceOf(alice), shares - sharesBurned);
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
        assertEq(asset.balanceOf(alice), 100_000 * 10 ** 18 - depositAmount + withdrawAmount);
        vm.stopPrank();
    }

    function test_Redeem() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        uint256 redeemShares = shares / 2;
        uint256 assetsReceived = vault.redeem(redeemShares, alice, alice);
        
        assertEq(vault.balanceOf(alice), shares - redeemShares);
        assertEq(vault.totalAssets(), depositAmount - assetsReceived);
        vm.stopPrank();
    }

    function test_SharePriceIncreasesAfterHarvest() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();
        
        uint256 initialSharePrice = vault.previewRedeem(1e18);
        
        vm.startPrank(owner);
        uint256 yieldAmount = 100 * 10 ** 18;
        asset.mint(owner, yieldAmount);
        asset.approve(address(vault), yieldAmount);
        vault.harvest(yieldAmount);
        vm.stopPrank();
        
        uint256 newSharePrice = vault.previewRedeem(1e18);
        assertGt(newSharePrice, initialSharePrice);
        
        uint256 aliceAssets = vault.convertToAssets(vault.balanceOf(alice));
        assertGt(aliceAssets, depositAmount);
    }

    function test_ConvertToSharesRounding() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        uint256 smallAssets = 123456789;
        uint256 shares = vault.previewDeposit(smallAssets);
        
        uint256 expectedShares = (smallAssets * vault.totalSupply()) / vault.totalAssets();
        assertEq(shares, expectedShares);
        
        uint256 targetShares = 123456789;
        uint256 assetsNeeded = vault.previewMint(targetShares);
        
        uint256 expectedAssets = (targetShares * vault.totalAssets() + vault.totalSupply() - 1) / vault.totalSupply();
        assertEq(assetsNeeded, expectedAssets);
        
        vm.stopPrank();
    }

    function test_EdgeCase_ZeroSupply() public view {
        uint256 assets = 1000 * 10 ** 18;
        uint256 shares = vault.convertToShares(assets);
        assertEq(shares, assets);
        
        assets = vault.convertToAssets(shares);
        assertEq(assets, shares);
    }

    function test_MultipleDepositsAndWithdrawals() public {
        uint256 aliceDeposit = 1000 * 10 ** 18;
        uint256 bobDeposit = 2000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        asset.approve(address(vault), bobDeposit);
        vault.deposit(bobDeposit, bob);
        vm.stopPrank();
        
        vm.startPrank(owner);
        uint256 yieldAmount = 300 * 10 ** 18;
        asset.mint(owner, yieldAmount);
        asset.approve(address(vault), yieldAmount);
        vault.harvest(yieldAmount);
        vm.stopPrank();
        
        uint256 aliceAssetsAfter = vault.convertToAssets(vault.balanceOf(alice));
        uint256 bobAssetsAfter = vault.convertToAssets(vault.balanceOf(bob));
        
        assertApproxEqAbs(aliceAssetsAfter, 1100 * 10 ** 18, 1e15);
        assertApproxEqAbs(bobAssetsAfter, 2200 * 10 ** 18, 1e15);
        
        vm.startPrank(bob);
        uint256 bobSharesBalance = vault.balanceOf(bob);
        uint256 bobWithdrawn = vault.redeem(bobSharesBalance, bob, bob);
        assertApproxEqAbs(bobWithdrawn, bobAssetsAfter, 1e15);
        vm.stopPrank();
    }

    function test_EdgeCase_MaxWithdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        assertEq(maxWithdraw, depositAmount);
        
        vault.withdraw(300 * 10 ** 18, alice, alice);
        maxWithdraw = vault.maxWithdraw(alice);
        assertEq(maxWithdraw, 700 * 10 ** 18);
        vm.stopPrank();
    }

    function test_EdgeCase_ZeroAmounts() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000 * 10 ** 18);
        
        vm.expectRevert("YieldVault: zero assets");
        vault.deposit(0, alice);
        
        vm.expectRevert("YieldVault: zero shares");
        vault.mint(0, alice);
        
        vm.stopPrank();
    }
}