//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";

/// Terminology
/// Staker: All users are referred to as stakers, even if they don't have
/// actively staked funds.
/// Epoch: The period that is used to quantize time. The default value of an
/// epoch is a week. This means that stakers need to renew their stakes each
/// week with a transaction.

/// The staker has to do the following to stake:
/// 1- Call deposit() to deposit funds to the contract. Doing so does not
/// provide any rewards, nor does it expose the staker to collateral risk.
/// 2- Call lock() to lock funds. Doing so does not provide any rewards, yet
/// it exposes the staker to collateral risk.
/// 3- Call stake() to stake locked funds every epoch/week. Doing so provides
/// staking rewards and governance rights in the next epoch/week.
/// Therefore, if a staker has any locked funds, it is in their best interest
/// to stake them.

/// The staker has to do the following to withdraw:
/// 1- Call requestUnlock() to request to unlock funds (no need to specify the
/// amount beforehand) unlockWaitingPeriod (default=2) epochs later. This
/// limit is to prevent stakers from front-running insurance claims (i.e.,
/// withdraw as soon as there is a possibility for a claim to be made). Note that
/// this request can only be done every unlockRequestCooldown (default=4) epochs to
/// prevent stakers from having an active unlock request at all times (which
/// would allow them to withdraw anytime and defeat the whole purpose).
/// 2- Exactly unlockWaitingPeriod epochs after the unlock request, call
/// unlock() with the amount they want to unlock.
/// 3- Call withdraw() any time they want.

/// ~~~Vesting~~~
/// A staker cannot withdraw a vesting before it is released, but can do
/// everything else with it, including locking and staking. For now, there are
/// two scenarios that use vesting:
/// 1- Partners, investors, etc. receive tokens that will be vested after a time
/// period
/// 2- Staking rewards are vested after a time period

/// ~~~IOU~~~
/// A staker cannot withdraw/lock/stake an IOU. It's main use is to allow stakers 
/// to lock/unlock funds while there is an active claim. See the two cases below:
/// 1- There is a total of 1000 API3 locked, of which 100 belongs to a user.
/// An insurance claim for 500 API3 is made. If the user wants to unlock tokens,
/// 50 of those tokens will be put into an IOU. The funds in the IOU can be
/// released by the staker later through a transaction if the claim has been denied.
/// 2- There is a total of 1000 API3 locked and an insurance claim for 500
/// API3 is made. A user locks 1000 API3 tokens after the claim is made. If the
/// claim is paid out, this user will lose 250 tokens, which we don't want. To
/// prevent this, we allow them to lock their 1000 API tokens, but also give
/// them a 250 token IOU that can be redeemed if the claim has been confirmed.
/// Redeemed IOU's simply get added to the user's totalFunds.

/// We don't keep the vestings/IOUs of a staker in an array because handling
/// that is too gas heavy. Instead, the staker needs to keep track of these
/// through past events and refer to specific IDs to release them when
/// they have matured. But this may be a problem to implement wrappers such as
/// xToken.


contract Api3Pool is InterfaceUtils, EpochUtils {
    struct Vesting
    {
        address staker;
        uint256 amount;
        uint256 vestTimestamp;
    }
  
    // Total funds per staker
    mapping(address => uint256) private totalFunds;
    // Funds that are not withdrawable due to not being vested
    mapping(address => uint256) private unvestedFunds;
    // Funds that are locked to be staked
    mapping(address => uint256) private lockedFunds;
    // The epoch when the last unlock request has been made
    mapping(address => uint256) private unlockRequestEpochs;
    // How much a staker has staked for a particular epoch
    mapping(address => mapping(uint256 => uint256)) private stakesPerEpoch;
    mapping(bytes32 => Vesting) private vestings;
    uint256 private noVestings;
    // TODO: Make these two updateable
    uint256 private unlockRequestCooldown = 4; // in epochs
    uint256 private unlockWaitingPeriod = 2; // in epochs

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
    
    // Should vesting be in timestamps or epochs?
    function deposit(
        address source,
        uint256 amount,
        address beneficiary,
        uint256 vestTimestamp
        )
        external
    {
        api3Token.transferFrom(source, address(this), amount);
        totalFunds[beneficiary] += amount;
        if (vestTimestamp != 0)
        {
            unvestedFunds[beneficiary] += amount;
            bytes32 vestingId = keccak256(abi.encodePacked(
                noVestings++,
                this
                ));
            vestings[vestingId] = Vesting({
                staker: beneficiary,
                amount: amount,
                vestTimestamp: vestTimestamp
            });
        }
    }

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        require(vesting.vestTimestamp < now, "Too early to vest");
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
        uint256 locked = lockedFunds[staker];
        uint256 nonWithdrawable = unvested > locked ? unvested: locked;
        uint256 withdrawable = totalFunds[staker] -= nonWithdrawable;
        require(withdrawable >= amount, "Not enough withdrawable funds");
        totalFunds[staker] -= amount;
        api3Token.transferFrom(address(this), destination, amount);
    }

    function lock(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 lockable = totalFunds[staker] - lockedFunds[staker];
        require(lockable >= amount, "Not enough lockable funds");
        lockedFunds[staker] += amount;
    }

    function requestUnlock()
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unlockRequestEpochs[staker] + unlockRequestCooldown < currentEpochNumber,
            "Have to wait unlockRequestCooldown to request a new unlock"
            );
        unlockRequestEpochs[staker] = currentEpochNumber;
    }

    // This doesn't take unlockWaitingPeriod changing after the unlock request
    function unlock(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        require(
            unlockRequestEpochs[staker] + unlockWaitingPeriod == currentEpochNumber,
            "Have to unlock unlockWaitingPeriod epochs after the request"
            );
        uint256 locked = lockedFunds[staker];
        require(
            locked >= amount,
            "Not enough unlockable funds"
        );
        locked -= amount;
        // In case the staker stakes and unlocks right after
        if (stakesPerEpoch[staker][currentEpochNumber + 1] > locked)
        {
            stakesPerEpoch[staker][currentEpochNumber + 1] = locked;
        }
        lockedFunds[staker] = locked;
    }

    function stake(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 stakeable = lockedFunds[staker] - stakesPerEpoch[staker][currentEpochNumber + 1];
        require(stakeable >= amount, "Not enough stakeable funds");
        stakesPerEpoch[staker][currentEpochNumber + 1] += amount;
    }
}
