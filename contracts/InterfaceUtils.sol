//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInterfaceUtils.sol";


contract InterfaceUtils is Ownable, IInterfaceUtils {
    IApi3Token public immutable api3Token;
    address public claimsManager;

    constructor(address api3TokenAddress)
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
        }

    function updateClaimsManager(address claimsManagerAddress)
        external
        override
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
