// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOracle {
    function getPrice() external view returns (uint256);
}

contract LendingPool {
    IERC20 public immutable token;
    IOracle public oracle;

    uint256 public constant LTV = 75; // %
    uint256 public constant PRECISION = 1e18;
    uint256 public interestRate = 5e16; // 5% yearly (scaled)

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    constructor(address _token, address _oracle) {
        token = IERC20(_token);
        oracle = IOracle(_oracle);
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateral += amount;
    }

    function _accrueInterest(address user) internal {
        Position storage p = positions[user];
        if (p.debt == 0) return;

        uint256 timeElapsed = block.timestamp - p.lastUpdate;
        uint256 interest = (p.debt * interestRate * timeElapsed) / (365 days * PRECISION);
        p.debt += interest;
    }

    function borrow(uint256 amount) external {
        Position storage p = positions[msg.sender];
        _accrueInterest(msg.sender);

        uint256 price = oracle.getPrice();
        uint256 collateralValue = (p.collateral * price) / PRECISION;
        uint256 maxBorrow = (collateralValue * LTV) / 100;

        require(p.debt + amount <= maxBorrow, "Exceeds LTV");

        p.debt += amount;
        p.lastUpdate = block.timestamp;

        token.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        Position storage p = positions[msg.sender];
        _accrueInterest(msg.sender);

        token.transferFrom(msg.sender, address(this), amount);

        if (amount > p.debt) {
            p.debt = 0;
        } else {
            p.debt -= amount;
        }
    }

    function withdraw(uint256 amount) external {
        Position storage p = positions[msg.sender];
        _accrueInterest(msg.sender);

        require(p.collateral >= amount, "Not enough collateral");

        p.collateral -= amount;

        require(getHealthFactor(msg.sender) > PRECISION, "HF < 1");

        token.transfer(msg.sender, amount);
    }

    function liquidate(address user) external {
        Position storage p = positions[user];
        _accrueInterest(user);

        require(getHealthFactor(user) < PRECISION, "Healthy");

        uint256 debt = p.debt;
        p.debt = 0;

        uint256 collateral = p.collateral;
        p.collateral = 0;

        token.transferFrom(msg.sender, address(this), debt);
        token.transfer(msg.sender, collateral);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        Position memory p = positions[user];
        if (p.debt == 0) return type(uint256).max;

        uint256 price = oracle.getPrice();
        uint256 collateralValue = (p.collateral * price) / PRECISION;
        uint256 adjusted = (collateralValue * LTV) / 100;

        return (adjusted * PRECISION) / p.debt;
    }
}