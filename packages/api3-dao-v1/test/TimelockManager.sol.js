const { expect } = require("chai");
const { deployer, utils } = require("@api3-contracts/helpers");

let api3Token;
let timelockManager;
let api3Pool;
let roles;
let timelocks;

async function batchDeployTimelocks() {
  await api3Token.connect(roles.dao).approve(
    timelockManager.address,
    timelocks.reduce(
      (acc, timelock) => acc.add(timelock.amount),
      ethers.BigNumber.from(0)
    )
  );
  let tx = await timelockManager.connect(roles.dao).transferAndLockMultiple(
    roles.dao._address,
    timelocks.map((timelock) => timelock.owner),
    timelocks.map((timelock) => timelock.amount),
    timelocks.map((timelock) => timelock.releaseTime)
  );
  for (const timelock of timelocks) {
    await utils.verifyLog(
      timelockManager,
      tx,
      "TransferredAndLocked(uint256,address,address,uint256,uint256)",
      {
        source: roles.dao._address,
        owner: timelock.owner,
        amount: timelock.amount,
        releaseTime: timelock.releaseTime,
      }
    );
  }
}

async function verifyDeployedTimelocks() {
  const retrievedTimelocks = await timelockManager.getTimelocks();
  expect(retrievedTimelocks.owners.length).to.equal(timelocks.length);
  expect(retrievedTimelocks.amounts.length).to.equal(timelocks.length);
  expect(retrievedTimelocks.releaseTimes.length).to.equal(timelocks.length);
  for (const timelock of timelocks) {
    const indTimelock = retrievedTimelocks.owners.findIndex(
      (owner, ind) =>
        owner == timelock.owner &&
        retrievedTimelocks.amounts[ind].eq(timelock.amount) &&
        retrievedTimelocks.releaseTimes[ind].eq(timelock.releaseTime)
    );
    expect(indTimelock).to.not.equal(-1);
    const individuallyRetrievedTimelock = await timelockManager.getTimelock(
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
      releaseTime: ethers.BigNumber.from(currentTimestamp + 10000),
    },
    {
      owner: roles.owner2._address,
      amount: ethers.utils.parseEther((8e2).toString()),
      releaseTime: ethers.BigNumber.from(currentTimestamp + 20000),
    },
    {
      owner: roles.owner1._address,
      amount: ethers.utils.parseEther((5e2).toString()),
      releaseTime: ethers.BigNumber.from(currentTimestamp + 40000),
    },
  ];
  ({ api3Token, timelockManager, api3Pool } = await deployer.deployAll(
    roles.deployer,
    roles.dao._address
  ));
});

describe("constructor", function () {
  it("Token address, pool address and ownership are set correctly at deployment", async function () {
    expect(await timelockManager.api3Token()).to.equal(api3Token.address);
    expect(await timelockManager.owner()).to.equal(roles.dao._address);
    expect(await timelockManager.api3Pool()).to.equal(
      ethers.constants.AddressZero
    );
  });
});

describe("updateApi3Pool", function () {
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
});

describe("transferAndLock", function () {
  it("DAO can transfer and lock tokens individually", async function () {
    await api3Token.connect(roles.dao).approve(
      timelockManager.address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
    );
    for (const timelock of timelocks) {
      let tx = await timelockManager
        .connect(roles.dao)
        .transferAndLock(
          roles.dao._address,
          timelock.owner,
          timelock.amount,
          timelock.releaseTime
        );
      await utils.verifyLog(
        timelockManager,
        tx,
        "TransferredAndLocked(uint256,address,address,uint256,uint256)",
        {
          source: roles.dao._address,
          owner: timelock.owner,
          amount: timelock.amount,
          releaseTime: timelock.releaseTime,
        }
      );
    }
    await verifyDeployedTimelocks();
  });

  it("Non-DAO accounts cannot transfer and lock tokens individually", async function () {
    await api3Token.connect(roles.dao).transfer(
      roles.randomPerson._address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
    );
    await api3Token.connect(roles.randomPerson).approve(
      timelockManager.address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
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
});

describe("transferAndLockMultiple", function () {
  it("DAO can batch transfer and lock tokens", async function () {
    await batchDeployTimelocks();
    await verifyDeployedTimelocks();
  });

  it("Non-DAO accounts cannot batch transfer and lock tokens", async function () {
    await api3Token.connect(roles.dao).transfer(
      roles.randomPerson._address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
    );
    await api3Token.connect(roles.randomPerson).approve(
      timelockManager.address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
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
    await api3Token.connect(roles.dao).approve(
      timelockManager.address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
    );
    await expect(
      timelockManager.connect(roles.dao).transferAndLockMultiple(
        roles.dao._address,
        [timelocks[0].owner],
        timelocks.map((timelock) => timelock.amount),
        timelocks.map((timelock) => timelock.releaseTime)
      )
    ).to.be.revertedWith("Lengths of parameters do not match");
  });

  it("Batch transfer and lock rejects parameters longer than 36", async function () {
    await api3Token.connect(roles.dao).approve(
      timelockManager.address,
      timelocks.reduce(
        (acc, timelock) => acc.add(timelock.amount),
        ethers.BigNumber.from(0)
      )
    );
    await expect(
      timelockManager
        .connect(roles.dao)
        .transferAndLockMultiple(
          roles.dao._address,
          Array(37).fill(timelocks[0].owner),
          Array(37).fill(timelocks[0].amount),
          Array(37).fill(timelocks[0].releaseTime)
        )
    ).to.be.revertedWith("Parameters are longer than 36");
  });
});

describe("withdraw", function () {
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

    const individuallyRetrievedTimelock = await timelockManager.getTimelock(
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
});

describe("withdrawToPool", function () {
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

    const individuallyRetrievedTimelock = await timelockManager.getTimelock(
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
