// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Linear ERC-20 release to a fixed beneficiary over 12 months starting at `start`.
 */
contract TokenVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable start;
    uint256 public immutable duration;
    uint256 public immutable allocation;
    uint256 public released;

    error TokenVestingNothingToRelease();

    event Released(address indexed beneficiary, uint256 amount);

    constructor(IERC20 token_, address beneficiary_, uint64 start_, uint256 allocation_, uint256 duration_) {
        token = token_;
        beneficiary = beneficiary_;
        start = start_;
        duration = duration_;
        allocation = allocation_;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp <= start) {
            return 0;
        }
        uint256 elapsed = timestamp - start;
        if (elapsed >= duration) {
            return allocation;
        }
        return (allocation * elapsed) / duration;
    }

    function releasable() public view returns (uint256) {
        uint256 vested = vestedAmount(block.timestamp);
        unchecked {
            if (vested <= released) return 0;
            return vested - released;
        }
    }

    function release() external {
        uint256 amount = releasable();
        if (amount == 0) {
            revert TokenVestingNothingToRelease();
        }
        released += amount;
        token.safeTransfer(beneficiary, amount);
        emit Released(beneficiary, amount);
    }
}
