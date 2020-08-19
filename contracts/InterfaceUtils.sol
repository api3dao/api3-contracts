//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInflationSchedule.sol";

contract InterfaceUtils is Ownable {
    IApi3Token public immutable api3Token;
    IInflationSchedule public inflationSchedule;

    event InflationScheduleUpdated(address inflationScheduleAddress);

    constructor(
        address api3TokenAddress,
        address inflationScheduleAddress
        )
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
            // Assign this contract as minter after deployment
            inflationSchedule = IInflationSchedule(inflationScheduleAddress);
        }

    function updateInflationSchedule(address inflationScheduleAddress)
        external
        onlyOwner
    {
        inflationSchedule = IInflationSchedule(inflationScheduleAddress);
        emit InflationScheduleUpdated(inflationScheduleAddress);
    }
}