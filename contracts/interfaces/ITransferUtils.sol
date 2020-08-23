//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface ITransferUtils {
    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external;
}
