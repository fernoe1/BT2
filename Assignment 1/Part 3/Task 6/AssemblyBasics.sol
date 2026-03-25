// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AssemblyBasics {
    uint256 public storedValue;

    // gets sender using assembly
    function getSenderAsm() public view returns (address sender) {
        assembly {
            sender := caller()
        }
    }

    // checks if a number is a power of two using assembly
    function isPowerOfTwoAsm(uint256 x) public pure returns (bool result) {
        assembly {
            if iszero(x) {
                result := 0
            }

            let check := and(x, sub(x, 1))

            if and(x, iszero(check)) {
                result := 1
            }
        }
    }

    // set value using assembly
    function setValueAsm(uint256 _value) public {
        assembly {
            sstore(0, _value)
        }
    }

    // get value using assembly
    function getValueAsm() public view returns (uint256 value) {
        assembly {
            value := sload(0)
        }
    }
}