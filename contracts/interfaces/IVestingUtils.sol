//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IVestingUtils {
    event VestingCreated(
        bytes32 indexed vestingId,
        address indexed userAddress,
        uint256 amount,
        uint256 vestingEpoch
        );

    event VestingResolved(bytes32 indexed vestingId);

    function vest(bytes32 vestingId)
        external;
}
