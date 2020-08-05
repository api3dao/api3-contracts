//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./interfaces/IInflationSchedule.sol";


contract InflationSchedule is IInflationSchedule {
    function getDelta(
        uint256 t0,
        uint256 t1
        )
        external
        view
        override
        returns(uint256 delta)
    {
        require(t1 >= t0, "Must satisfy t1 >= t0");
        // Implement any inflation schedule you want below
        delta = t1 - t0;
    }
}