const { expect } = require("chai");
const { deployer } = require("@api3-contracts/helpers");

describe("EpochUtils", function () {
  let api3Pool;
  let roles;
  let epochPeriodInSeconds = 60 * 24 * 7; // week-long epochs
  let firstEpochStartTimestamp = Math.floor(Date.now() / 1000); // first epoch starts right away

  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    roles = {
      owner: accounts[0],
    };
    const api3Token = await deployer.deployToken(
      roles.owner,
      roles.owner._address,
      roles.owner._address
    );
    api3Pool = await deployer.deployPool(
      roles.owner,
      api3Token.address,
      epochPeriodInSeconds,
      firstEpochStartTimestamp
    );
  });

  it("Returns correct epoch indices", async function () {
    expect(
      await api3Pool.getEpochIndex(firstEpochStartTimestamp - 100)
    ).to.equal(0);

    expect(await api3Pool.getEpochIndex(firstEpochStartTimestamp - 1)).to.equal(
      0
    );

    expect(await api3Pool.getEpochIndex(firstEpochStartTimestamp)).to.equal(1);

    expect(
      await api3Pool.getEpochIndex(
        firstEpochStartTimestamp + Math.floor(epochPeriodInSeconds * 100.5)
      )
    ).to.equal(101);
  });

  it("Returns correct current epoch index", async function () {
    expect(
      await api3Pool.getEpochIndex(Math.floor(Date.now() / 1000))
    ).to.equal(await api3Pool.getCurrentEpochIndex());
  });
});
