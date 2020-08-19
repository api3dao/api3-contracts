//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    struct Vesting
    {
        address staker;
        uint256 amount;
        uint256 unlockTimestamp;
    }
  
    mapping(address => uint256) private balances;
    mapping(address => uint256) private nonVestedBalances;
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
        uint256 unlockTimestamp
        )
        external
    {
        api3Token.transferFrom(source, address(this), amount);
        balances[beneficiary] += amount;
        if (unlockTimestamp != 0)
        {
            nonVestedBalances[beneficiary] += amount;
            bytes32 vestingId = keccak256(abi.encodePacked(
                noVestings++,
                this
                ));
            vestings[vestingId] = Vesting({
                staker: beneficiary,
                amount: amount,
                unlockTimestamp: unlockTimestamp
            });
        }
    }
}
