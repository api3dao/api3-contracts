//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IGetterUtils {
    function getVotingPower(
        address userAddress,
        uint256 timestamp
        )
        external
        view
        returns(uint256 votingPower);
}
