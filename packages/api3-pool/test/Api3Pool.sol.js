const { expect } = require("chai");
const { deployer } = require("@api3-contracts/helpers");

describe("Api3Pool", function () {
  let api3Token;
  let api3Pool;
  let roles;
  let epochPeriodInSeconds = 60 * 24 * 7; // week-long epochs
  let firstEpochStartTimestamp = Math.floor(Date.now() / 1000); // first epoch starts right away

  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    roles = {
      owner: accounts[0],
      inflationManager: accounts[1],
      claimsManager: accounts[2],
      randomPerson: accounts[9],
    };
    api3Token = await deployer.deployToken(roles.owner, roles.owner._address);
    api3Pool = await deployer.deployPool(
      roles.owner,
      api3Token.address,
      epochPeriodInSeconds,
      firstEpochStartTimestamp
    );
  });

  it("Deploys with the correct values", async function () {
    expect(await api3Pool.api3Token()).to.equal(api3Token.address);
    expect(await api3Pool.inflationManager()).to.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(await api3Pool.claimsManager()).to.equal(
      "0x0000000000000000000000000000000000000000"
    );

    expect(await api3Pool.epochPeriodInSeconds()).to.equal(
      epochPeriodInSeconds
    );
    expect(await api3Pool.firstEpochStartTimestamp()).to.equal(
      firstEpochStartTimestamp
    );

    expect(await api3Pool.totalPooled()).to.equal(1);
    expect(await api3Pool.totalShares()).to.equal(1);

    expect(await api3Pool.unpoolRequestCooldown()).to.equal(0);
    expect(await api3Pool.unpoolWaitingPeriod()).to.equal(0);
    expect(await api3Pool.rewardVestingPeriod()).to.equal(52);

    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(0);
    expect(await api3Pool.totalGhostShares()).to.equal(1);
  });

  it("Owner can update admin paramaters", async function () {
    await expect(
      api3Pool
        .connect(roles.owner)
        .updateInflationManager(roles.inflationManager._address)
    )
      .to.emit(api3Pool, "InflationManagerUpdated")
      .withArgs(roles.inflationManager._address);
    expect(await api3Pool.inflationManager()).to.equal(
      roles.inflationManager._address
    );

    await expect(
      api3Pool
        .connect(roles.owner)
        .updateClaimsManager(roles.claimsManager._address)
    )
      .to.emit(api3Pool, "ClaimsManagerUpdated")
      .withArgs(roles.claimsManager._address);
    expect(await api3Pool.claimsManager()).to.equal(
      roles.claimsManager._address
    );

    await expect(api3Pool.connect(roles.owner).updateRewardVestingPeriod(100))
      .to.emit(api3Pool, "RewardVestingPeriodUpdated")
      .withArgs(100);
    expect(await api3Pool.rewardVestingPeriod()).to.equal(100);

    await expect(api3Pool.connect(roles.owner).updateUnpoolRequestCooldown(4))
      .to.emit(api3Pool, "UnpoolRequestCooldownUpdated")
      .withArgs(4);
    expect(await api3Pool.unpoolRequestCooldown()).to.equal(4);

    await expect(api3Pool.connect(roles.owner).updateUnpoolWaitingPeriod(2))
      .to.emit(api3Pool, "UnpoolWaitingPeriodUpdated")
      .withArgs(2);
    expect(await api3Pool.unpoolWaitingPeriod()).to.equal(2);
  });

  it("Non-owner cannot update admin parameters", async function () {
    await expect(
      api3Pool
        .connect(roles.randomPerson)
        .updateInflationManager(roles.inflationManager._address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      api3Pool
        .connect(roles.randomPerson)
        .updateClaimsManager(roles.claimsManager._address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      api3Pool.connect(roles.randomPerson).updateRewardVestingPeriod(100)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      api3Pool.connect(roles.randomPerson).updateUnpoolWaitingPeriod(2)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
