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
  
    // User balances
    mapping(address => uint256) private balances;
    // Funds that are not withdrawable due to not being vested
    mapping(address => uint256) private unvestedFunds;
    uint256 private totalPoolFunds;
    // Funds that are pooled to be staked
    uint256 private totalPoolShares;
    mapping(address => uint256) private poolShares;
    // The epoch when the last unpool request has been made
    mapping(address => uint256) private unpoolRequestEpochs;
    // The shares that users have staked for epochs
    mapping(address => mapping(uint256 => uint256)) private stakesPerEpoch;
    mapping(bytes32 => Vesting) private vestings;
    uint256 private noVestings;

    // TODO: Make these two updateable
    uint256 private unpoolRequestCooldown = 4; // in epochs
    uint256 private unpoolWaitingPeriod = 2; // in epochs

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
        require(getCurrentEpochNumber() < vesting.epoch, "Too early to vest");
        unvestedFunds[vesting.userAddress] = unvestedFunds[vesting.userAddress].sub(vesting.amount);
        delete vestings[vestingId];
    }

    function withdraw(
        uint256 amount,
        address destinationAddress
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

    function requestUnpool()
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

    // This doesn't take unpoolWaitingPeriod changing after the unpool request into account
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
        // In case the user stakes and unpools right after
        if (stakesPerEpoch[userAddress][nextEpochNumber] > pooled)
        {
            stakesPerEpoch[userAddress][nextEpochNumber] = pooled;
        }
        uint256 poolShare = totalPoolShares.mul(amount).div(totalPoolFunds);
        poolShares[userAddress] = poolShares[userAddress].sub(poolShare);
        totalPoolShares = totalPoolShares.sub(poolShare);
        totalPoolFunds = totalPoolFunds.sub(amount);
    }

    // Allow anyone to call this on behalf of the user?
    function stake(uint256 amount)
        external
    {
        address userAddress = msg.sender;
        uint256 nextEpochNumber = getCurrentEpochNumber().add(1);
        uint256 currentStaked = stakesPerEpoch[userAddress][nextEpochNumber];
        uint256 stakeable = getPooledFunds(userAddress).sub(currentStaked);
        require(stakeable >= amount, "Not enough stakeable funds");
        stakesPerEpoch[userAddress][nextEpochNumber] = currentStaked.add(amount);
    }

    function getPooledFunds(address userAddress)
        internal
        view
        returns(uint256 pooledFunds)
    {
        pooledFunds = totalPoolShares.mul(totalPoolFunds).div(poolShares[userAddress]);
    }
}
