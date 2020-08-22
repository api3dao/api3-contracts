//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IApi3Pool {
    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external;
}
