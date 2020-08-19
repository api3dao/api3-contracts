//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "./interfaces/IInflationSchedule.sol";


contract InflationSchedule is IInflationSchedule {
    function getDelta(uint256 indEpoch)
        external
        view
        override
        returns(int256 delta) // supports deflation
    {
        delta = int256(100000 - indEpoch * 100); // replace this with the actual schedule
    }
}