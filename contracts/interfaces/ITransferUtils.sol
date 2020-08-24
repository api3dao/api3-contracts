//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface ITransferUtils {
    function deposit(
        address sourceAddress,
        uint256 amount,
        address userAddress
        )
        external;

    function depositWithVesting(
        address sourceAddress,
        uint256 amount,
        address userAddress,
        uint256 vestingEpoch
        )
        external;

    function withdraw(
        address destinationAddress,
        uint256 amount
        )
        external;

    function addVestedRewards(
        address sourceAddress,
        uint256 amount
        )
        external;

    function addInstantRewards(
        address sourceAddress,
        uint256 amount
        )
        external;
}
