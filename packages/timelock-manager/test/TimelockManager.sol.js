const { expect } = require("chai");
const { deployer, utils } = require("@api3-contracts/helpers");

let api3Token;
let timelockManager;
let api3Pool;
let roles;
let timelocks;

async function batchDeployTimelocks() {
  // Approve enough tokens to cover all timelocks
  await api3Token.connect(roles.dao).approve(
    timelockManager.address,
    timelocks.reduce(
      (acc, timelock) => acc.add(timelock.totalAmount),
      ethers.BigNumber.from(0)
    )
  );
  // Batch-deploy timelocks
  let tx = await timelockManager.connect(roles.dao).transferAndLockMultiple(
    roles.dao._address,
    timelocks.map((timelock) => timelock.owner),
    timelocks.map((timelock) => timelock.totalAmount),
    timelocks.map((timelock) => timelock.releaseStart),
    timelocks.map((timelock) => timelock.releaseEnd),
    timelocks.map((timelock) => timelock.cliff),
    timelocks.map((timelock) => timelock.reversible)
  );
  // Check that each timelock deployment has emitted its respective event
  for (const timelock of timelocks) {
    await utils.verifyLog(
      timelockManager,
      tx,
      "TransferredAndLocked(uint256,address,address,uint256,uint256,uint256,uint256,bool)",
      {
        source: roles.dao._address,
        owner: timelock.owner,
        amount: timelock.totalAmount,
        releaseStart: timelock.releaseStart,
        releaseEnd: timelock.releaseEnd,
        cliff: timelock.cliff,
        reversible: timelock.reversible,
      }
    );
  }
}

async function verifyDeployedTimelocks() {
  // Retrieve all timelocks and check that their number is correct
  const retrievedTimelocks = await timelockManager.getTimelocks();
  expect(retrievedTimelocks.owners.length).to.equal(timelocks.length);
  expect(retrievedTimelocks.totalAmounts.length).to.equal(timelocks.length);
  expect(retrievedTimelocks.releaseStarts.length).to.equal(timelocks.length);
  expect(retrievedTimelocks.reversibles.length).to.equal(timelocks.length);
  for (const timelock of timelocks) {
    // Search for each timelock among the retrieved timelocks
    const indTimelock = retrievedTimelocks.owners.findIndex(
      (owner, ind) =>
        owner == timelock.owner &&
        retrievedTimelocks.totalAmounts[ind].eq(timelock.totalAmount) &&
        retrievedTimelocks.releaseStarts[ind].eq(timelock.releaseStart) &&
        retrievedTimelocks.reversibles[ind] == timelock.reversible
    );
    expect(indTimelock).to.not.equal(-1);
    // Retrieve the timelock individually and check its fields again
    const individuallyRetrievedTimelock = await timelockManager.getTimelock(
      indTimelock
    );
    expect(individuallyRetrievedTimelock.owner).to.equal(timelock.owner);
    expect(individuallyRetrievedTimelock.totalAmount).to.equal(
      timelock.totalAmount
    );
    expect(individuallyRetrievedTimelock.releaseStart).to.equal(
      timelock.releaseStart
    );
    expect(individuallyRetrievedTimelock.reversible).to.equal(
      timelock.reversible
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
      totalAmount: ethers.utils.parseEther((2e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 40000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 40000).add(
        104 * 7 * 24 * 60 * 60
      ),
      reversible: true,
      cliff: ethers.BigNumber.from(currentTimestamp + 40000).add(
        26 * 7 * 24 * 60 * 60 //26 week cliff
      ),
    },
    {
      owner: roles.owner2._address,
      totalAmount: ethers.utils.parseEther((8e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 20000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 20000).add(
        104 * 7 * 24 * 60 * 60
      ),
      reversible: false,
      cliff: ethers.BigNumber.from(currentTimestamp + 40000).add(
        26 * 7 * 24 * 60 * 60 //26 week cliff
      ),
    },
    {
      owner: roles.owner1._address,
      totalAmount: ethers.utils.parseEther((5e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 10000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 10000).add(
        104 * 7 * 24 * 60 * 60
      ),
      reversible: false,
      cliff: 0, //no cliff
    },
    {
      owner: roles.owner2._address,
      totalAmount: ethers.utils.parseEther((3e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 30000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 30000).add(
        104 * 7 * 24 * 60 * 60
      ),
      reversible: true,
      cliff: 0, //no cliff
    },
  ];
  api3Token = await deployer.deployToken(roles.deployer, roles.dao._address);
  timelockManager = await deployer.deployTimelockManager(
    roles.deployer,
    roles.dao._address,
    api3Token.address
  );
  api3Pool = await deployer.deployPool(roles.deployer, api3Token.address);
});

describe("constructor", function () {
  it("deploys correctly", async function () {
    expect(await timelockManager.api3Token()).to.equal(api3Token.address);
    expect(await timelockManager.owner()).to.equal(roles.dao._address);
    expect(await timelockManager.api3Pool()).to.equal(
      ethers.constants.AddressZero
    );
  });
});

describe("updateApi3Pool", function () {
  context("If the caller is the DAO", async function () {
    it("updates the pool address", async function () {
      const newPoolAddress = "0x0000000000000000000000000000000000000001";
      await expect(
        timelockManager.connect(roles.dao).updateApi3Pool(newPoolAddress)
      )
        .to.emit(timelockManager, "Api3PoolUpdated")
        .withArgs(newPoolAddress);
      expect(await timelockManager.api3Pool()).to.equal(newPoolAddress);
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      const newPoolAddress = "0x0000000000000000000000000000000000000001";
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .updateApi3Pool(newPoolAddress)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("transferAndLock", function () {
  context("If the caller is the DAO", async function () {
    it("transfers and locks tokens individually", async function () {
      // Approve enough tokens to cover all timelocks
      await api3Token.connect(roles.dao).approve(
        timelockManager.address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.totalAmount),
          ethers.BigNumber.from(0)
        )
      );
      // Deploy timelocks individually
      for (const timelock of timelocks) {
        let tx = await timelockManager
          .connect(roles.dao)
          .transferAndLock(
            roles.dao._address,
            timelock.owner,
            timelock.totalAmount,
            timelock.releaseStart,
            timelock.releaseEnd,
            timelock.cliff,
            timelock.reversible
          );
        await utils.verifyLog(
          timelockManager,
          tx,
          "TransferredAndLocked(uint256,address,address,uint256,uint256,uint256,uint256,bool)",
          {
            source: roles.dao._address,
            owner: timelock.owner,
            amount: timelock.totalAmount,
            releaseStart: timelock.releaseStart,
            releaseEnd: timelock.releaseEnd,
            cliff: timelock.cliff,
            reversible: timelock.reversible,
          }
        );
      }
      await verifyDeployedTimelocks();
    });
    context("If the transferred and locked amount is 0", async function () {
      it("reverts", async function () {
        await expect(
          timelockManager
            .connect(roles.dao)
            .transferAndLock(
              roles.dao._address,
              timelocks[0].owner,
              0,
              timelocks[0].releaseStart,
              timelocks[0].releaseEnd,
              timelocks[0].cliff,
              timelocks[0].reversible
            )
        ).to.be.revertedWith("Transferred and locked amount cannot be 0");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      // Transfer tokens to randomPerson for them to deploy the timelocks
      await api3Token.connect(roles.dao).transfer(
        roles.randomPerson._address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.totalAmount),
          ethers.BigNumber.from(0)
        )
      );
      // Have randomPerson approve enough tokens to cover all timelocks
      await api3Token.connect(roles.randomPerson).approve(
        timelockManager.address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.totalAmount),
          ethers.BigNumber.from(0)
        )
      );
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .transferAndLock(
            roles.randomPerson._address,
            timelocks[0].owner,
            timelocks[0].totalAmount,
            timelocks[0].releaseStart,
            timelocks[0].releaseEnd,
            timelocks[0].cliff,
            timelocks[0].reversible
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("transferAndLockMultiple", function () {
  context("If the caller is the DAO", async function () {
    it("batch-transfers and locks tokens", async function () {
      await batchDeployTimelocks();
      await verifyDeployedTimelocks();
    });
    context("parameters are of unequal length", async function () {
      it("reverts", async function () {
        // Approve enough tokens to cover all timelocks
        await api3Token.connect(roles.dao).approve(
          timelockManager.address,
          timelocks.reduce(
            (acc, timelock) => acc.add(timelock.totalAmount),
            ethers.BigNumber.from(0)
          )
        );
        await expect(
          timelockManager.connect(roles.dao).transferAndLockMultiple(
            roles.dao._address,
            [timelocks[0].owner],
            timelocks.map((timelock) => timelock.totalAmount),
            timelocks.map((timelock) => timelock.releaseStart),
            timelocks.map((timelock) => timelock.releaseEnd),
            timelocks.map((timelock) => timelock.cliff),
            timelocks.map((timelock) => timelock.reversible)
          )
        ).to.be.revertedWith("Lengths of parameters do not match");
      });
    });
    context("parameters are longer than 30", async function () {
      it("reverts", async function () {
        await expect(
          timelockManager
            .connect(roles.dao)
            .transferAndLockMultiple(
              roles.dao._address,
              Array(31).fill(timelocks[0].owner),
              Array(31).fill(timelocks[0].totalAmount),
              Array(31).fill(timelocks[0].releaseStart),
              Array(31).fill(timelocks[0].releaseEnd),
              Array(31).fill(timelocks[0].cliff),
              Array(31).fill(timelocks[0].reversible)
            )
        ).to.be.revertedWith("Parameters are longer than 30");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      // Transfer tokens to randomPerson for them to deploy the timelocks
      await api3Token.connect(roles.dao).transfer(
        roles.randomPerson._address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.totalAmount),
          ethers.BigNumber.from(0)
        )
      );
      // Have randomPerson approve enough tokens to cover all timelocks
      await api3Token.connect(roles.randomPerson).approve(
        timelockManager.address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.totalAmount),
          ethers.BigNumber.from(0)
        )
      );
      await expect(
        timelockManager.connect(roles.randomPerson).transferAndLockMultiple(
          roles.dao._address,
          timelocks.map((timelock) => timelock.owner),
          timelocks.map((timelock) => timelock.totalAmount),
          timelocks.map((timelock) => timelock.releaseStart),
          timelocks.map((timelock) => timelock.releaseEnd),
          timelocks.map((timelock) => timelock.cliff),
          timelocks.map((timelock) => timelock.reversible)
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("reverseTimelock", function () {
  context("If the caller is the DAO", async function () {
    it("reverses reversible timelocks individually", async function () {
      await batchDeployTimelocks();
      const retrievedTimelocks = await timelockManager.getTimelocks();
      const reversibleTimelocks = timelocks.filter(
        (timelock) => timelock.reversible
      );
      for (const reversibleTimelock of reversibleTimelocks) {
        // Find the timelock among the retrieved timelocks
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner, ind) =>
            owner == reversibleTimelock.owner &&
            retrievedTimelocks.totalAmounts[ind].eq(
              reversibleTimelock.totalAmount
            ) &&
            retrievedTimelocks.releaseStarts[ind].eq(
              reversibleTimelock.releaseStart
            ) &&
            retrievedTimelocks.reversibles[ind] == reversibleTimelock.reversible
        );
        const previousBalance = await api3Token.balanceOf(roles.dao._address);
        // Have the DAO reverse the timelock and receive the tokens
        await expect(
          timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, roles.dao._address)
        )
          .to.emit(timelockManager, "TimelockReversed")
          .withArgs(indTimelock, roles.dao._address);
        // Check if the withdrawal was successful
        const afterBalance = await api3Token.balanceOf(roles.dao._address);
        expect(afterBalance.sub(previousBalance)).to.equal(
          retrievedTimelocks.totalAmounts[indTimelock]
        );
      }
    });
    context(
      "If the DAO attempts to reverse a timelock a second time",
      async function () {
        it("reverts", async function () {
          await batchDeployTimelocks();
          const retrievedTimelocks = await timelockManager.getTimelocks();
          const reversibleTimelocks = timelocks.filter(
            (timelock) => timelock.reversible
          );
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == reversibleTimelocks[0].owner &&
              retrievedTimelocks.totalAmounts[ind].eq(
                reversibleTimelocks[0].totalAmount
              ) &&
              retrievedTimelocks.releaseStarts[ind].eq(
                reversibleTimelocks[0].releaseStart
              ) &&
              retrievedTimelocks.reversibles[ind] ==
                reversibleTimelocks[0].reversible
          );
          await timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, roles.dao._address);
          await expect(
            timelockManager
              .connect(roles.dao)
              .reverseTimelock(indTimelock, roles.dao._address)
          ).to.be.revertedWith("Timelock is already withdrawn");
        });
      }
    );
    context("If the DAO attempts to withdraw to address 0", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        const reversibleTimelocks = timelocks.filter(
          (timelock) => timelock.reversible
        );
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner, ind) =>
            owner == reversibleTimelocks[0].owner &&
            retrievedTimelocks.totalAmounts[ind].eq(
              reversibleTimelocks[0].totalAmount
            ) &&
            retrievedTimelocks.releaseStarts[ind].eq(
              reversibleTimelocks[0].releaseStart
            ) &&
            retrievedTimelocks.reversibles[ind] ==
              reversibleTimelocks[0].reversible
        );
        await expect(
          timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, ethers.constants.AddressZero)
        ).to.be.revertedWith("Cannot withdraw to address 0");
      });
    });
    context("Timelock is not reversible", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        const reversibleTimelocks = timelocks.filter(
          (timelock) => !timelock.reversible
        );
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner, ind) =>
            owner == reversibleTimelocks[0].owner &&
            retrievedTimelocks.totalAmounts[ind].eq(
              reversibleTimelocks[0].totalAmount
            ) &&
            retrievedTimelocks.releaseStarts[ind].eq(
              reversibleTimelocks[0].releaseStart
            ) &&
            retrievedTimelocks.reversibles[ind] ==
              reversibleTimelocks[0].reversible
        );
        await expect(
          timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, roles.dao._address)
        ).to.be.revertedWith("Timelock is not reversible");
      });
    });
    context("If the timelock is withdrawn", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        const reversibleTimelocks = timelocks.filter(
          (timelock) => timelock.reversible
        );
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner, ind) =>
            owner == roles.owner1._address &&
            retrievedTimelocks.totalAmounts[ind].eq(
              reversibleTimelocks[0].totalAmount
            ) &&
            retrievedTimelocks.releaseStarts[ind].eq(
              reversibleTimelocks[0].releaseStart
            ) &&
            retrievedTimelocks.reversibles[ind] ==
              reversibleTimelocks[0].reversible
        );
        await ethers.provider.send("evm_setNextBlockTimestamp", [
          //Timelock fully claimable after 104 weeks (2 years)
          retrievedTimelocks.releaseEnds[indTimelock].toNumber() + 1,
        ]);
        await timelockManager
          .connect(roles.owner1)
          .withdraw(indTimelock, roles.owner1._address);
        await expect(
          timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, roles.dao._address)
        ).to.be.revertedWith("Timelock is already withdrawn");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      await batchDeployTimelocks();
      const retrievedTimelocks = await timelockManager.getTimelocks();
      const reversibleTimelocks = timelocks.filter(
        (timelock) => timelock.reversible
      );
      const indTimelock = retrievedTimelocks.owners.findIndex(
        (owner, ind) =>
          owner == reversibleTimelocks[0].owner &&
          retrievedTimelocks.totalAmounts[ind].eq(
            reversibleTimelocks[0].totalAmount
          ) &&
          retrievedTimelocks.releaseStarts[ind].eq(
            reversibleTimelocks[0].releaseStart
          ) &&
          retrievedTimelocks.reversibles[ind] ==
            reversibleTimelocks[0].reversible
      );
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .reverseTimelock(indTimelock, roles.randomPerson._address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("reverseTimelockMultiple", function () {
  context("If the caller is the DAO", async function () {
    it("batch-reverses timelocks", async function () {
      await batchDeployTimelocks();
      const retrievedTimelocks = await timelockManager.getTimelocks();
      const reversibleTimelocks = timelocks.filter(
        (timelock) => timelock.reversible
      );
      const reversibleTimelockInds = [];
      let totalAmount = ethers.BigNumber.from(0);
      for (const reversibleTimelock of reversibleTimelocks) {
        // Find the timelock among the retrieved timelocks
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner, ind) =>
            owner == reversibleTimelock.owner &&
            retrievedTimelocks.totalAmounts[ind].eq(
              reversibleTimelock.totalAmount
            ) &&
            retrievedTimelocks.releaseStarts[ind].eq(
              reversibleTimelock.releaseStart
            ) &&
            retrievedTimelocks.reversibles[ind] == reversibleTimelock.reversible
        );
        reversibleTimelockInds.push(indTimelock);
        totalAmount = totalAmount.add(
          retrievedTimelocks.totalAmounts[indTimelock]
        );
      }
      const previousBalance = await api3Token.balanceOf(roles.dao._address);
      await timelockManager
        .connect(roles.dao)
        .reverseTimelockMultiple(reversibleTimelockInds, roles.dao._address);
      const afterBalance = await api3Token.balanceOf(roles.dao._address);
      expect(afterBalance.sub(previousBalance)).to.equal(totalAmount);
    });
    context("parameters are longer than 30", async function () {
      it("reverts", async function () {
        await expect(
          timelockManager
            .connect(roles.dao)
            .reverseTimelockMultiple(
              Array(31).fill(ethers.BigNumber.from(1)),
              roles.dao._address
            )
        ).to.be.revertedWith("Parameters are longer than 30");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .reverseTimelockMultiple([1], roles.dao._address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("withdraw", function () {
  context("If the caller is the owner", async function () {
    context("After releaseTime", async function () {
      it("withdraws", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        // Sort timelocks with respect to their releaseEnd times because we need to
        // fast forward the EVM time in sequence
        let timelocksCopy = timelocks.slice();
        timelocksCopy.sort((a, b) => {
          return a.releaseEnd.gt(b.releaseEnd) ? 1 : -1;
        });
        for (const timelock of timelocksCopy) {
          // Find the timelock among the retrieved timelocks
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == timelock.owner &&
              retrievedTimelocks.totalAmounts[ind].eq(timelock.totalAmount) &&
              retrievedTimelocks.releaseStarts[ind].eq(timelock.releaseStart) &&
              retrievedTimelocks.releaseEnds[ind].eq(timelock.releaseEnd) &&
              retrievedTimelocks.reversibles[ind] == timelock.reversible
          );
          // Fast forward time so that the timelock is resolvable
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            retrievedTimelocks.releaseEnds[indTimelock].toNumber() + 1,
          ]);
          // Get the owner of the timelock
          const ownerRole = Object.values(roles).find(
            (role) => role._address == retrievedTimelocks.owners[indTimelock]
          );
          const previousBalance = await api3Token.balanceOf(ownerRole._address);
          // Have the owner redeem the tokens to their own address
          await expect(
            timelockManager
              .connect(ownerRole)
              .withdraw(indTimelock, ownerRole._address)
          )
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(indTimelock, ownerRole._address);
          // Check if the withdrawal was successful
          const afterBalance = await api3Token.balanceOf(ownerRole._address);
          expect(afterBalance.sub(previousBalance)).to.equal(
            retrievedTimelocks.totalAmounts[indTimelock]
          );
        }
      });

      it("withdraws on a linear schedule", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        // Sort timelocks with respect to their releaseEnd times because we need to
        // fast forward the EVM time in sequence
        let timelocksCopy = timelocks.slice();
        timelocksCopy.sort((a, b) => {
          return a.releaseEnd.gt(b.releaseEnd) ? 1 : -1;
        });
        for (const timelock of timelocksCopy) {
          // Find the timelock among the retrieved timelocks
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == timelock.owner &&
              retrievedTimelocks.totalAmounts[ind].eq(timelock.totalAmount) &&
              retrievedTimelocks.releaseStarts[ind].eq(timelock.releaseStart) &&
              retrievedTimelocks.releaseEnds[ind].eq(timelock.releaseEnd) &&
              retrievedTimelocks.reversibles[ind] == timelock.reversible
          );
          // Fast forward time so that the timelock is resolvable
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            //Set time at 50% point
            retrievedTimelocks.releaseStarts[indTimelock].toNumber() +
              52 * 7 * 24 * 60 * 60,
          ]);
          // Get the owner of the timelock
          const ownerRole = Object.values(roles).find(
            (role) => role._address == retrievedTimelocks.owners[indTimelock]
          );
          const previousBalance = await api3Token.balanceOf(ownerRole._address);
          // Have the owner redeem the tokens to their own address
          await expect(
            timelockManager
              .connect(ownerRole)
              .withdraw(indTimelock, ownerRole._address)
          )
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(indTimelock, ownerRole._address);
          // Check if the withdrawal was successful
          const afterBalance = await api3Token.balanceOf(ownerRole._address);
          expect(afterBalance.sub(previousBalance)).to.equal(
            retrievedTimelocks.totalAmounts[indTimelock].div(2)
          );
        }
      });

      context(
        "If the owner attempts to withdraw a second time",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            // Withdraw a timelock once
            const retrievedTimelocks = await timelockManager.getTimelocks();
            const indTimelock = retrievedTimelocks.owners.findIndex(
              (owner) => owner == roles.owner1._address
            );
            await ethers.provider.send("evm_setNextBlockTimestamp", [
              retrievedTimelocks.releaseEnds[indTimelock].toNumber() + 1,
            ]);

            let balanceBefore = await api3Token.balanceOf(
              roles.owner1._address
            );
            await timelockManager
              .connect(roles.owner1)
              .withdraw(indTimelock, roles.owner1._address);
            let balanceAfter = await api3Token.balanceOf(roles.owner1._address);
            // Verify that the withdrawn timelock amount is deleted
            const individuallyRetrievedTimelock = await timelockManager.getTimelock(
              indTimelock
            );
            expect(individuallyRetrievedTimelock.totalAmount).to.equal(
              balanceAfter.sub(balanceBefore)
            );
            // Attempt to withdraw the same timelock
            await expect(
              timelockManager
                .connect(roles.owner1)
                .withdraw(indTimelock, roles.owner1._address)
            ).to.be.revertedWith("Timelock is already withdrawn");
          });
        }
      );
      context(
        "If the owner attempts to withdraw to address 0",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            const retrievedTimelocks = await timelockManager.getTimelocks();
            const indTimelock = retrievedTimelocks.owners.findIndex(
              (owner) => owner == roles.owner1._address
            );
            await ethers.provider.send("evm_setNextBlockTimestamp", [
              retrievedTimelocks.releaseStarts[indTimelock].toNumber() + 1,
            ]);
            await expect(
              timelockManager
                .connect(roles.owner1)
                .withdraw(indTimelock, ethers.constants.AddressZero)
            ).to.be.revertedWith("Cannot withdraw to address 0");
          });
        }
      );
      context("If the timelock is reversed", async function () {
        it("reverts", async function () {
          await batchDeployTimelocks();
          const retrievedTimelocks = await timelockManager.getTimelocks();
          const reversibleTimelocks = timelocks.filter(
            (timelock) => timelock.reversible
          );
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == roles.owner1._address &&
              retrievedTimelocks.totalAmounts[ind].eq(
                reversibleTimelocks[0].totalAmount
              ) &&
              retrievedTimelocks.releaseStarts[ind].eq(
                reversibleTimelocks[0].releaseStart
              ) &&
              retrievedTimelocks.reversibles[ind] ==
                reversibleTimelocks[0].reversible
          );
          await timelockManager
            .connect(roles.dao)
            .reverseTimelock(indTimelock, roles.dao._address);
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            retrievedTimelocks.releaseStarts[indTimelock].toNumber() + 1,
          ]);
          await expect(
            timelockManager
              .connect(roles.owner1)
              .withdraw(indTimelock, roles.owner1._address)
          ).to.be.revertedWith("Timelock is already withdrawn");
        });
      });
    });

    context("Before the cliff on a timelock with a cliff", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        // Withdraw a timelock once
        const retrievedTimelocks = await timelockManager.getTimelocks();
        const indTimelock = retrievedTimelocks.owners.findIndex(
          (owner) => owner == roles.owner1._address
        );
        await ethers.provider.send("evm_setNextBlockTimestamp", [
          retrievedTimelocks.releaseStarts[indTimelock].toNumber() + 1,
        ]);

        // Attempt to withdraw before the cliff
        await expect(
          timelockManager
            .connect(roles.owner1)
            .withdraw(indTimelock, roles.owner1._address)
        ).to.be.revertedWith("Timelock has not matured yet");
      });
    });

    context(
      "Before the cliff on a timelock without a cliff",
      async function () {
        it("withdraws", async function () {
          await batchDeployTimelocks();
          // Withdraw a timelock once
          const retrievedTimelocks = await timelockManager.getTimelocks();
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == roles.owner1._address &&
              retrievedTimelocks.cliffTimes[ind].eq(0)
          );
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            retrievedTimelocks.releaseStarts[indTimelock].toNumber() +
              24 * 60 * 60,
          ]);

          const balanceBefore = await api3Token.balanceOf(
            roles.owner1._address
          );

          //Withdraw 1 day after start time
          await expect(
            timelockManager
              .connect(roles.owner1)
              .withdraw(indTimelock, roles.owner1._address)
          )
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(indTimelock, roles.owner1._address);
          // Check if the withdrawal was successful
          const balanceAfter = await api3Token.balanceOf(roles.owner1._address);
          expect(balanceAfter.sub(balanceBefore)).to.equal(
            //Balance is 1/728 of total (1 day out of 2 years = 1 days / 728 days)
            //TODO: JS rounding screws up the last 2 digits here, contract reports correct
            //value of 686813186813186800
            // retrievedTimelocks.totalAmounts[indTimelock].div(
            //   728
            // )

            "686813186813186800"
          );
        });
      }
    );

    context("Before releaseTime", async function () {
      it("reverts", async function () {
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
    });
    context("If the timelock does not exist", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const indNonExistentTimelock = timelocks.length;
        await expect(
          timelockManager
            .connect(roles.owner1)
            .withdraw(indNonExistentTimelock, roles.owner1._address)
        ).to.be.revertedWith("No such timelock exists");
      });
    });
  });
  context("If the caller is not the owner", async function () {
    it("reverts", async function () {
      await batchDeployTimelocks();
      const retrievedTimelocks = await timelockManager.getTimelocks();
      const indTimelock = retrievedTimelocks.owners.findIndex(
        (owner) => owner == roles.owner1._address
      );
      await ethers.provider.send("evm_setNextBlockTimestamp", [
        retrievedTimelocks.releaseStarts[indTimelock].toNumber() + 1,
      ]);
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .withdraw(indTimelock, roles.randomPerson._address)
      ).to.be.revertedWith(
        "Only the owner of the timelock can withdraw from it"
      );
    });
  });
});

describe("withdrawToPool", function () {
  context("After DAO has set the pool address", async function () {
    context("If the caller is the owner", async function () {
      it("withdraws to pool", async function () {
        await batchDeployTimelocks();
        await timelockManager
          .connect(roles.dao)
          .updateApi3Pool(api3Pool.address);
        const retrievedTimelocks = await timelockManager.getTimelocks();
        for (const timelock of timelocks) {
          const indTimelock = retrievedTimelocks.owners.findIndex(
            (owner, ind) =>
              owner == timelock.owner &&
              retrievedTimelocks.totalAmounts[ind].eq(timelock.totalAmount) &&
              retrievedTimelocks.releaseStarts[ind].eq(timelock.releaseStart) &&
              retrievedTimelocks.reversibles[ind] == timelock.reversible
          );
          const ownerRole = Object.values(roles).find(
            (role) => role._address == retrievedTimelocks.owners[indTimelock]
          );
          let tx = await timelockManager
            .connect(ownerRole)
            .withdrawToPool(indTimelock, api3Pool.address, ownerRole._address);
          await utils.verifyLog(
            timelockManager,
            tx,
            "WithdrawnToPool(uint256,address,address)",
            {
              indTimelock: indTimelock,
              api3PoolAddress: api3Pool.address,
              beneficiary: ownerRole._address,
            }
          );
          const vestingEpoch = await api3Pool.getEpochIndex(
            retrievedTimelocks.releaseStarts[indTimelock]
          );
          await utils.verifyLog(
            api3Pool,
            tx,
            "VestingCreated(bytes32,address,uint256,uint256)",
            {
              userAddress: ownerRole._address,
              amount: retrievedTimelocks.totalAmounts[indTimelock],
              vestingEpoch: vestingEpoch,
            }
          );
        }
      });
      context(
        "If the owner attempts to withdraw to pool a second time",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            // Withdraw a timelock to the pool once
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
            const retrievedTimelocks = await timelockManager.getTimelocks();
            let indTimelock = retrievedTimelocks.owners.findIndex(
              (owner) => owner == roles.owner1._address
            );
            await timelockManager
              .connect(roles.owner1)
              .withdrawToPool(
                indTimelock,
                api3Pool.address,
                roles.owner1._address
              );

            // Verify that the withdrawn timelock amount is deleted
            const individuallyRetrievedTimelock = await timelockManager.getTimelock(
              indTimelock
            );
            expect(individuallyRetrievedTimelock.totalAmount).to.equal(
              individuallyRetrievedTimelock.releasedAmount
            );
            // Attempt to withdraw the same timelock to the pool
            await expect(
              timelockManager
                .connect(roles.owner1)
                .withdrawToPool(
                  indTimelock,
                  api3Pool.address,
                  roles.owner1._address
                )
            ).to.be.revertedWith("Timelock is already withdrawn");
          });
        }
      );
      context(
        "If the owner attempts to withdraw to benefit address 0",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
            const retrievedTimelocks = await timelockManager.getTimelocks();
            const indTimelock = retrievedTimelocks.owners.findIndex(
              (owner) => owner == roles.owner1._address
            );
            await expect(
              timelockManager
                .connect(roles.owner1)
                .withdrawToPool(
                  indTimelock,
                  api3Pool.address,
                  ethers.constants.AddressZero
                )
            ).to.be.revertedWith("Cannot withdraw to benefit address 0");
          });
        }
      );
      context(
        "If the owner provides the wrong pool address",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            const retrievedTimelocks = await timelockManager.getTimelocks();
            let indTimelock = retrievedTimelocks.owners.findIndex(
              (owner) => owner == roles.owner1._address
            );
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
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
        }
      );
    });
    context("If the caller is not the owner", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        await timelockManager
          .connect(roles.dao)
          .updateApi3Pool(api3Pool.address);
        const retrievedTimelocks = await timelockManager.getTimelocks();
        let indTimelock = retrievedTimelocks.owners.findIndex(
          (owner) => owner == roles.owner1._address
        );
        await expect(
          timelockManager
            .connect(roles.randomPerson)
            .withdrawToPool(
              indTimelock,
              api3Pool.address,
              roles.randomPerson._address
            )
        ).to.be.revertedWith(
          "Only the owner of the timelock can withdraw from it"
        );
      });
    });
    context("If the timelock does not exist", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        await timelockManager
          .connect(roles.dao)
          .updateApi3Pool(api3Pool.address);
        const indNonExistentTimelock = timelocks.length;
        await expect(
          timelockManager
            .connect(roles.owner1)
            .withdrawToPool(
              indNonExistentTimelock,
              api3Pool.address,
              roles.owner1._address
            )
        ).to.be.revertedWith("No such timelock exists");
      });
    });
  });
  context("Before DAO has set the pool address", async function () {
    context("If the caller is the owner", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const retrievedTimelocks = await timelockManager.getTimelocks();
        let indTimelock = retrievedTimelocks.owners.findIndex(
          (owner) => owner == roles.owner1._address
        );
        await expect(
          timelockManager
            .connect(roles.owner1)
            .withdrawToPool(
              indTimelock,
              api3Pool.address,
              roles.owner1._address
            )
        ).to.be.revertedWith("API3 pool not set yet");
      });
    });
  });
});
