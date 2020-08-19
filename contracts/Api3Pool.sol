//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./InterfaceUtils.sol";
import "./EpochUtils.sol";


contract Api3Pool is InterfaceUtils, EpochUtils {
    // Total balances (staked, non-staked, vested, non-vested, etc.)
    mapping(address => uint256) internal balances;

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
        address beneficiary
        )
        external
    {
        api3Token.transferFrom(source, address(this), amount);
        balances[beneficiary] += amount;
    }
}
