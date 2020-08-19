//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IInflationSchedule {
    function getDelta(uint256 indEpoch)
        external
        view
        returns(int256 delta);
}