// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Simple state holder controlled exclusively by governance (via timelock).
 */
contract Box {
    address public timelock;
    uint256 private _stored;

    error BoxUnauthorizedCaller();

    event ValueChanged(uint256 newValue);

    modifier onlyTimelock() {
        if (msg.sender != timelock) {
            revert BoxUnauthorizedCaller();
        }
        _;
    }

    constructor(address timelock_) {
        timelock = timelock_;
    }

    function store(uint256 newValue) external onlyTimelock {
        _stored = newValue;
        emit ValueChanged(newValue);
    }

    function retrieve() external view returns (uint256) {
        return _stored;
    }
}
