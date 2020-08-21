//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    struct Vesting
    {
        address userAddress;
        uint256 amount;
        uint256 epoch;
    }
  
    // User balances, includes vested and unvested funds (not IOUs)
    mapping(address => uint256) private balances;
    // User unvested funds
    mapping(address => uint256) private unvestedFunds;

    // Total funds in the pool
    uint256 private totalPoolFunds;
    // Total number of pool shares
    uint256 private totalPoolShares;
    // User pool shares
    mapping(address => uint256) private poolShares;

    // Total staked pool shares at each epoch
    mapping(uint256 => uint256) private totalStakesPerEpoch;
    // User staked pool shares at each epoch
    mapping(address => mapping(uint256 => uint256)) private stakesPerEpoch;

    // Total rewards to be vested at each epoch
    mapping(uint256 => uint256) private vestedRewardsPerEpoch;
    // Total rewards at each epoch (not vested, received immediately)
    mapping(uint256 => uint256) private rewardsPerEpoch;

    // The epoch when the user made the last unpool request
    mapping(address => uint256) private unpoolRequestEpochs;
    
    // A record of vestings
    uint256 private noVestings;
    mapping(bytes32 => Vesting) private vestings;

    // TODO: Make these updatable
    uint256 private unpoolRequestCooldown = 4; // in epochs
    uint256 private unpoolWaitingPeriod = 2; // in epochs
    uint256 private rewardVestingPeriod = 52; // in epochs

    constructor(
        address api3TokenAddress,
        address inflationScheduleAddress,
        uint256 epochPeriodInSeconds
        )
        InterfaceUtils(
            api3TokenAddress,
            inflationScheduleAddress
            )
        EpochUtils(epochPeriodInSeconds)
        public
        {}
    
    function deposit(
        address sourceAddress,
        uint256 amount,
        address userAddress,
        uint256 vestingEpoch
        )
        external
    {
        api3Token.transferFrom(sourceAddress, address(this), amount);
        balances[userAddress] = balances[userAddress].add(amount);
        if (vestingEpoch != 0)
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
    }

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        require(getCurrentEpochNumber() < vesting.epoch, "Not time to vest yet");
        unvestedFunds[vesting.userAddress] = unvestedFunds[vesting.userAddress].sub(vesting.amount);
        delete vestings[vestingId];
    }

    function withdraw(
        address destinationAddress,
        uint256 amount
        )
        external
    {
        address userAddress = msg.sender;
        uint256 unvested = unvestedFunds[userAddress];
        uint256 pooled = getPooledFunds(userAddress);
        uint256 nonWithdrawable = unvested > pooled ? unvested: pooled;
        uint256 balance = balances[userAddress];
        uint256 withdrawable = balance.sub(nonWithdrawable);
        require(withdrawable >= amount, "Not enough withdrawable funds");
        balances[userAddress] = balance.sub(amount);
        api3Token.transferFrom(address(this), destinationAddress, amount);
    }

    function pool(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 poolable = balances[userAddress].sub(getPooledFunds(userAddress));
        require(poolable >= amount, "Not enough poolable funds");
        uint256 poolShare = totalPoolShares.mul(amount).div(totalPoolFunds);
        poolShares[userAddress] = poolShares[userAddress].add(poolShare);
        totalPoolShares = totalPoolShares.add(poolShare);
        totalPoolFunds = totalPoolFunds.add(amount);
    }

    /// If a user has made a request to unpool at epoch t, they can't repeat
    /// their request at t+1 to postpone their unpooling to one epoch later.
    /// Should we allow this?
    function requestToUnpool()
        external
    {
        address userAddress = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unpoolRequestEpochs[userAddress].add(unpoolRequestCooldown) <= currentEpochNumber,
            "Have to wait unpoolRequestCooldown to request a new unpool"
            );
        unpoolRequestEpochs[userAddress] = currentEpochNumber;
    }

    /// This doesn't take unpoolWaitingPeriod changing after the unpool request
    /// into account
    function unpool(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 nextEpochNumber = currentEpochNumber.add(1);
        require(
            unpoolRequestEpochs[userAddress].add(unpoolWaitingPeriod) == currentEpochNumber,
            "Have to unpool unpoolWaitingPeriod epochs after the request"
            );
        uint256 pooled = getPooledFunds(userAddress);
        require(
            pooled >= amount,
            "Not enough unpoolable funds"
        );
        pooled = pooled.sub(amount);
        /// Check if the user has staked in this epoch before unpooling and
        /// reduce their staked amount to their updated pooled amount if so
        uint256 staked = stakesPerEpoch[userAddress][nextEpochNumber];
        if (staked > pooled)
        {
            totalStakesPerEpoch[nextEpochNumber] = totalStakesPerEpoch[nextEpochNumber]
                .sub(staked.sub(pooled));
            stakesPerEpoch[userAddress][nextEpochNumber] = pooled;
        }
        uint256 poolShare = totalPoolShares.mul(amount).div(totalPoolFunds);
        poolShares[userAddress] = poolShares[userAddress].sub(poolShare);
        totalPoolShares = totalPoolShares.sub(poolShare);
        totalPoolFunds = totalPoolFunds.sub(amount);
    }

    // Should we allow anyone to call this on behalf of the user?
    function stake(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 nextEpochNumber = getCurrentEpochNumber().add(1);
        uint256 staked = stakesPerEpoch[userAddress][nextEpochNumber];
        uint256 stakeable = getPooledFunds(userAddress).sub(staked);
        require(stakeable >= amount, "Not enough stakeable funds");
        stakesPerEpoch[userAddress][nextEpochNumber] = staked.add(amount);
        totalStakesPerEpoch[nextEpochNumber] = totalStakesPerEpoch[nextEpochNumber].add(amount);
    }

    function collect()
        external
    {
        address userAddress = msg.sender;
        uint256 previousEpochNumber = getCurrentEpochNumber().sub(1);
        uint256 totalStakesInPreviousEpoch = totalStakesPerEpoch[previousEpochNumber];
        uint256 stakeInPreviousEpoch = stakesPerEpoch[userAddress][previousEpochNumber];

        uint256 vestedRewards = vestedRewardsPerEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(vestedRewards);
        unvestedFunds[userAddress] = unvestedFunds[userAddress].add(vestedRewards);
        bytes32 vestingId = keccak256(abi.encodePacked(
                noVestings,
                this
                ));
            noVestings = noVestings.add(1);
            vestings[vestingId] = Vesting({
                userAddress: userAddress,
                amount: vestedRewards,
                epoch: previousEpochNumber.add(1).add(rewardVestingPeriod)
            });
        
        uint256 rewards = rewardsPerEpoch[previousEpochNumber]
            .mul(totalStakesInPreviousEpoch)
            .div(stakeInPreviousEpoch);
        balances[userAddress] = balances[userAddress].add(rewards);
    }

    function getPooledFunds(address userAddress)
        internal
        view
        returns(uint256 pooled)
    {
        pooled = totalPoolShares.mul(totalPoolFunds).div(poolShares[userAddress]);
    }
}
