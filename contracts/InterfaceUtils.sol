//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";

contract InterfaceUtils is Ownable {
    IApi3Token public immutable api3Token;
    address public claimsManager;

    event ClaimsManagerUpdated(address claimsManager);

    constructor(address api3TokenAddress)
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
        }

    function updateClaimsInterface(address claimsManagerAddress)
        external
        onlyOwner
    {
        claimsManager = claimsManagerAddress;
        emit ClaimsManagerUpdated(claimsManager);
    }

    modifier onlyClaimsManager()
    {
        require(msg.sender == claimsManager, "Not authorized to manage claims processes");
        _;
    }
}
