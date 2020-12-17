const { expect } = require("chai");

let token;
let payer;
let roles;

beforeEach(async () => {
  const accounts = await ethers.getSigners();
  roles = {
    dao: accounts[0],
    owner: accounts[1],
    payee1: accounts[2],
    payee2: accounts[3],
    payee3: accounts[4],
  };
  const MockToken = await ethers.getContractFactory("MockToken");
  token = await MockToken.deploy();

  const Payer = await ethers.getContractFactory("Payer");
  payer = await Payer.deploy(roles.owner.address, token.address);
});

describe("constructor", function () {
  it("initializes with correct parameters", async function () {
    expect(await payer.owner()).to.equal(roles.owner.address);
    expect(await payer.getTokenAddress()).to.equal(token.address);
    expect(await payer.paymentsSet()).to.equal(false);
  });
});

describe("setPayments", function () {
  context("Caller is the owner", async function () {
    context("Payments are not set", async function () {
      context("Parameters are of equal length", async function () {
        context("Parameters are not empty", async function () {
          context("Parameters are no longer than 30", async function () {
            it("sets payments", async function () {
              const destinations = [
                roles.payee1.address,
                roles.payee2.address,
                roles.payee3.address,
              ];
              const amounts = [
                ethers.BigNumber.from(1),
                ethers.BigNumber.from(2),
                ethers.BigNumber.from(3),
              ];
              await payer
                .connect(roles.owner)
                .setPayments(destinations, amounts);
              const {
                _destinations,
                _amounts,
              } = await payer.getDestinationsAndAmounts();
              expect(_destinations).to.be.eql(destinations);
              expect(_amounts).to.be.eql(amounts);
            });
          });
          context("Parameters are longer than 30", async function () {
            it("reverts", async function () {
              await expect(
                payer
                  .connect(roles.owner)
                  .setPayments(
                    Array(31).fill(ethers.constants.AddressZero),
                    Array(31).fill(1)
                  )
              ).to.be.revertedWith("Parameters longer than 30");
            });
          });
        });
        context("Parameters are empty", async function () {
          it("reverts", async function () {
            await expect(
              payer.connect(roles.owner).setPayments([], [])
            ).to.be.revertedWith("Parameters empty");
          });
        });
      });
      context("Parameters are not of equal length", async function () {
        it("reverts", async function () {
          await expect(
            payer
              .connect(roles.owner)
              .setPayments(
                Array(3).fill(ethers.constants.AddressZero),
                Array(2).fill(1)
              )
          ).to.be.revertedWith("Parameters not of equal length");
        });
      });
    });
    context("Payments are set", async function () {
      it("reverts", async function () {
        await payer
          .connect(roles.owner)
          .setPayments(
            Array(3).fill(ethers.constants.AddressZero),
            Array(3).fill(1)
          );
        await expect(
          payer
            .connect(roles.owner)
            .setPayments(
              Array(3).fill(ethers.constants.AddressZero),
              Array(2).fill(1)
            )
        ).to.be.revertedWith("Payment already set");
      });
    });
  });
  context("Caller is not the owner", async function () {
    it("reverts", async function () {
      await expect(
        payer
          .connect(roles.dao)
          .setPayments(
            Array(3).fill(ethers.constants.AddressZero),
            Array(3).fill(1)
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("makePayments", function () {
  context("Payments are set", async function () {
    context("The contract is funded", async function () {
      it("makes payments", async function () {
        const destinations = [
          roles.payee1.address,
          roles.payee2.address,
          roles.payee3.address,
        ];
        const amounts = [1, 2, 3];
        expect(await payer.isReadyToPay()).to.equal(false);
        await payer.connect(roles.owner).setPayments(destinations, amounts);
        expect(await payer.isReadyToPay()).to.equal(false);
        const requiredDeposit = await payer.getRequiredDeposit();
        await token.connect(roles.dao).transfer(payer.address, requiredDeposit);
        expect(await payer.isReadyToPay()).to.equal(true);
        await payer.makePayments();
        for (const [ind, destination] of destinations.entries()) {
          expect(await token.balanceOf(destination)).to.equal(amounts[ind]);
        }
      });
    });
    context("The contract is not funded", async function () {
      it("revert", async function () {
        const destinations = [
          roles.payee1.address,
          roles.payee2.address,
          roles.payee3.address,
        ];
        const amounts = [1, 2, 3];
        await payer.connect(roles.owner).setPayments(destinations, amounts);
        await expect(payer.makePayments()).to.be.revertedWith(
          "ERC20: transfer amount exceeds balance"
        );
      });
    });
  });
  context("Payments are not set", async function () {
    it("reverts", async function () {
      await expect(payer.makePayments()).to.be.revertedWith("Payments not set");
    });
  });
});

describe("getRequiredDeposit", function () {
  it("gets required deposit", async function () {
    expect(await payer.getRequiredDeposit()).to.be.equal(0);
    const amounts = [1, 2, 3];
    const totalAmount = amounts.reduce((a, b) => a + b, 0);
    await payer
      .connect(roles.owner)
      .setPayments(Array(3).fill(ethers.constants.AddressZero), amounts);
    expect(await payer.getRequiredDeposit()).to.be.equal(totalAmount);
    await token.connect(roles.dao).transfer(payer.address, totalAmount / 2);
    expect(await payer.getRequiredDeposit()).to.be.equal(
      totalAmount - totalAmount / 2
    );
    await token.connect(roles.dao).transfer(payer.address, totalAmount / 2);
    expect(await payer.getRequiredDeposit()).to.be.equal(0);
    await token.connect(roles.dao).transfer(payer.address, totalAmount / 2);
    expect(await payer.getRequiredDeposit()).to.be.equal(0);
  });
});
