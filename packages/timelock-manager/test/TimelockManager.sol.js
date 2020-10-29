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
      (acc, timelock) => acc.add(timelock.amount),
      ethers.BigNumber.from(0)
    )
  );
  // Batch-deploy timelocks
  let tx = await timelockManager.connect(roles.dao).transferAndLockMultiple(
    roles.dao._address,
    timelocks.map((timelock) => timelock.recipient),
    timelocks.map((timelock) => timelock.amount),
    timelocks.map((timelock) => timelock.releaseStart),
    timelocks.map((timelock) => timelock.releaseEnd)
  );
  // Check that each timelock deployment has emitted its respective event
  for (const timelock of timelocks) {
    await utils.verifyLog(
      timelockManager,
      tx,
      "TransferredAndLocked(address,address,uint256,uint256,uint256)",
      {
        source: roles.dao._address,
        recipient: timelock.recipient,
        amount: timelock.amount,
        releaseStart: timelock.releaseStart,
        releaseEnd: timelock.releaseEnd,
      }
    );
  }
}

async function verifyDeployedTimelocks() {
  for (const timelock of timelocks) {
    const retrievedTimelock = await timelockManager.getTimelock(
      timelock.recipient
    );
    expect(retrievedTimelock.totalAmount).to.equal(timelock.amount);
    expect(retrievedTimelock.remainingAmount).to.equal(timelock.amount);
    expect(retrievedTimelock.releaseStart).to.equal(timelock.releaseStart);
    expect(retrievedTimelock.releaseEnd).to.equal(timelock.releaseEnd);
  }
}

beforeEach(async () => {
  const accounts = await ethers.getSigners();
  roles = {
    deployer: accounts[0],
    dao: accounts[1],
    recipient1: accounts[2],
    recipient2: accounts[3],
    randomPerson: accounts[9],
  };
  const currentTimestamp = parseInt(
    (await ethers.provider.send("eth_getBlockByNumber", ["latest", false]))
      .timestamp
  );
  timelocks = [
    {
      recipient: roles.recipient1._address,
      amount: ethers.utils.parseEther((2e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 40000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 60000),
    },
    {
      recipient: roles.recipient2._address,
      amount: ethers.utils.parseEther((8e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 20000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 30000),
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
    it("transfers and locks tokens", async function () {
      // Approve enough tokens to cover all timelocks
      await api3Token.connect(roles.dao).approve(
        timelockManager.address,
        timelocks.reduce(
          (acc, timelock) => acc.add(timelock.amount),
          ethers.BigNumber.from(0)
        )
      );
      // Deploy timelocks individually
      for (const timelock of timelocks) {
        let tx = await timelockManager
          .connect(roles.dao)
          .transferAndLock(
            roles.dao._address,
            timelock.recipient,
            timelock.amount,
            timelock.releaseStart,
            timelock.releaseEnd
          );
        await utils.verifyLog(
          timelockManager,
          tx,
          "TransferredAndLocked(address,address,uint256,uint256,uint256)",
          {
            source: roles.dao._address,
            recipient: timelock.recipient,
            amount: timelock.amount,
            releaseStart: timelock.releaseStart,
            releaseEnd: timelock.releaseEnd,
          }
        );
      }
      await verifyDeployedTimelocks();
    });
    context("If the recipient has remaining tokens", async function () {
      it("reverts", async function () {
        await api3Token
          .connect(roles.dao)
          .approve(timelockManager.address, timelocks[0].amount);
        await timelockManager
          .connect(roles.dao)
          .transferAndLock(
            roles.dao._address,
            timelocks[0].recipient,
            timelocks[0].amount,
            timelocks[0].releaseStart,
            timelocks[0].releaseEnd
          );
        await expect(
          timelockManager
            .connect(roles.dao)
            .transferAndLock(
              roles.dao._address,
              timelocks[0].recipient,
              timelocks[0].amount,
              timelocks[0].releaseStart,
              timelocks[0].releaseEnd
            )
        ).to.be.revertedWith("Recipient has remaining tokens");
      });
    });
    context("If the transferred and locked amount is 0", async function () {
      it("reverts", async function () {
        await expect(
          timelockManager
            .connect(roles.dao)
            .transferAndLock(
              roles.dao._address,
              timelocks[0].recipient,
              0,
              timelocks[0].releaseStart,
              timelocks[0].releaseEnd
            )
        ).to.be.revertedWith("Amount cannot be 0");
      });
    });
    context("If releaseStart is larger than releaseEnd", async function () {
      it("reverts", async function () {
        await expect(
          timelockManager.connect(roles.dao).transferAndLock(
            roles.dao._address,
            timelocks[0].recipient,
            timelocks[0].amount,
            // Note that releaseStart and releaseEnd is switched around
            timelocks[0].releaseEnd,
            timelocks[0].releaseStart
          )
        ).to.be.revertedWith("releaseEnd has to be larger than releaseStart");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      await expect(
        timelockManager
          .connect(roles.randomPerson)
          .transferAndLock(
            roles.randomPerson._address,
            timelocks[0].recipient,
            timelocks[0].amount,
            timelocks[0].releaseStart,
            timelocks[0].releaseEnd
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
            (acc, timelock) => acc.add(timelock.amount),
            ethers.BigNumber.from(0)
          )
        );
        await expect(
          timelockManager.connect(roles.dao).transferAndLockMultiple(
            roles.dao._address,
            [timelocks[0].recipient], // This should have been a list of multiple elements
            timelocks.map((timelock) => timelock.amount),
            timelocks.map((timelock) => timelock.releaseStart),
            timelocks.map((timelock) => timelock.releaseEnd)
          )
        ).to.be.revertedWith("Lengths of parameters do not match");
      });
    });
    context("parameters are longer than 30", async function () {
      it("reverts", async function () {
        /*
        await api3Token
          .connect(roles.dao)
          .approve(timelockManager.address, timelocks[0].amount);
        const gasCost = await timelockManager
          .connect(roles.dao)
          .estimateGas.transferAndLockMultiple(
            roles.dao._address,
            [...Array(30)].map(() => ethers.Wallet.createRandom().address),
            Array(30).fill(1),
            Array(30).fill(timelocks[0].releaseStart),
            Array(30).fill(timelocks[0].releaseEnd)
          );
        */
        // Costs 2,979,067 gas
        await expect(
          timelockManager
            .connect(roles.dao)
            .transferAndLockMultiple(
              roles.dao._address,
              Array(31).fill(timelocks[0].recipient),
              Array(31).fill(timelocks[0].amount),
              Array(31).fill(timelocks[0].releaseStart),
              Array(31).fill(timelocks[0].releaseEnd)
            )
        ).to.be.revertedWith("Parameters are longer than 30");
      });
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      await expect(
        timelockManager.connect(roles.randomPerson).transferAndLockMultiple(
          roles.dao._address,
          timelocks.map((timelock) => timelock.recipient),
          timelocks.map((timelock) => timelock.amount),
          timelocks.map((timelock) => timelock.releaseStart),
          timelocks.map((timelock) => timelock.releaseEnd)
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("withdraw", function () {
  context("If the caller is the recipient", async function () {
    context("After releaseTime", async function () {
      it("withdraws", async function () {
        await batchDeployTimelocks();
        // Sort timelocks with respect to their releaseTimes because we have to
        // fast forward the EVM time in sequence
        let timelocksCopy = timelocks.slice();
        timelocksCopy.sort((a, b) => {
          return a.releaseEnd.gt(b.releaseEnd) ? 1 : -1;
        });
        for (const timelock of timelocksCopy) {
          // Fast forward time so that the timelock is resolvable
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            timelock.releaseEnd.toNumber() + 1,
          ]);
          // Get the recipient of the timelock
          const recipientRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          const previousBalance = await api3Token.balanceOf(
            recipientRole._address
          );
          // Have the recipient withdraw the tokens to their own address
          await expect(
            timelockManager
              .connect(recipientRole)
              .withdraw(recipientRole._address)
          )
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(recipientRole._address, recipientRole._address);
          // Check if the withdrawal was successful
          const afterBalance = await api3Token.balanceOf(
            recipientRole._address
          );
          expect(afterBalance.sub(previousBalance)).to.equal(timelock.amount);
        }
      });
      context(
        "If the recipient attempts to withdraw a second time",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            // Withdraw a timelock once
            const timelock = timelocks[0];
            await ethers.provider.send("evm_setNextBlockTimestamp", [
              timelock.releaseEnd.toNumber() + 1,
            ]);
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await timelockManager
              .connect(recipientRole)
              .withdraw(recipientRole._address);
            // Verify that the withdrawn timelock amount is depleted
            const retrievedTimelock = await timelockManager.getTimelock(
              recipientRole._address
            );
            expect(retrievedTimelock.remainingAmount).to.equal(0);
            // Attempt to withdraw the same timelock
            await expect(
              timelockManager
                .connect(recipientRole)
                .withdraw(recipientRole._address)
            ).to.be.revertedWith("Recipient does not have remaining tokens");
          });
        }
      );
      context(
        "If the recipient attempts to withdraw to address 0",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            const timelock = timelocks[0];
            await ethers.provider.send("evm_setNextBlockTimestamp", [
              timelock.releaseEnd.toNumber() + 1,
            ]);
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await expect(
              timelockManager
                .connect(recipientRole)
                .withdraw(ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid destination");
          });
        }
      );
    });
    context("Before releaseStart", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const timelock = timelocks[0];
        const recipientRole = Object.values(roles).find(
          (role) => role._address == timelock.recipient
        );
        await expect(
          timelockManager
            .connect(recipientRole)
            .withdraw(roles.recipient1._address)
        ).to.be.revertedWith("No withdrawable tokens yet");
      });
    });
    context("Between releaseStart and releaseEnd", async function () {
      it("withdraws", async function () {
        await batchDeployTimelocks();
        const timelock = timelocks[0];
        // Withdraw at the middle of the vesting schedule
        await ethers.provider.send("evm_setNextBlockTimestamp", [
          (timelock.releaseStart.toNumber() + timelock.releaseEnd.toNumber()) /
            2,
        ]);
        // Get the recipient of the timelock
        const recipientRole = Object.values(roles).find(
          (role) => role._address == timelock.recipient
        );
        const previousBalance = await api3Token.balanceOf(
          recipientRole._address
        );
        // Have the recipient withdraw the tokens to their own address
        await expect(
          timelockManager
            .connect(recipientRole)
            .withdraw(recipientRole._address)
        )
          .to.emit(timelockManager, "Withdrawn")
          .withArgs(recipientRole._address, recipientRole._address);
        // Check if the withdrawal was successful
        const duringBalance = await api3Token.balanceOf(recipientRole._address);
        // Verify that the recipient recieved half of the amount
        expect(duringBalance.sub(previousBalance)).to.equal(
          timelock.amount.div(2)
        );
        // Wait until the vesting schedule ends
        await ethers.provider.send("evm_setNextBlockTimestamp", [
          timelock.releaseEnd.toNumber() + 1,
        ]);
        await expect(
          timelockManager
            .connect(recipientRole)
            .withdraw(recipientRole._address)
        )
          .to.emit(timelockManager, "Withdrawn")
          .withArgs(recipientRole._address, recipientRole._address);
        const afterBalance = await api3Token.balanceOf(recipientRole._address);
        expect(afterBalance.sub(previousBalance)).to.equal(timelock.amount);
      });
    });
    context("If the timelock does not exist", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        await expect(
          timelockManager
            .connect(roles.randomPerson)
            .withdraw(roles.randomPerson._address)
        ).to.be.revertedWith("Recipient does not have remaining tokens");
      });
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
        for (const timelock of timelocks) {
          const ownerRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          let tx = await timelockManager
            .connect(ownerRole)
            .withdrawToPool(api3Pool.address, ownerRole._address);
          await utils.verifyLog(
            timelockManager,
            tx,
            "WithdrawnToPool(address,address,address)",
            {
              recipient: ownerRole._address,
              api3PoolAddress: api3Pool.address,
              beneficiary: ownerRole._address,
            }
          );
        }
      });
      context(
        "If the recipient attempts to withdraw to pool a second time",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            // Withdraw a timelock to the pool once
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
            const timelock = timelocks[0];
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await timelockManager
              .connect(recipientRole)
              .withdrawToPool(api3Pool.address, recipientRole._address);
            // Verify that the withdrawn timelock amount is deleted
            const retrievedTimelock = await timelockManager.getTimelock(
              timelock.recipient
            );
            expect(retrievedTimelock.remainingAmount).to.equal(0);
            // Attempt to withdraw the same timelock to the pool
            await expect(
              timelockManager
                .connect(recipientRole)
                .withdrawToPool(api3Pool.address, roles.recipient1._address)
            ).to.be.revertedWith("Recipient does not have remaining tokens");
          });
        }
      );
      context(
        "If the recipient attempts to withdraw to benefit address 0",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
            const timelock = timelocks[0];
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await expect(
              timelockManager
                .connect(recipientRole)
                .withdrawToPool(api3Pool.address, ethers.constants.AddressZero)
            ).to.be.revertedWith("Cannot withdraw to benefit address 0");
          });
        }
      );
      context(
        "If the owner provides the wrong pool address",
        async function () {
          it("reverts", async function () {
            await batchDeployTimelocks();
            await timelockManager
              .connect(roles.dao)
              .updateApi3Pool(api3Pool.address);
            const timelock = timelocks[0];
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await expect(
              timelockManager
                .connect(recipientRole)
                .withdrawToPool(
                  ethers.constants.AddressZero,
                  recipientRole._address
                )
            ).to.be.revertedWith("API3 pool addresses do not match");
          });
        }
      );
    });
    context("If the timelock does not exist", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        await timelockManager
          .connect(roles.dao)
          .updateApi3Pool(api3Pool.address);
        await expect(
          timelockManager
            .connect(roles.randomPerson)
            .withdrawToPool(api3Pool.address, roles.randomPerson._address)
        ).to.be.revertedWith("Recipient does not have remaining tokens");
      });
    });
  });
  context("Before DAO has set the pool address", async function () {
    context("If the caller is the recipient", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        const timelock = timelocks[0];
        const recipientRole = Object.values(roles).find(
          (role) => role._address == timelock.recipient
        );
        await expect(
          timelockManager
            .connect(recipientRole)
            .withdrawToPool(api3Pool.address, recipientRole._address)
        ).to.be.revertedWith("API3 pool not set yet");
      });
    });
  });
});

describe("getWithdrawable", function () {
  it("returns the withdrawable amount", async function () {
    await batchDeployTimelocks();
    const timelock = timelocks[0];
    expect(await timelockManager.getWithdrawable(timelock.recipient)).to.equal(
      ethers.BigNumber.from(0)
    );

    const noSteps = 10;
    for (let i = 0; i < noSteps; i++) {
      const time = timelock.releaseStart.add(
        timelock.releaseEnd.sub(timelock.releaseStart).div(noSteps).mul(i)
      );
      await ethers.provider.send("evm_setNextBlockTimestamp", [
        time.toNumber(),
      ]);
      // We have to wait for a block since the next call is static
      await ethers.provider.send("evm_mine");
      expect(
        await timelockManager.getWithdrawable(timelock.recipient)
      ).to.equal(timelock.amount.div(noSteps).mul(i));
    }

    await ethers.provider.send("evm_setNextBlockTimestamp", [
      timelock.releaseEnd.toNumber() + 1,
    ]);
    await ethers.provider.send("evm_mine");
    expect(await timelockManager.getWithdrawable(timelock.recipient)).to.equal(
      timelock.amount
    );
  });
});
