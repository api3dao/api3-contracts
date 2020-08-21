//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    struct Vesting
    {
        address staker;
        uint256 amount;
        uint256 vestEpoch;
    }
  
    // Staker balances
    mapping(address => uint256) private balances;
    // Funds that are not withdrawable due to not being vested
    mapping(address => uint256) private unvestedFunds;
    uint256 private totalPool;
    // Funds that are pooled to be staked
    uint256 private totalPoolShares;
    mapping(address => uint256) private poolShares;
    // The epoch when the last unpool request has been made
    mapping(address => uint256) private unpoolRequestEpochs;
    // How much a staker has staked for a particular epoch
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
        address source,
        uint256 amount,
        address beneficiary,
        uint256 vestEpoch
        )
        external
    {
        api3Token.transferFrom(source, address(this), amount);
        balances[beneficiary] += amount;
        if (vestEpoch != 0)
        {
            unvestedFunds[beneficiary] += amount;
            bytes32 vestingId = keccak256(abi.encodePacked(
                noVestings++,
                this
                ));
            vestings[vestingId] = Vesting({
                staker: beneficiary,
                amount: amount,
                vestEpoch: vestEpoch
            });
        }
    }

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(currentEpochNumber < vesting.vestEpoch, "Too early to vest");
        unvestedFunds[vesting.staker] -= vesting.amount;
        delete vestings[vestingId];
    }

    function withdraw(
        uint256 amount,
        address destination
        )
        external
    {
        address staker = msg.sender;
        uint256 unvested = unvestedFunds[staker];
        uint256 pooled = getPooledFunds(staker);
        uint256 nonWithdrawable = unvested > pooled ? unvested: pooled;
        uint256 withdrawable = balances[staker] -= nonWithdrawable;
        require(withdrawable >= amount, "Not enough withdrawable funds");
        balances[staker] -= amount;
        api3Token.transferFrom(address(this), destination, amount);
    }

    function pool(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 poolable = balances[staker] - getPooledFunds(staker);
        require(poolable >= amount, "Not enough poolable funds");
        uint256 poolShare = totalPoolShares.mul(amount).div(totalPool);
        poolShares[staker] += poolShare;
        totalPoolShares += poolShare;
        totalPool += amount;
    }

    function requestUnpool()
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unpoolRequestEpochs[staker] + unpoolRequestCooldown < currentEpochNumber,
            "Have to wait unpoolRequestCooldown to request a new unpool"
            );
        unpoolRequestEpochs[staker] = currentEpochNumber;
    }

    // This doesn't take unpoolWaitingPeriod changing after the unpool request into account
    function unpool(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unpoolRequestEpochs[staker] + unpoolWaitingPeriod == currentEpochNumber,
            "Have to unpool unpoolWaitingPeriod epochs after the request"
            );
        uint256 pooled = getPooledFunds(staker);
        require(
            pooled >= amount,
            "Not enough unpoolable funds"
        );
        pooled -= amount;
        // In case the staker stakes and unpools right after
        if (stakesPerEpoch[staker][currentEpochNumber + 1] > pooled)
        {
            stakesPerEpoch[staker][currentEpochNumber + 1] = pooled;
        }
        uint256 poolShare = totalPoolShares.mul(amount).div(totalPool);
        poolShares[staker] -= poolShare;
        totalPoolShares -= poolShare;
        totalPool -= amount;
    }

    function stake(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 stakeable = getPooledFunds(staker) - stakesPerEpoch[staker][currentEpochNumber + 1];
        require(stakeable >= amount, "Not enough stakeable funds");
        stakesPerEpoch[staker][currentEpochNumber + 1] += amount;
    }

    function getPooledFunds(address stakerAddress)
        internal
        view
        returns(uint256 pooledFunds)
    {
        pooledFunds = totalPoolShares.mul(totalPool).div(poolShares[stakerAddress]);
    }
}
