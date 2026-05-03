// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

import { DaoGovernorParams } from "./DaoGovernorParams.sol";
import { TokenVesting } from "./TokenVesting.sol";

/**
 * @notice Fixed-supply ERC-20 with votes + permit.
 * Allocation: 40% team vesting (12-month linear vesting wallet), 30% treasury, 20% community, 10% liquidity.
 */
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    TokenVesting public immutable teamVesting;

    constructor(address teamBeneficiary, address treasury, address community, address liquidity)
        ERC20("DAO Governance Token", "DGVT")
        ERC20Permit("DAO Governance Token")
    {
        uint256 initial = DaoGovernorParams.INITIAL_SUPPLY;
        uint256 teamAmount = initial * 40 / 100;
        uint256 treasuryAmount = initial * 30 / 100;
        uint256 communityAmount = initial * 20 / 100;
        uint256 liquidityAmount = initial * 10 / 100;

        teamVesting =
            new TokenVesting(IERC20(address(this)), teamBeneficiary, uint64(block.timestamp), teamAmount, 365 days);

        _mint(address(teamVesting), teamAmount);
        _mint(treasury, treasuryAmount);
        _mint(community, communityAmount);
        _mint(liquidity, liquidityAmount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
