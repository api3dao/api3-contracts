//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInflationSchedule.sol";
import "./EpochUtils.sol";


contract Api3Pool is EpochUtils, Ownable {
    IApi3Token public api3Token;
    IInflationSchedule public inflationSchedule;

    // Total balances (staked, non-staked, vested, non-vested, etc.)
    mapping(address => uint256) internal balances;

    constructor(
        address api3TokenAddress,
        address inflationScheduleAddress,
        uint256 epochPeriodInSeconds
        )
        EpochUtils(epochPeriodInSeconds)
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
            // Assign this contract as minter after deployment
            inflationSchedule = IInflationSchedule(inflationScheduleAddress);
        }
    
    function deposit(
        address source,
        uint256 amount,
        address beneficiary
        )
        external
    {
        api3Token.transferFrom(source, address(this), amount);
        stakerBalances[beneficiary] += amount;
    }

    function getStakerBalance(address stakerAddress)
        external
        view
        returns(uint256 stakerBalance)
    {
        stakerBalance = stakerBalances[stakerAddress];
    }
}
