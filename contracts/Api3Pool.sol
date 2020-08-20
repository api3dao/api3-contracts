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
    mapping(address => mapping(uint256 => uint256)) private epochStakes;
    mapping(bytes32 => Vesting) private vestings;
    uint256 private noVestings;

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

    function stake(uint256 amount)
        external
    {
        address staker = msg.sender;
        uint256 currentEpochNumber = getCurrentEpochNumber();
        uint256 stakeable = lockedFunds[staker] - epochStakes[staker][currentEpochNumber + 1];
        require(stakeable >= amount, "Not enough stakeable funds");
        epochStakes[staker][currentEpochNumber + 1] = lockedFunds[staker];
    }
}
