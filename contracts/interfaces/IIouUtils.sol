//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IIouUtils {
    function redeem(bytes32 iouId)
        external;
}
