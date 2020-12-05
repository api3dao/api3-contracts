//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@api3-contracts/api3-token/contracts/interfaces/IApi3Token.sol";
import "./interfaces/IApi3Pool.sol";


contract InflationPrototype {
    using SafeMath for uint256;

    IApi3Token public immutable api3Token;
    IApi3Pool public immutable api3Pool;

    // Percentages are multiplied by 1,000,000
    uint256 public minApr = 2500000; // 2.5%
    uint256 public maxApr = 75000000; // 75%
    uint256 public stakeTarget = 10e6; // 10M API3
    // updateCoeff is not in percentages, it's a coefficient that determines
    // how aggresively inflation rate will be updated to meet the target.
    uint256 public updateCoeff = 1000000; 

    uint256 public currentApr = 2500000;
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

    function updateCurrentApr()
        private
    {
        // I am using pooled/staked interchangeably here
        // See https://github.com/api3dao/api3-dao/issues/34
        uint256 currentPooled = api3Pool.getTotalRealPooled();
        uint256 totalSupply = api3Token.totalSupply();

        uint256 deltaAbsolute = currentPooled < stakeTarget 
            ? stakeTarget.sub(currentPooled) : currentPooled.sub(stakeTarget);
        // Percentages are multiplied by 1,000,000
        uint256 deltaPercentage = deltaAbsolute.mul(100000000).div(totalSupply);
        
        // An updateCoeff of 1,000,000 means that for each 1% deviation from the 
        // stake target, APR will be updated by 1%.
        uint256 aprUpdate = deltaPercentage.mul(updateCoeff).div(1000000);

        currentApr = currentPooled < stakeTarget
            ? currentApr.add(aprUpdate) : currentApr.sub(aprUpdate);
    }
    
    function mintInflationaryRewardsToPool()
        external
    {
        uint256 currentEpochIndex = api3Pool.getCurrentEpochIndex();
        require(!mintedInflationaryRewardsAtEpoch[currentEpochIndex], "Already minted");
        mintedInflationaryRewardsAtEpoch[currentEpochIndex] = true;

        updateCurrentApr();

        uint256 amount = api3Token.totalSupply().mul(currentApr).div(5200000000);
        api3Token.mint(address(this), amount);
        api3Token.approve(address(api3Pool), amount);
        api3Pool.addVestedRewards(address(this), amount);
    }
}
