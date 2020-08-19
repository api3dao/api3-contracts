//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IInflationSchedule {
    function getDeltaTokenSupply(uint256 currentEpoch)
        external
        view
        returns(uint256 deltaTokenSupply);
}