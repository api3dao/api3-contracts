//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInflationSchedule.sol";


contract Api3Pool is Ownable {
    IApi3Token public api3Token;
    IInflationSchedule public inflationSchedule;

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
}
