//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    struct Vesting
    {
        address staker;
        uint256 amount;
        uint256 vestTimestamp;
    }
  
    mapping(address => uint256) private totalFunds;
    // Includes initial vestings, inflationary rewards and potential insurance
    // claim payments. Can be locked/unlocked and staked/unstaked.
    mapping(address => uint256) private unvestedFunds;
    // Funds locked to be staked. They are exposed to collateral risk even if
    // they are not staked
    mapping(address => uint256) private lockedFunds;
    mapping(address => uint256) private unlockRequestEpochs;
    mapping(address => mapping(uint256 => uint256)) private stakesPerEpoch;
    mapping(bytes32 => Vesting) private vestings;
    uint256 private noVestings;
    // Make these two updateable
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
        // We want this so that stakers don't have unlock requests lined up for each
        // epoch to be able to get out quickly if they need want
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
