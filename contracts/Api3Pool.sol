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
    mapping(address => uint256) private lockedBalances;
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
            lockedBalances[beneficiary] += amount;
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

    function vest(bytes32 vestingId)
        external
    {
        Vesting memory vesting = vestings[vestingId];
        require(vesting.unlockTimestamp < now, "Too early to vest");
        lockedBalances[vesting.staker] -= vesting.amount;
        delete vestings[vestingId];
    }

    function withdraw(
        address staker,
        uint256 amount,
        address destination
        )
        external
    {
        uint256 withdrawable = balances[staker] - lockedBalances[staker];
        require(withdrawable >= amount, "Not enough withdrawable funds");
        balances[staker] -= amount;
        api3Token.transferFrom(address(this), destination, amount);
    }
}
