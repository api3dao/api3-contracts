//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IInflationSchedule {
    function getDelta(
        uint256 t0,
        uint256 t1
        )
        external
        view
        returns(uint256 delta);
}