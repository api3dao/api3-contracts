//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";

/// ~~~Terminology~~~
/// Staker: All users are referred to as stakers, even if they don't have
/// actively staked funds.
/// Epoch: The period that is used to quantize time. The default value of an
/// epoch is a week. This means that stakers need to renew their stakes each
/// week with a transaction.
/// Pool: Refers to the collateral pool, and putting funds into it.

/// The staker has to do the following to stake:
/// 1- Call deposit() to deposit funds to the contract. Doing so does not
/// provide any rewards, nor does it expose the staker to collateral risk.
/// 2- Call pool() to pool funds. Doing so does not provide any rewards, yet
/// it exposes the staker to collateral risk.
/// 3- Call stake() to stake pooled funds every epoch/week. Doing so provides
/// staking rewards and governance rights in the next epoch/week.
/// Therefore, if a staker has any pooled funds, it is in their best interest
/// to stake them.

/// The staker has to do the following to withdraw:
/// 1- Call requestUnpool() to request to unpool funds (no need to specify the
/// amount beforehand) unpoolWaitingPeriod (default=2) epochs later. This
/// limit is to prevent stakers from front-running insurance claims (i.e.,
/// withdraw as soon as there is a possibility for a claim to be made). Note that
/// this request can only be done every unpoolRequestCooldown (default=4) epochs to
/// prevent stakers from having an active unpool request at all times (which
/// would allow them to withdraw anytime and defeat the whole purpose).
/// 2- Exactly unpoolWaitingPeriod epochs after the unpool request, call
/// unpool() with the amount they want to unpool.
/// 3- Call withdraw() any time they want.

/// ~~~Vesting~~~
/// A staker cannot withdraw a vesting before it is released, but can do
/// everything else with it, including pooling and staking. For now, there are
/// two scenarios that use vesting:
/// 1- Partners, investors, etc. receive tokens that will be vested after a time
/// period
/// 2- Staking rewards are vested after a time period

/// ~~~IOU~~~
/// A staker cannot withdraw/pool/stake an IOU. It's main use is to allow stakers 
/// to pool/unpool funds while there is an active claim. See the two cases below:
/// 1- There is a total of 1000 API3 pooled, of which 100 belongs to a staker.
/// An insurance claim for 500 API3 is made. If the staker wants to unpool tokens,
/// 50 of those tokens will be put into an IOU. The funds in the IOU can be
/// released by the staker later through a transaction if the claim has been denied.
/// (the staker cannot stake their 50 tokens kept in the IOU during the claims
/// process which results in a slight loss for them)
/// 2- There is a total of 1000 API3 pooled and an insurance claim for 500
/// API3 is made. A staker pools 1000 API3 tokens after the claim is made. If the
/// claim is paid out, this staker will lose 250 tokens, which we don't want. To
/// prevent this, we allow them to pool their 1000 API tokens, but also give
/// them a 250 token IOU that can be redeemed if the claim has been confirmed.
/// Note that in the second case, the IOU can't be in an absolute value (e.g.
/// 250 tokens) because how much the staker will (undeservedly) lose will also
/// depend on additional stakers pooling tokens after them. Therefore, it
/// should be in the form of "refund this staker for their loss from claim ID:X".

/// We don't keep the vestings/IOUs of a staker in an array because handling
/// that is too gas heavy. Instead, the staker needs to keep track of these
/// through past events and refer to specific IDs to release them when
/// they have matured. But this may be a problem to implement wrappers such as
/// xToken.

/// ~~~Pool shares~~~
/// We don't keep absolute pooled values, but rather shares. This way, a claim can
/// be paid out from totalPool without updating per-user variables, the token
/// equivalence of shares decrease automatically.


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
