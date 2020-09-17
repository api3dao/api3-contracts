const { expect } = require("chai");
const { deployer, utils } = require("@api3-contracts/helpers");

describe("TimelockManager", function () {
  let api3Token;
  let timelockManager;
  let api3Pool;
  let roles;
  let timelocks;

  async function batchDeployTimelocks() {
    await api3Token
      .connect(roles.dao)
      .approve(
        timelockManager.address,
        ethers.utils.parseEther((1e3).toString())
      );
    await timelockManager.connect(roles.dao).transferAndLockMultiple(
      roles.dao._address,
      timelocks.map((timelock) => timelock.owner),
      timelocks.map((timelock) => timelock.amount),
      timelocks.map((timelock) => timelock.releaseTime)
    );
  }

  async function verifyDeployedTimelocks() {
    const retrievedTimelocks = await timelockManager.getTimelocks();
    expect(retrievedTimelocks.owners.length).to.equal(timelocks.length);
    expect(retrievedTimelocks.amounts.length).to.equal(timelocks.length);
    expect(retrievedTimelocks.releaseTimes.length).to.equal(timelocks.length);
    for (const timelock of timelocks) {
      const indTimelock = retrievedTimelocks.owners.findIndex(
        (owner) => owner == timelock.owner
      );
      expect(retrievedTimelocks.owners[indTimelock]).to.equal(timelock.owner);
      expect(retrievedTimelocks.amounts[indTimelock]).to.equal(timelock.amount);
      expect(retrievedTimelocks.releaseTimes[indTimelock]).to.equal(
        timelock.releaseTime
      );
      const individuallyRetrievedTimelock = await timelockManager.timelocks(
        indTimelock
      );
      expect(individuallyRetrievedTimelock.owner).to.equal(timelock.owner);
      expect(individuallyRetrievedTimelock.amount).to.equal(timelock.amount);
      expect(individuallyRetrievedTimelock.releaseTime).to.equal(
        timelock.releaseTime
      );
    }
  }

  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    roles = {
      deployer: accounts[0],
      dao: accounts[1],
      owner1: accounts[2],
      owner2: accounts[3],
      randomPerson: accounts[9],
    };
    const currentTimestamp = parseInt(
      (await ethers.provider.send("eth_getBlockByNumber", ["latest", false]))
        .timestamp
    );
    timelocks = [
      {
        owner: roles.owner1._address,
        amount: ethers.utils.parseEther((2e2).toString()),
        releaseTime: currentTimestamp + 10000,
      },
      {
        owner: roles.owner2._address,
        amount: ethers.utils.parseEther((8e2).toString()),
        releaseTime: currentTimestamp + 20000,
      },
    ];
    ({ api3Token, timelockManager, api3Pool } = await deployer.deployAll(
      roles.deployer,
      roles.dao._address
    ));
  });

  it("Token address, pool address and ownership are set correctly at deployment", async function () {
    expect(await timelockManager.api3Token()).to.equal(api3Token.address);
    expect(await timelockManager.owner()).to.equal(roles.dao._address);
    expect(await timelockManager.api3Pool()).to.equal(
      ethers.constants.AddressZero
    );
  });

  it("DAO can update the pool address", async function () {
    const newPoolAddress = "0x0000000000000000000000000000000000000001";
    let tx = await timelockManager
      .connect(roles.dao)
      .updateApi3Pool(newPoolAddress);
    await utils.verifyLog(timelockManager, tx, "Api3PoolUpdated(address)", {
      api3PoolAddress: newPoolAddress,
    });
    expect(await timelockManager.api3Pool()).to.equal(newPoolAddress);
  });

  it("Non-DAO accounts cannot update the pool address", async function () {
    const newPoolAddress = "0x0000000000000000000000000000000000000001";
    await expect(
      timelockManager.connect(roles.randomPerson).updateApi3Pool(newPoolAddress)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("DAO can transfer and lock tokens individually", async function () {
    await api3Token
      .connect(roles.dao)
      .approve(
        timelockManager.address,
        ethers.utils.parseEther((1e3).toString())
      );
    for (const timelock of timelocks) {
      await timelockManager
        .connect(roles.dao)
        .transferAndLock(
          roles.dao._address,
          timelock.owner,
          timelock.amount,
          timelock.releaseTime
        );
    }
    await verifyDeployedTimelocks();
  });

  it("DAO can batch transfer and lock tokens", async function () {
    await batchDeployTimelocks();
    await verifyDeployedTimelocks();
  });

  it("Non-DAO accounts cannot transfer and lock tokens individually", async function () {
    await api3Token
      .connect(roles.dao)
      .transfer(
        roles.randomPerson._address,
        ethers.utils.parseEther((1e3).toString())
      );
    await api3Token
      .connect(roles.randomPerson)
      .approve(
        timelockManager.address,
        ethers.utils.parseEther((1e3).toString())
      );
    await expect(
      timelockManager
        .connect(roles.randomPerson)
        .transferAndLock(
          roles.randomPerson._address,
          timelocks[0].owner,
          timelocks[0].amount,
          timelocks[0].releaseTime
        )
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Non-DAO accounts cannot batch transfer and lock tokens", async function () {
    await api3Token
      .connect(roles.dao)
      .transfer(
        roles.randomPerson._address,
        ethers.utils.parseEther((1e3).toString())
      );
    await api3Token
      .connect(roles.randomPerson)
      .approve(
        timelockManager.address,
        ethers.utils.parseEther((1e3).toString())
      );
    await expect(
      timelockManager.connect(roles.randomPerson).transferAndLockMultiple(
        roles.dao._address,
        timelocks.map((timelock) => timelock.owner),
        timelocks.map((timelock) => timelock.amount),
        timelocks.map((timelock) => timelock.releaseTime)
      )
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Batch transfer and lock rejects parameters of unequal length", async function () {
    await api3Token
      .connect(roles.dao)
      .approve(
        timelockManager.address,
        ethers.utils.parseEther((1e3).toString())
      );
    await expect(
      timelockManager.connect(roles.randomPerson).transferAndLockMultiple(
        roles.dao._address,
        [timelocks[0].owner],
        timelocks.map((timelock) => timelock.amount),
        timelocks.map((timelock) => timelock.releaseTime)
      )
    ).to.be.revertedWith("Lengths of parameters do not match");
  });

  it("Owners can withdraw their tokens after releaseTime only", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    let indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      retrievedTimelocks.releaseTimes[indTimelock].toNumber() + 1,
    ]);
    await timelockManager
      .connect(roles.owner1)
      .withdraw(indTimelock, roles.owner1._address);
    expect(await api3Token.balanceOf(roles.owner1._address)).to.equal(
      retrievedTimelocks.amounts[indTimelock]
    );
    indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner2._address
    );
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      retrievedTimelocks.releaseTimes[indTimelock].toNumber() + 1,
    ]);
    await timelockManager
      .connect(roles.owner2)
      .withdraw(indTimelock, roles.owner2._address);
    expect(await api3Token.balanceOf(roles.owner2._address)).to.equal(
      retrievedTimelocks.amounts[indTimelock]
    );
  });

  it("Owner cannot withdraw from the same timelock twice", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    const indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      retrievedTimelocks.releaseTimes[indTimelock].toNumber() + 1,
    ]);
    await timelockManager
      .connect(roles.owner1)
      .withdraw(indTimelock, roles.owner1._address);

    const individuallyRetrievedTimelock = await timelockManager.timelocks(
      indTimelock
    );
    expect(individuallyRetrievedTimelock.owner).to.equal(
      ethers.constants.AddressZero
    );
    expect(individuallyRetrievedTimelock.amount).to.equal(0);
    expect(individuallyRetrievedTimelock.releaseTime).to.equal(0);

    await expect(
      timelockManager
        .connect(roles.owner1)
        .withdraw(indTimelock, roles.owner1._address)
    ).to.be.revertedWith("Only the owner of the timelock can withdraw from it");
  });

  it("Owner cannot withdraw their tokens before releaseTime", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    const indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await expect(
      timelockManager
        .connect(roles.owner1)
        .withdraw(indTimelock, roles.owner1._address)
    ).to.be.revertedWith("Timelock has not matured yet");
  });

  it("Non-owner cannot withdraw tokens after releaseTime", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    const indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      retrievedTimelocks.releaseTimes[indTimelock].toNumber() + 1,
    ]);
    await expect(
      timelockManager
        .connect(roles.randomPerson)
        .withdraw(indTimelock, roles.randomPerson._address)
    ).to.be.revertedWith("Only the owner of the timelock can withdraw from it");
  });

  it("Owner can withdraw their tokens to the pool only once", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    let indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await timelockManager.connect(roles.dao).updateApi3Pool(api3Pool.address);
    let tx = await timelockManager
      .connect(roles.owner1)
      .withdrawToPool(indTimelock, api3Pool.address, roles.owner1._address);
    const vestingEpoch = await api3Pool.getEpochIndex(
      retrievedTimelocks.releaseTimes[indTimelock]
    );
    await utils.verifyLog(
      api3Pool,
      tx,
      "VestingCreated(bytes32,address,uint256,uint256)",
      {
        userAddress: roles.owner1._address,
        amount: retrievedTimelocks.amounts[indTimelock],
        vestingEpoch: vestingEpoch,
      }
    );

    const individuallyRetrievedTimelock = await timelockManager.timelocks(
      indTimelock
    );
    expect(individuallyRetrievedTimelock.owner).to.equal(
      ethers.constants.AddressZero
    );
    expect(individuallyRetrievedTimelock.amount).to.equal(0);
    expect(individuallyRetrievedTimelock.releaseTime).to.equal(0);

    await expect(
      timelockManager
        .connect(roles.owner1)
        .withdrawToPool(indTimelock, api3Pool.address, roles.owner1._address)
    ).to.be.revertedWith("Only the owner of the timelock can withdraw from it");
  });

  it("Owner cannot withdraw their tokens to the pool before it is set by the DAO", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    let indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await expect(
      timelockManager
        .connect(roles.owner1)
        .withdrawToPool(indTimelock, api3Pool.address, roles.owner1._address)
    ).to.be.revertedWith("API3 pool not set yet");
  });

  it("Owner cannot withdraw their tokens to the pool without providing the correct address", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    let indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await timelockManager.connect(roles.dao).updateApi3Pool(api3Pool.address);
    await expect(
      timelockManager
        .connect(roles.owner1)
        .withdrawToPool(
          indTimelock,
          ethers.constants.AddressZero,
          roles.owner1._address
        )
    ).to.be.revertedWith("API3 pool addresses do not match");
  });

  it("Non-owner cannot withdraw tokens to the pool", async function () {
    await batchDeployTimelocks();
    const retrievedTimelocks = await timelockManager.getTimelocks();
    let indTimelock = retrievedTimelocks.owners.findIndex(
      (owner) => owner == roles.owner1._address
    );
    await timelockManager.connect(roles.dao).updateApi3Pool(api3Pool.address);
    await expect(
      timelockManager
        .connect(roles.randomPerson)
        .withdrawToPool(
          indTimelock,
          api3Pool.address,
          roles.randomPerson._address
        )
    ).to.be.revertedWith("Only the owner of the timelock can withdraw from it");
  });
});
