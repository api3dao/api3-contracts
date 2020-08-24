//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IVestingUtils {
    function vest(bytes32 vestingId)
        external;
}
