// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YieldVault is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    uint8 private immutable _decimals;

    uint256 private constant ROUND_DOWN = 0;
    uint256 private constant ROUND_UP = 1;

    event Harvest(uint256 yieldAmount, uint256 newSharePrice);

    constructor(IERC20 _asset, string memory name, string memory symbol) 
        ERC20(name, symbol) 
        Ownable(msg.sender) 
    {
        asset = _asset;
        _decimals = ERC20(address(_asset)).decimals();
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _convertToAssets(uint256 shares, uint256 rounding) internal view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 totalAssets_ = totalAssets();

        if (totalSupply_ == 0 || totalAssets_ == 0) {
            return shares;
        }

        uint256 assets = (shares * totalAssets_) / totalSupply_;
        
        if (rounding == ROUND_UP && (assets * totalSupply_) < (shares * totalAssets_)) {
            assets++;
        }
        
        return assets;
    }

    function _convertToShares(uint256 assets, uint256 rounding) internal view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 totalAssets_ = totalAssets();

        if (totalSupply_ == 0 || totalAssets_ == 0) {
            return assets;
        }

        uint256 shares = (assets * totalSupply_) / totalAssets_;
        
        if (rounding == ROUND_UP && (shares * totalAssets_) < (assets * totalSupply_)) {
            shares++;
        }
        
        return shares;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, ROUND_DOWN);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, ROUND_DOWN);
    }

    function harvest(uint256 yieldAmount) external onlyOwner {
        require(yieldAmount > 0, "YieldVault: zero yield");
        
        asset.safeTransferFrom(msg.sender, address(this), yieldAmount);
        
        emit Harvest(yieldAmount, previewRedeem(1e18));
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "YieldVault: zero assets");
        
        shares = previewDeposit(assets);
        require(shares > 0, "YieldVault: zero shares");
        
        asset.safeTransferFrom(msg.sender, address(this), assets);
        
        _mint(receiver, shares);
        
        return shares;
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        require(shares > 0, "YieldVault: zero shares");
        
        assets = previewMint(shares);
        require(assets > 0, "YieldVault: zero assets");
        
        asset.safeTransferFrom(msg.sender, address(this), assets);
        
        _mint(receiver, shares);
        
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        require(assets > 0, "YieldVault: zero assets");
        require(receiver != address(0), "YieldVault: zero receiver");
        
        shares = previewWithdraw(assets);
        require(shares > 0, "YieldVault: zero shares");
        
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);
        
        asset.safeTransfer(receiver, assets);
        
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(shares > 0, "YieldVault: zero shares");
        require(receiver != address(0), "YieldVault: zero receiver");
        
        assets = previewRedeem(shares);
        require(assets > 0, "YieldVault: zero assets");
        
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        _burn(owner, shares);
        
        asset.safeTransfer(receiver, assets);
        
        return assets;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, ROUND_DOWN);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, ROUND_UP);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, ROUND_UP);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, ROUND_DOWN);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        uint256 assets = convertToAssets(balanceOf(owner));
        return assets;
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }
}