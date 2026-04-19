// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseToken.sol";

contract SimpleAMM {
    BaseToken public token;
    uint256 public ethReserve;
    uint256 public tokenReserve;
    uint256 public constant FEE = 30; // 0.3
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event Swap(address indexed user, uint256 ethIn, uint256 tokenOut, bool isEthToToken);
    
    constructor(address _tokenAddress) {
        token = BaseToken(_tokenAddress);
    }
    
    function addLiquidity(uint256 tokenAmount) external payable {
        require(msg.value > 0, "Need ETH");
        require(tokenAmount > 0, "Need tokens");
        
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        
        if (ethReserve == 0 && tokenReserve == 0) {
            ethReserve = msg.value;
            tokenReserve = tokenAmount;
        } else {
            uint256 requiredTokens = (msg.value * tokenReserve) / ethReserve;
            require(tokenAmount >= requiredTokens, "Incorrect token amount");
            
            ethReserve += msg.value;
            tokenReserve += requiredTokens;
            
            if (tokenAmount > requiredTokens) {
                token.transfer(msg.sender, tokenAmount - requiredTokens);
            }
        }
        
        emit LiquidityAdded(msg.sender, msg.value, tokenAmount);
    }
    
    function ethToToken(uint256 minTokens) external payable {
        require(msg.value > 0, "Need ETH");
        
        uint256 tokenOut = getTokenAmount(msg.value, ethReserve, tokenReserve);
        require(tokenOut >= minTokens, "Slippage too high");
        
        uint256 fee = (msg.value * FEE) / FEE_DENOMINATOR;
        uint256 ethInAfterFee = msg.value - fee;
        
        ethReserve += ethInAfterFee;
        tokenReserve -= tokenOut;
        
        require(token.transfer(msg.sender, tokenOut), "Token transfer failed");
        
        emit Swap(msg.sender, msg.value, tokenOut, true);
    }
    
    function tokenToEth(uint256 tokenAmount, uint256 minEth) external {
        require(tokenAmount > 0, "Need tokens");
        
        uint256 ethOut = getEthAmount(tokenAmount, tokenReserve, ethReserve);
        require(ethOut >= minEth, "Slippage too high");
        
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        
        uint256 fee = (tokenAmount * FEE) / FEE_DENOMINATOR;
        uint256 tokenInAfterFee = tokenAmount - fee;
        
        tokenReserve += tokenInAfterFee;
        ethReserve -= ethOut;
        
        (bool success, ) = payable(msg.sender).call{value: ethOut}("");
        require(success, "ETH transfer failed");
        
        emit Swap(msg.sender, ethOut, tokenAmount, false);
    }
    
    function getTokenAmount(uint256 ethAmount, uint256 ethRes, uint256 tokenRes) public pure returns (uint256) {
        return (ethAmount * tokenRes) / (ethRes + ethAmount);
    }
    
    function getEthAmount(uint256 tokenAmount, uint256 tokenRes, uint256 ethRes) public pure returns (uint256) {
        return (tokenAmount * ethRes) / (tokenRes + tokenAmount);
    }
    
    function getPrice() external view returns (uint256 ethPerToken) {
        if (tokenReserve > 0) {
            return ethReserve / tokenReserve;
        }
        return 0;
    }
    
    receive() external payable {}
}