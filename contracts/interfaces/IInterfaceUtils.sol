//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;


interface IInterfaceUtils {
    event ClaimsManagerUpdated(address claimsManager);

    function updateClaimsManager(address claimsManagerAddress)
        external;
}
