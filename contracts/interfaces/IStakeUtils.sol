//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IStakeUtils {
    event Staked(
        address indexed userAddress,
        uint256 amountInShares
        );

    event Collected(
        address indexed userAddress,
        uint256 vestedRewards,
        uint256 instantRewards
        );

    function stake(address userAddress)
        external;

    function collect(address userAddress)
        external;
}
