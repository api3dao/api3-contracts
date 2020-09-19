const { expect } = require("chai");
const { deployer, utils } = require("@api3-contracts/helpers");

let api3Token;
let roles;

beforeEach(async () => {
  const accounts = await ethers.getSigners();
  roles = {
    deployer: accounts[0],
    dao: accounts[1],
    minter: accounts[2],
    randomPerson: accounts[9],
  };
  api3Token = await deployer.deployToken(roles.deployer, roles.dao._address);
});

describe("constructor", function () {
  it("DAO receives the ownership of the token contract and the minted tokens at deployment", async function () {
    const expectedTotalSupply = ethers.utils.parseEther((1e8).toString());
    const totalSupply = await api3Token.totalSupply();
    const daoBalance = await api3Token.balanceOf(roles.dao._address);
    expect(totalSupply).to.equal(expectedTotalSupply);
    expect(daoBalance).to.equal(expectedTotalSupply);
    expect(await api3Token.owner()).to.equal(roles.dao._address);
  });
});

describe("updateMinterStatus", function () {
  context("If the caller is the DAO", async function () {
    it("can be used to give and revoke minting authorization", async function () {
      // Authorize roles.minter to mint
      let tx = await api3Token
        .connect(roles.dao)
        .updateMinterStatus(roles.minter._address, true);
      await utils.verifyLog(api3Token, tx, "MinterStatusUpdated(address,bool)", {
        minterAddress: roles.minter._address,
        minterStatus: true,
      });
      let minterMinterStatus = await api3Token.getMinterStatus(
        roles.minter._address
      );
      expect(minterMinterStatus).to.equal(true);
      // Mint 200 million tokens
      const initialTotalSupply = await api3Token.totalSupply();
      const amountToBeMinted = ethers.utils.parseEther((2e8).toString());
      await api3Token
        .connect(roles.minter)
        .mint(roles.minter._address, amountToBeMinted);
      const expectedTotalSupply = initialTotalSupply.add(amountToBeMinted);
      // Check balances
      const totalSupply = await api3Token.totalSupply();
      const minterBalance = await api3Token.balanceOf(roles.minter._address);
      expect(totalSupply).to.equal(expectedTotalSupply);
      expect(minterBalance).to.equal(amountToBeMinted);
      // Revoke minting authorization
      tx = await api3Token
        .connect(roles.dao)
        .updateMinterStatus(roles.minter._address, false);
      await utils.verifyLog(api3Token, tx, "MinterStatusUpdated(address,bool)", {
        minterAddress: roles.minter._address,
        minterStatus: false,
      });
      minterMinterStatus = await api3Token.getMinterStatus(roles.minter._address);
      expect(minterMinterStatus).to.equal(false);
      // Attempt to mint
      await expect(
        api3Token
          .connect(roles.minter)
          .mint(roles.minter._address, ethers.utils.parseEther((1e8).toString()))
      ).to.be.revertedWith("Only minters are allowed to mint");
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
    await expect(
    api3Token
        .connect(roles.randomPerson)
        .updateMinterStatus(roles.minter._address, true)
        ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("mint", function () {
  context("If the caller is not a minter", async function () {
    it("reverts", async function () {
      const randomPersonMinterStatus = await api3Token.getMinterStatus(
        roles.randomPerson._address
      );
      expect(randomPersonMinterStatus).to.equal(false);
      await expect(
        api3Token
          .connect(roles.randomPerson)
          .mint(
            roles.randomPerson._address,
            ethers.utils.parseEther((1e8).toString())
          )
      ).to.be.revertedWith("Only minters are allowed to mint");
    });
  });
});
