//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IPoolUtils {
    function pool(uint256 amount)
        external;

    function requestToUnpool()
        external;

    function unpool(uint256 amount)
        external;
}
