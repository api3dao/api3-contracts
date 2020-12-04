//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@api3-contracts/api3-token/contracts/interfaces/IApi3Token.sol";
import "./interfaces/IApi3Pool.sol";


contract InflationPrototype {
    using SafeMath for uint256;

    IApi3Token public immutable api3Token;
    IApi3Pool public immutable api3Pool;

    // Percentages are multiplied by 100
    uint256 public minApr = 250; // 2.5%
    uint256 public maxApr = 7500; // 75%
    uint256 public stakeTarget = 10e6; // 10M API3
    uint256 public updateSteps = 50; // 0.5%

    uint256 public currentApr = 250;
    mapping(uint256 => bool) private mintedInflationaryRewardsAtEpoch;

    constructor(
        address api3TokenAddress,
        address api3PoolAddress
        )
        public
    {
        api3Token = IApi3Token(api3TokenAddress);
        api3Pool = IApi3Pool(api3PoolAddress);
    }
    
    function mintInflationaryRewardsToPool()
        external
    {
        uint256 currentEpochIndex = api3Pool.getCurrentEpochIndex();
        require(!mintedInflationaryRewardsAtEpoch[currentEpochIndex], "Already minted");
        mintedInflationaryRewardsAtEpoch[currentEpochIndex] = true;

        uint256 currentPooled = api3Pool.getTotalRealPooled();
        if (currentPooled < stakeTarget)
        {
            currentApr = currentApr.add(updateSteps);
            if (currentApr > maxApr)
            {
                currentApr = maxApr;
            }
        }
        else
        {
            currentApr = currentApr.sub(updateSteps);
            if (currentApr < minApr)
            {
                currentApr = minApr;
            }
        }
        uint256 amount = api3Token.totalSupply().mul(currentApr).div(520000);
        api3Token.mint(address(this), amount);
        api3Token.approve(address(api3Pool), amount);
        api3Pool.addVestedRewards(address(this), amount);
    }
}
