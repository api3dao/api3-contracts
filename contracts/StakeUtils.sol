//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./VestingUtils.sol";
import "./interfaces/IStakeUtils.sol";


/// @title Contract where the staking logic of the API3 pool is implemented
contract StakeUtils is VestingUtils, IStakeUtils {
    /// @param api3TokenAddress Address of the API3 token contract
    /// @param epochPeriodInSeconds Length of epochs used to quantize time
    /// @param firstEpochStartTimestamp Starting timestamp of epoch #1
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

    /// @notice Has the user stake all of their pool shares
    /// @param userAddress User address
    function stake(address userAddress)
        external
        override
    {
        uint256 nextEpochIndex = getCurrentEpochIndex().add(1);
        uint256 sharesStaked = stakesAtEpoch[userAddress][nextEpochIndex];
        uint256 sharesToStake = poolShares[userAddress];
        stakesAtEpoch[userAddress][nextEpochIndex] = sharesToStake;
        totalStakesAtEpoch[nextEpochIndex] = totalStakesAtEpoch[nextEpochIndex]
            .add(sharesToStake.sub(sharesStaked));
    }

    /// @notice Has the user collect rewards from the previous epoch
    /// @dev Requires the user to have staked in the two previous epoch
    /// @param userAddress User address
    function collect(address userAddress)
        external
        override
    {
        // Triggers the minting of inflationary rewards for this epoch if it
        // was not already. Note that this does not affect the rewards to be
        // received below, but rewards to be received in the next epoch.
        inflationManager.mintInflationaryRewardsToPool();

        uint256 currentEpochIndex = getCurrentEpochIndex();
        uint256 previousEpochIndex = currentEpochIndex.sub(1);
        uint256 twoPreviousEpochIndex = currentEpochIndex.sub(2);
        uint256 totalStakesInPreviousEpoch = totalStakesAtEpoch[previousEpochIndex];
        uint256 stakeInPreviousEpoch = stakesAtEpoch[userAddress][previousEpochIndex];

        // Carry over vested rewards from two epochs ago
        if (unpaidVestedRewardsAtEpoch[twoPreviousEpochIndex] != 0)
        {
            vestedRewardsAtEpoch[previousEpochIndex] = vestedRewardsAtEpoch[previousEpochIndex]
                .add(unpaidVestedRewardsAtEpoch[twoPreviousEpochIndex]);
            unpaidVestedRewardsAtEpoch[twoPreviousEpochIndex] = 0;
        }

        // Collect vested rewards
        uint256 vestedRewards = vestedRewardsAtEpoch[previousEpochIndex]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(vestedRewards);
        createVesting(userAddress, vestedRewards, currentEpochIndex.add(rewardVestingPeriod));
        unpaidVestedRewardsAtEpoch[previousEpochIndex] = unpaidVestedRewardsAtEpoch[previousEpochIndex]
            .sub(vestedRewards);

        // Carry over instant rewards from two epochs ago
        if (unpaidInstantRewardsAtEpoch[twoPreviousEpochIndex] != 0)
        {
            instantRewardsAtEpoch[previousEpochIndex] = instantRewardsAtEpoch[previousEpochIndex]
                .add(unpaidInstantRewardsAtEpoch[twoPreviousEpochIndex]);
            unpaidInstantRewardsAtEpoch[twoPreviousEpochIndex] = 0;
        }

        // Collect instant rewards
        uint256 instantRewards = instantRewardsAtEpoch[previousEpochIndex]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(instantRewards);
        unpaidInstantRewardsAtEpoch[previousEpochIndex] = unpaidInstantRewardsAtEpoch[previousEpochIndex]
            .sub(instantRewards);
    }
}
