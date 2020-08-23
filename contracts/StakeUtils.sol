//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./VestingUtils.sol";


contract StakeUtils is VestingUtils {
    constructor(
        address api3TokenAddress,
        uint256 epochPeriodInSeconds,
        uint256 firstEpochStartTimestamp
        )
        VestingUtils(
            api3TokenAddress,
            epochPeriodInSeconds,
            firstEpochStartTimestamp
            )
        public
        {}

    function stake(address userAddress)
        external
    {
        uint256 nextEpochNumber = getCurrentEpochNumber().add(1);
        uint256 sharesStaked = stakesAtEpoch[userAddress][nextEpochNumber];
        uint256 sharesToStake = poolShares[userAddress];
        stakesAtEpoch[userAddress][nextEpochNumber] = sharesToStake;
        totalStakesAtEpoch[nextEpochNumber] = totalStakesAtEpoch[nextEpochNumber]
            .add(sharesToStake.sub(sharesStaked));
    }

    function collect(address userAddress)
        external
    {
        inflationManager.mintInflationaryRewardsToPool();

        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 previousEpochNumber = currentEpochNumber.sub(1);
        uint256 twoPreviousEpochNumber = currentEpochNumber.sub(2);
        uint256 totalStakesInPreviousEpoch = totalStakesAtEpoch[previousEpochNumber];
        uint256 stakeInPreviousEpoch = stakesAtEpoch[userAddress][previousEpochNumber];

        // Carry over vested rewards from two epochs ago
        if (unpaidVestedRewardsAtEpoch[twoPreviousEpochNumber] != 0)
        {
            vestedRewardsAtEpoch[previousEpochNumber] = vestedRewardsAtEpoch[previousEpochNumber]
                .add(unpaidVestedRewardsAtEpoch[twoPreviousEpochNumber]);
            unpaidVestedRewardsAtEpoch[twoPreviousEpochNumber] = 0;
        }

        uint256 vestedRewards = vestedRewardsAtEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(vestedRewards);
        createVesting(userAddress, vestedRewards, currentEpochNumber.add(rewardVestingPeriod));
        unpaidVestedRewardsAtEpoch[previousEpochNumber] = unpaidVestedRewardsAtEpoch[previousEpochNumber]
            .sub(vestedRewards);

        // Carry over instant rewards from two epochs ago
        if (unpaidInstantRewardsAtEpoch[twoPreviousEpochNumber] != 0)
        {
            instantRewardsAtEpoch[previousEpochNumber] = instantRewardsAtEpoch[previousEpochNumber]
                .add(unpaidInstantRewardsAtEpoch[twoPreviousEpochNumber]);
            unpaidInstantRewardsAtEpoch[twoPreviousEpochNumber] = 0;
        }

        uint256 instantRewards = instantRewardsAtEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(instantRewards);
        unpaidInstantRewardsAtEpoch[previousEpochNumber] = unpaidInstantRewardsAtEpoch[previousEpochNumber]
            .sub(instantRewards);
    }
}
