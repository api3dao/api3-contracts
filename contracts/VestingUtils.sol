//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./PoolUtils.sol";


contract VestingUtils is PoolUtils {
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        PoolUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    function createVesting(
        address userAddress,
        uint256 amount,
        uint256 vestingEpoch
        )
        internal
    {
        unvestedFunds[userAddress] = unvestedFunds[userAddress].add(amount);
        bytes32 vestingId = keccak256(abi.encodePacked(
            noVestings,
            this
            ));
        noVestings = noVestings.add(1);
        vestings[vestingId] = Vesting({
            userAddress: userAddress,
            amount: amount,
            epoch: vestingEpoch
            });
    }

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        require(getCurrentEpochNumber() >= vesting.epoch, "Cannot vest before vesting.epoch");
        unvestedFunds[vesting.userAddress] = unvestedFunds[vesting.userAddress].sub(vesting.amount);
        delete vestings[vestingId];
    }
}
