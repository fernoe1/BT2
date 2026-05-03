// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Holds ETH and ERC-20s; withdrawals and parameter updates are routed through governance (timelock).
 */
contract Treasury {
    using SafeERC20 for IERC20;

    address public timelock;
    uint96 public treasuryFeeBps;

    error TreasuryUnauthorizedCaller();

    event EtherWithdrawal(address indexed to, uint256 amount);
    event TokenWithdrawal(address indexed token, address indexed to, uint256 amount);
    event TimelockUpdated(address indexed timelock);
    event FeeBpsUpdated(uint96 feeBps);

    modifier onlyTimelock() {
        if (msg.sender != timelock) {
            revert TreasuryUnauthorizedCaller();
        }
        _;
    }

    constructor(address timelock_) {
        timelock = timelock_;
    }

    receive() external payable { }

    function setTreasuryFeeBps(uint96 newFeeBps) external onlyTimelock {
        require(newFeeBps <= 10_000);
        treasuryFeeBps = newFeeBps;
        emit FeeBpsUpdated(newFeeBps);
    }

    /**
     * @notice Governance-only operational parameter (e.g. future migration hooks).
     */
    function updateTimelock(address newTimelock) external onlyTimelock {
        timelock = newTimelock;
        emit TimelockUpdated(newTimelock);
    }

    function withdrawEther(address payable to, uint256 amount) external onlyTimelock {
        (bool ok,) = to.call{ value: amount }("");
        require(ok);
        emit EtherWithdrawal(to, amount);
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyTimelock {
        IERC20(token).safeTransfer(to, amount);
        emit TokenWithdrawal(token, to, amount);
    }
}
