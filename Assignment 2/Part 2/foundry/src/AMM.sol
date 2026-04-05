// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMM {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE = 3; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed user, uint amountA, uint amountB, uint liquidity);
    event LiquidityRemoved(address indexed user, uint amountA, uint amountB, uint liquidity);
    event Swap(address indexed user, address tokenIn, uint amountIn, uint amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken("LP Token", "LPT");
    }

    function _updateReserves(uint _reserveA, uint _reserveB) private {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    function addLiquidity(uint amountA, uint amountB) external returns (uint liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (lpToken.totalSupply() == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * lpToken.totalSupply()) / reserveA,
                (amountB * lpToken.totalSupply()) / reserveB
            );
        }

        require(liquidity > 0, "Insufficient liquidity");

        lpToken.mint(msg.sender, liquidity);

        _updateReserves(
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this))
        );

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint liquidity) external returns (uint amountA, uint amountB) {
        require(liquidity > 0, "Invalid liquidity");

        uint totalSupply = lpToken.totalSupply();

        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        lpToken.burn(msg.sender, liquidity);

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        _updateReserves(
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this))
        );

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swap(address tokenIn, uint amountIn, uint minAmountOut)
        external
        returns (uint amountOut)
    {
        require(amountIn > 0, "Invalid input");

        bool isA = tokenIn == address(tokenA);
        require(isA || tokenIn == address(tokenB), "Invalid token");

        (IERC20 inToken, IERC20 outToken, uint reserveIn, uint reserveOut) =
            isA
                ? (tokenA, tokenB, reserveA, reserveB)
                : (tokenB, tokenA, reserveB, reserveA);

        inToken.transferFrom(msg.sender, address(this), amountIn);

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "Slippage");

        outToken.transfer(msg.sender, amountOut);

        _updateReserves(
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this))
        );

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        returns (uint)
    {
        uint amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    function min(uint x, uint y) private pure returns (uint) {
        return x < y ? x : y;
    }

    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}