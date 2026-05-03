// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @notice Assumes roughly 12-second mainnet-style blocks (~7200 blocks per day, ~50400 per week).
 */
library DaoGovernorParams {
    uint48 internal constant VOTING_DELAY_BLOCKS = 7200;
    uint32 internal constant VOTING_PERIOD_BLOCKS = 50400;
    uint256 internal constant TIMELOCK_DELAY_SECONDS = 2 days;

    uint8 internal constant QUORUM_PERCENT = 4;
    uint8 internal constant PROPOSAL_THRESHOLD_PERCENT = 1;

    uint256 internal constant INITIAL_SUPPLY = 100_000_000e18;
}
