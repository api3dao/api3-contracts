const { expect } = require("chai");
const { deployer } = require("@api3-contracts/helpers");

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
  it("deploys correctly", async function () {
    expect(await api3Token.name()).to.equal("API3");
    expect(await api3Token.symbol()).to.equal("API3");
    expect(await api3Token.decimals()).to.equal(18);

    expect(await api3Token.owner()).to.equal(roles.dao._address);

    const expectedTotalSupply = ethers.utils.parseEther((1e8).toString());
    const totalSupply = await api3Token.totalSupply();
    expect(totalSupply).to.equal(expectedTotalSupply);

    const daoBalance = await api3Token.balanceOf(roles.dao._address);
    expect(daoBalance).to.equal(expectedTotalSupply);
  });
});

describe("renounceOwnership", function () {
  context("If the caller is the DAO", async function () {
    it("reverts", async function () {
      await expect(
        api3Token.connect(roles.dao).renounceOwnership()
      ).to.be.revertedWith("Ownership cannot be renounced");
    });
  });
  context("If the caller is not the DAO", async function () {
    it("reverts", async function () {
      await expect(
        api3Token.connect(roles.randomPerson).renounceOwnership()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});

describe("updateMinterStatus", function () {
  context("If the caller is the DAO", async function () {
    it("can be used to give minting authorization", async function () {
      // Authorize minter to mint
      await expect(
        api3Token
          .connect(roles.dao)
          .updateMinterStatus(roles.minter._address, true)
      )
        .to.emit(api3Token, "MinterStatusUpdated")
        .withArgs(roles.minter._address, true);
      expect(await api3Token.getMinterStatus(roles.minter._address)).to.equal(
        true
      );
      // Mint 200 million tokens
      const initialTotalSupply = await api3Token.totalSupply();
      const amountToBeMinted = ethers.utils.parseEther((2e8).toString());
      await api3Token
        .connect(roles.minter)
        .mint(roles.minter._address, amountToBeMinted);
      const expectedTotalSupply = initialTotalSupply.add(amountToBeMinted);
      // Check balances
      const totalSupply = await api3Token.totalSupply();
      expect(totalSupply).to.equal(expectedTotalSupply);
      const minterBalance = await api3Token.balanceOf(roles.minter._address);
      expect(minterBalance).to.equal(amountToBeMinted);
    });
    it("can be used to revoke minting authorization", async function () {
      // Authorizer minter to mint, to revoke later
      await api3Token
        .connect(roles.dao)
        .updateMinterStatus(roles.minter._address, true);
      // Revoke minting authorization
      await expect(
        api3Token
          .connect(roles.dao)
          .updateMinterStatus(roles.minter._address, false)
      )
        .to.emit(api3Token, "MinterStatusUpdated")
        .withArgs(roles.minter._address, false);
      expect(await api3Token.getMinterStatus(roles.minter._address)).to.equal(
        false
      );
      // Attempt to mint
      await expect(
        api3Token
          .connect(roles.minter)
          .mint(
            roles.minter._address,
            ethers.utils.parseEther((1e8).toString())
          )
      ).to.be.revertedWith("Only minters are allowed to mint");
    });
    context("If the input will not update state", async function () {
      it("reverts", async function () {
        await expect(
          api3Token
            .connect(roles.dao)
            .updateMinterStatus(roles.minter._address, false)
        ).to.be.revertedWith("Input will not update state");
        await api3Token
          .connect(roles.dao)
          .updateMinterStatus(roles.minter._address, true);
        await expect(
          api3Token
            .connect(roles.dao)
            .updateMinterStatus(roles.minter._address, true)
        ).to.be.revertedWith("Input will not update state");
      });
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

describe("updateBurnerStatus", function () {
  it("can be used to claim and renounce burning authorization", async function () {
    await expect(api3Token.connect(roles.dao).updateBurnerStatus(true))
      .to.emit(api3Token, "BurnerStatusUpdated")
      .withArgs(roles.dao._address, true);
    expect(await api3Token.getBurnerStatus(roles.dao._address)).to.equal(true);
    await expect(api3Token.connect(roles.dao).updateBurnerStatus(false))
      .to.emit(api3Token, "BurnerStatusUpdated")
      .withArgs(roles.dao._address, false);
    expect(await api3Token.getBurnerStatus(roles.dao._address)).to.equal(false);
  });
  context("If the input will not update state", async function () {
    it("reverts", async function () {
      await expect(
        api3Token.connect(roles.dao).updateBurnerStatus(false)
      ).to.be.revertedWith("Input will not update state");
      await api3Token.connect(roles.dao).updateBurnerStatus(true);
      await expect(
        api3Token.connect(roles.dao).updateBurnerStatus(true)
      ).to.be.revertedWith("Input will not update state");
    });
  });
});

describe("mint", function () {
  context("If the caller is not authorized to mint", async function () {
    it("reverts", async function () {
      expect(
        await api3Token.getMinterStatus(roles.randomPerson._address)
      ).to.equal(false);
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

describe("burn", function () {
  context("Caller is authorized to burn tokens", async function () {
    it("burns caller's tokens", async function () {
      await expect(api3Token.connect(roles.dao).updateBurnerStatus(true))
        .to.emit(api3Token, "BurnerStatusUpdated")
        .withArgs(roles.dao._address, true);
      const amountToBurn = ethers.utils.parseEther((1e3).toString());
      const initialBalance = await api3Token.balanceOf(roles.dao._address);
      await api3Token
        .connect(roles.dao)
        .burn(ethers.utils.parseEther((1e3).toString()));
      const finalBalance = await api3Token.balanceOf(roles.dao._address);
      expect(initialBalance.sub(finalBalance)).to.equal(amountToBurn);
    });
  });
  context("Caller is not authorized to burn tokens", async function () {
    it("reverts", async function () {
      await expect(
        api3Token
          .connect(roles.dao)
          .burn(ethers.utils.parseEther((1e3).toString()))
      ).to.be.revertedWith("Only burners are allowed to burn");
    });
  });
});
