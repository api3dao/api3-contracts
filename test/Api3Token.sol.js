/* global ethers */
const { expect } = require("chai");
const { describe, it, beforeEach } = require("mocha");
const { deploy } = require("./deployer");

describe("Api3Token", function () {
  let api3Token;
  let roles;

  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    roles = {
      owner: accounts[0],
      nonMinter: accounts[1],
      minter: accounts[2],
    };
    ({ api3Token } = await deploy(roles.owner));
  });

  it("Deployer receives all of the total supply of 100 million tokens", async function () {
    const expectedTotalSupply = ethers.utils.parseEther((1e8).toString());
    const totalSupply = await api3Token.totalSupply();
    const deployerBalance = await api3Token.balanceOf(roles.owner._address);
    expect(totalSupply).to.equal(expectedTotalSupply);
    expect(deployerBalance).to.equal(expectedTotalSupply);
  });

  it("Accounts are not authorized to mint by default", async function () {
    const nonMinterMinterStatus = await api3Token.getMinterStatus(
      roles.nonMinter._address
    );
    expect(nonMinterMinterStatus).to.equal(false);
    await expect(
      api3Token
        .connect(roles.nonMinter)
        .mint(
          roles.nonMinter._address,
          ethers.utils.parseEther((1e8).toString())
        )
    ).to.be.revertedWith("Only minters are allowed to mint");
  });

  it("Owner can authorize accounts to mint", async function () {
    // Authorize roles.minter to mint
    await api3Token
      .connect(roles.owner)
      .updateMinterStatus(roles.minter._address, true);
    const minterMinterStatus = await api3Token.getMinterStatus(
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
  });

  it("Owner can revoke minting authorization", async function () {
    // Authorize roles.minter to mint
    await api3Token
      .connect(roles.owner)
      .updateMinterStatus(roles.minter._address, true);
    let minterMinterStatus = await api3Token.getMinterStatus(
      roles.minter._address
    );
    expect(minterMinterStatus).to.equal(true);
    // Revoke minting authorization
    await api3Token
      .connect(roles.owner)
      .updateMinterStatus(roles.minter._address, false);
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
