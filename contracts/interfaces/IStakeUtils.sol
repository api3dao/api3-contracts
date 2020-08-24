//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IStakeUtils {
    function stake(address userAddress)
        external;

    function collect(address userAddress)
        external;
}
