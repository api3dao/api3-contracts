const { expect } = require("chai");
const { deployer, utils } = require("@api3-contracts/helpers");

let api3Token;
let timelockManager;
let roles;
let timelocks;

async function batchDeployTimelocks() {
  // Approve enough tokens to cover all timelocks
  await api3Token.connect(roles.contractOwner).approve(
    timelockManager.address,
    timelocks.reduce(
      (acc, timelock) => acc.add(timelock.amount),
      ethers.BigNumber.from(0)
    )
  );
  // Batch-deploy timelocks
  let tx = await timelockManager
    .connect(roles.contractOwner)
    .transferAndLockMultiple(
      roles.contractOwner._address,
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
        source: roles.contractOwner._address,
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
    const retrievedRemainingAmount = await timelockManager.getRemainingAmount(
      timelock.recipient
    );
    expect(retrievedRemainingAmount).to.equal(timelock.amount);
  }
}

beforeEach(async () => {
  const accounts = await ethers.getSigners();
  roles = {
    deployer: accounts[0],
    contractOwner: accounts[1],
    recipient1: accounts[2],
    recipient2: accounts[3],
    recipient3: accounts[4],
    recipient4: accounts[5],
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
    {
      recipient: roles.recipient3._address,
      amount: ethers.utils.parseEther((8e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 5000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 10000),
    },
    {
      recipient: roles.recipient4._address,
      amount: ethers.utils.parseEther((8e2).toString()),
      releaseStart: ethers.BigNumber.from(currentTimestamp + 15000),
      releaseEnd: ethers.BigNumber.from(currentTimestamp + 18000),
    },
  ];
  api3Token = await deployer.deployToken(
    roles.deployer,
    roles.contractOwner._address
  );
  timelockManager = await deployer.deployTimelockManagerReversible(
    roles.deployer,
    roles.contractOwner._address,
    api3Token.address
  );
});

describe("constructor", function () {
  it("deploys correctly", async function () {
    expect(await timelockManager.api3Token()).to.equal(api3Token.address);
    expect(await timelockManager.owner()).to.equal(
      roles.contractOwner._address
    );
  });
});

describe("stopVesting", function () {
  context("Caller is the contractOwner", async function () {
    context("Recipient has remaining tokens", async function () {
      context("Destination is valid", async function () {
        it("sets the releaseEnd to the currentTimeStamp (test uses evm_setNextBlockTimestamp)", async function () {
          await batchDeployTimelocks();
          const timelock = timelocks[2];
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            (timelock.releaseStart.toNumber() +
              timelock.releaseEnd.toNumber()) /
              2,
          ]);
          const recipientRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          await timelockManager
            .connect(roles.contractOwner)
            .stopVesting(recipientRole._address, roles.randomPerson._address);

          const currentTimestamp = parseInt(
            (
              await ethers.provider.send("eth_getBlockByNumber", [
                "latest",
                false,
              ])
            ).timestamp
          );
          const retrievedTimelock = await timelockManager.getTimelock(
            recipientRole._address
          );
          expect(retrievedTimelock.releaseEnd.toNumber()).to.be.equal(
            currentTimestamp
          );
        });

        it("sets the remainingAmount to withdrawable (test uses evm_setNextBlockTimestamp)", async function () {
          await batchDeployTimelocks();
          const timelock = timelocks[2];
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            (timelock.releaseStart.toNumber() +
              timelock.releaseEnd.toNumber()) /
              2,
          ]);
          const recipientRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          await timelockManager
            .connect(roles.contractOwner)
            .stopVesting(recipientRole._address, roles.randomPerson._address);
          const currentTimestamp = parseInt(
            (
              await ethers.provider.send("eth_getBlockByNumber", [
                "latest",
                false,
              ])
            ).timestamp
          );
          const retrievedTimelock = await timelockManager.getTimelock(
            recipientRole._address
          );

          // Check if the vesting set the remaining amount
          expect(retrievedTimelock.remainingAmount).be.equal(
            timelock.amount.div(2)
          );
          // Have the recipient Withdraw the tokens
          await expect(timelockManager.connect(recipientRole).withdraw())
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(recipientRole._address, timelock.amount.div(2));

          // Wait some time to confirm that more tokens are not getting vested
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            currentTimestamp + 10000,
          ]);
          await expect(
            timelockManager.connect(recipientRole).withdraw()
          ).to.be.revertedWith("Recipient does not have remaining tokens");
        });

        it("sends the reclaimedTokens to the destination address (test uses evm_setNextBlockTimestamp)", async function () {
          await batchDeployTimelocks();
          const timelock = timelocks[0];
          await ethers.provider.send("evm_setNextBlockTimestamp", [
            (timelock.releaseStart.toNumber() +
              timelock.releaseEnd.toNumber()) /
              2,
          ]);
          const recipientRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          const previousBalanceOfDestination = await api3Token.balanceOf(
            roles.randomPerson._address
          );
          const previousBalanceOfRecipient = await timelockManager.getRemainingAmount(
            recipientRole._address
          );

          await timelockManager
            .connect(roles.contractOwner)
            .stopVesting(recipientRole._address, roles.randomPerson._address);

          const retrievedTimelock = await timelockManager.getTimelock(
            recipientRole._address
          );

          const newBalanceOfRecipient = await timelockManager.getRemainingAmount(
            recipientRole._address
          );
          expect(
            previousBalanceOfRecipient.sub(newBalanceOfRecipient)
          ).to.equal(timelock.amount.div(2));

          const newBalanceOfDestination = await api3Token.balanceOf(
            roles.randomPerson._address
          );
          expect(
            newBalanceOfDestination.sub(previousBalanceOfDestination)
          ).to.equal(
            retrievedTimelock.totalAmount.sub(retrievedTimelock.remainingAmount)
          );
        });
      });
      context("Destination is not valid", async function () {
        it("reverts", async function () {
          await batchDeployTimelocks();
          await expect(
            timelockManager
              .connect(roles.contractOwner)
              .stopVesting(
                roles.recipient1._address,
                ethers.constants.AddressZero
              )
          ).to.be.revertedWith("revert ERC20: transfer to the zero address");
        });
      });
    });
    context("Recipient does not have remaining tokens", async function () {
      it("reverts", async function () {
        await batchDeployTimelocks();
        await expect(
          timelockManager.connect(roles.randomPerson).withdraw()
        ).to.be.revertedWith("Recipient does not have remaining tokens");
      });
    });
  });
  context("Caller is not the Contract Owner", async function () {
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

describe("transferAndLock", function () {
  context("Caller is the Contract Owner", async function () {
    context("Recipient does not have remaining tokens", async function () {
      context("Transferred and locked amount is not 0", async function () {
        context("releaseEnd is larger than releaseStart", async function () {
          context("releaseStart is larger than now", async function () {
            it("transfers and locks tokens", async function () {
              // Approve enough tokens to cover all timelocks
              await api3Token.connect(roles.contractOwner).approve(
                timelockManager.address,
                timelocks.reduce(
                  (acc, timelock) => acc.add(timelock.amount),
                  ethers.BigNumber.from(0)
                )
              );
              // Deploy timelocks individually
              for (const timelock of timelocks) {
                let tx = await timelockManager
                  .connect(roles.contractOwner)
                  .transferAndLock(
                    roles.contractOwner._address,
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
                    source: roles.contractOwner._address,
                    recipient: timelock.recipient,
                    amount: timelock.amount,
                    releaseStart: timelock.releaseStart,
                    releaseEnd: timelock.releaseEnd,
                  }
                );
              }
              await verifyDeployedTimelocks();
            });
          });
          context("releaseStart is smaller than now", async function () {
            it("reverts", async function () {
              await expect(
                timelockManager
                  .connect(roles.contractOwner)
                  .transferAndLock(
                    roles.contractOwner._address,
                    timelocks[0].recipient,
                    timelocks[0].amount,
                    0,
                    timelocks[0].releaseEnd
                  )
              ).to.be.revertedWith("releaseStart not in the future");
            });
          });
        });
        context(
          "releaseEnd is not larger than releaseStart",
          async function () {
            it("reverts", async function () {
              await expect(
                timelockManager.connect(roles.contractOwner).transferAndLock(
                  roles.contractOwner._address,
                  timelocks[0].recipient,
                  timelocks[0].amount,
                  // Note that releaseStart and releaseEnd is switched around
                  timelocks[0].releaseEnd,
                  timelocks[0].releaseStart
                )
              ).to.be.revertedWith("releaseEnd not larger than releaseStart");
            });
          }
        );
      });
      context("Transferred and locked amount is 0", async function () {
        it("reverts", async function () {
          await expect(
            timelockManager
              .connect(roles.contractOwner)
              .transferAndLock(
                roles.contractOwner._address,
                timelocks[0].recipient,
                0,
                timelocks[0].releaseStart,
                timelocks[0].releaseEnd
              )
          ).to.be.revertedWith("Amount cannot be 0");
        });
      });
    });
    context("Recipient has remaining tokens", async function () {
      it("reverts", async function () {
        await api3Token
          .connect(roles.contractOwner)
          .approve(timelockManager.address, timelocks[0].amount);
        await timelockManager
          .connect(roles.contractOwner)
          .transferAndLock(
            roles.contractOwner._address,
            timelocks[0].recipient,
            timelocks[0].amount,
            timelocks[0].releaseStart,
            timelocks[0].releaseEnd
          );
        await expect(
          timelockManager
            .connect(roles.contractOwner)
            .transferAndLock(
              roles.contractOwner._address,
              timelocks[0].recipient,
              timelocks[0].amount,
              timelocks[0].releaseStart,
              timelocks[0].releaseEnd
            )
        ).to.be.revertedWith("Recipient has remaining tokens");
      });
    });
  });
  context("Caller is not the Contract Owner", async function () {
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
  context("Caller is the Contract Owner", async function () {
    context("Parameters are of equal length", async function () {
      context("Parameters are not longer than 30", async function () {
        it("batch-transfers and locks tokens", async function () {
          await batchDeployTimelocks();
          await verifyDeployedTimelocks();
        });
      });
      context("Parameters are longer than 30", async function () {
        it("reverts", async function () {
          /*
          await api3Token
            .connect(roles.contractOwner)
            .approve(timelockManager.address, timelocks[0].amount);
          const gasCost = await timelockManager
            .connect(roles.contractOwner)
            .estimateGas.transferAndLockMultiple(
              roles.contractOwner._address,
              [...Array(30)].map(() => ethers.Wallet.createRandom().address),
              Array(30).fill(1),
              Array(30).fill(timelocks[0].releaseStart),
              Array(30).fill(timelocks[0].releaseEnd)
            );
          */
          // Costs 2,979,067 gas
          await expect(
            timelockManager
              .connect(roles.contractOwner)
              .transferAndLockMultiple(
                roles.contractOwner._address,
                Array(31).fill(timelocks[0].recipient),
                Array(31).fill(timelocks[0].amount),
                Array(31).fill(timelocks[0].releaseStart),
                Array(31).fill(timelocks[0].releaseEnd)
              )
          ).to.be.revertedWith("Parameters are longer than 30");
        });
      });
    });
    context("Parameters are not of equal length", async function () {
      it("reverts", async function () {
        // Approve enough tokens to cover all timelocks
        await api3Token.connect(roles.contractOwner).approve(
          timelockManager.address,
          timelocks.reduce(
            (acc, timelock) => acc.add(timelock.amount),
            ethers.BigNumber.from(0)
          )
        );
        await expect(
          timelockManager.connect(roles.contractOwner).transferAndLockMultiple(
            roles.contractOwner._address,
            [timelocks[0].recipient], // This should have been a list of multiple elements
            timelocks.map((timelock) => timelock.amount),
            timelocks.map((timelock) => timelock.releaseStart),
            timelocks.map((timelock) => timelock.releaseEnd)
          )
        ).to.be.revertedWith("Parameters are of unequal length");
      });
    });
  });
  context("Caller is not the Contract Owner", async function () {
    it("reverts", async function () {
      await expect(
        timelockManager.connect(roles.randomPerson).transferAndLockMultiple(
          roles.contractOwner._address,
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
  context("Recipient has remaining tokens", async function () {
    context("After releaseTime", async function () {
      it("withdraws (test uses evm_setNextBlockTimestamp)", async function () {
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
            timelock.releaseEnd.toNumber() + 10,
          ]);
          // Get the recipient of the timelock
          const recipientRole = Object.values(roles).find(
            (role) => role._address == timelock.recipient
          );
          const previousBalance = await api3Token.balanceOf(
            recipientRole._address
          );
          // Have the recipient withdraw the tokens to their own address
          await expect(timelockManager.connect(recipientRole).withdraw())
            .to.emit(timelockManager, "Withdrawn")
            .withArgs(recipientRole._address, timelock.amount);
          // Check if the withdrawal was successful
          const afterBalance = await api3Token.balanceOf(
            recipientRole._address
          );
          expect(afterBalance.sub(previousBalance)).to.equal(timelock.amount);
        }
      });
      context(
        "Recipient attempts to withdraw a second time",
        async function () {
          it("reverts (test uses evm_setNextBlockTimestamp)", async function () {
            await batchDeployTimelocks();
            // Withdraw a timelock once
            const timelock = timelocks[0];
            await ethers.provider.send("evm_setNextBlockTimestamp", [
              timelock.releaseEnd.toNumber() + 1,
            ]);
            const recipientRole = Object.values(roles).find(
              (role) => role._address == timelock.recipient
            );
            await timelockManager.connect(recipientRole).withdraw();
            // Verify that the withdrawn timelock amount is depleted
            const retrievedTimelock = await timelockManager.getTimelock(
              recipientRole._address
            );
            expect(retrievedTimelock.remainingAmount).to.equal(0);
            // Attempt to withdraw the same timelock
            await expect(
              timelockManager.connect(recipientRole).withdraw()
            ).to.be.revertedWith("Recipient does not have remaining tokens");
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
          timelockManager.connect(recipientRole).withdraw()
        ).to.be.revertedWith("No withdrawable tokens yet");
      });
    });
    context("Between releaseStart and releaseEnd", async function () {
      it("withdraws (test uses evm_setNextBlockTimestamp)", async function () {
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
        await expect(timelockManager.connect(recipientRole).withdraw())
          .to.emit(timelockManager, "Withdrawn")
          .withArgs(recipientRole._address, timelock.amount.div(2));
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
        await expect(timelockManager.connect(recipientRole).withdraw())
          .to.emit(timelockManager, "Withdrawn")
          .withArgs(recipientRole._address, timelock.amount.div(2));
        const afterBalance = await api3Token.balanceOf(recipientRole._address);
        expect(afterBalance.sub(previousBalance)).to.equal(timelock.amount);
      });
    });
  });
  context("Recipient does not have remaining tokens", async function () {
    it("reverts", async function () {
      await batchDeployTimelocks();
      await expect(
        timelockManager.connect(roles.randomPerson).withdraw()
      ).to.be.revertedWith("Recipient does not have remaining tokens");
    });
  });
});

describe("getWithdrawable", function () {
  it("returns the withdrawable amount (test uses evm_setNextBlockTimestamp)", async function () {
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
