//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IEpochUtils {
    function getCurrentEpochNumber()
        external
        view
        returns(uint256 currentEpochNumber);

    function getEpochNumber(uint256 timestamp)
        external
        view
        returns(uint256 epochNumber);
}
