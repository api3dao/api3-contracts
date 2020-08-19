//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IApi3Token.sol";
import "./interfaces/IInflationSchedule.sol";


contract Api3Pool is Ownable {
    IApi3Token public api3Token;
    IInflationSchedule public inflationSchedule;

    mapping(address=>uint256) private reps;
    uint256 public totalRep = 1;
    uint256 public lastRewardUpdate;

    constructor(
        address api3TokenAddress,
        address inflationScheduleAddress
        )
        public
        {
            api3Token = IApi3Token(api3TokenAddress);
            inflationSchedule = IInflationSchedule(inflationScheduleAddress);
            // Seed the contract with 1 API3 token after deploying it
            // Assign it as minter
        }

    function startRewards()
        external
        onlyOwner
    {
        lastRewardUpdate = block.timestamp;
    }

    modifier mintRewards()
    {
        if (lastRewardUpdate != 0)
        {
            uint256 delta = inflationSchedule.getDelta(lastRewardUpdate, block.timestamp);
            api3Token.mint(address(this), delta);
            lastRewardUpdate = block.timestamp;
        }
        _;
    }

    function mintRep(
        address api3Sender,
        address repRecipient,
        uint256 api3Amount
        )
        external
        mintRewards
    {
        // api3Sender has to approve first
        api3Token.transferFrom(api3Sender, address(this), api3Amount);
        uint256 balance = api3Token.balanceOf(address(this));
        if (balance == 0)
        {
            balance = 1;
        }
        uint256 repAmount = api3Amount * totalRep / balance;
        reps[repRecipient] += repAmount;
        totalRep += repAmount;
    }

    function burnRep(
        address repOwner,
        address api3Recipient,
        uint256 repAmount
        )
        external
        mintRewards
    {
        uint256 api3Amount = repAmount * api3Token.balanceOf(address(this)) / totalRep;
        api3Token.transferFrom(address(this), api3Recipient, api3Amount);
        reps[repOwner] -= repAmount;
        totalRep -= repAmount;
    }
}
