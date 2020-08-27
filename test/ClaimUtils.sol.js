/* global ethers */
const { expect } = require("chai");
const { describe, it, beforeEach } = require("mocha");
const { deploy } = require("./deployer");
const { setUpPool } = require("./helper");
const { verifyLog } = require("./util");
const ClaimStatus = Object.freeze({ Pending: 0, Accepted: 1, Denied: 2 });

describe("ClaimUtils", function () {
  let api3Token;
  let api3Pool;
  let roles;
  let poolers;

  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    roles = {
      owner: accounts[0],
      claimsManager: accounts[1],
      claimBeneficiary: accounts[2],
      randomPerson: accounts[9],
    };
    poolers = [
      {
        account: accounts[3],
        amount: ethers.utils.parseEther((1e3).toString()),
      },
      {
        account: accounts[4],
        amount: ethers.utils.parseEther((2e3).toString()),
      },
      {
        account: accounts[5],
        amount: ethers.utils.parseEther((3e3).toString()),
      },
    ];
    ({ api3Token, api3Pool } = await deploy(roles.owner));
    await api3Pool
      .connect(roles.owner)
      .updateClaimsManager(roles.claimsManager._address);
    await setUpPool(api3Token, api3Pool, roles.owner, poolers);
  });

  it("Claims manager can create a claim", async function () {
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    const claim = await api3Pool.getClaim(log.args.claimId);
    expect(claim.beneficiary).to.equal(roles.claimBeneficiary._address);
    expect(claim.amount).to.equal(claimAmount);
    expect(claim.status).to.equal(ClaimStatus.Pending);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(claimAmount);
    expect(await api3Pool.getActiveClaims()).to.deep.equal([log.args.claimId]);
  });

  it("Non-claims manager accounts cannot create a claim", async function () {
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    await expect(
      api3Pool
        .connect(roles.randomPerson)
        .createClaim(roles.claimBeneficiary._address, claimAmount)
    ).to.be.revertedWith("Caller is not the claims manager");
  });

  it("Claims manager cannot create a claim larger than the pool", async function () {
    const claimAmount = ethers.utils.parseEther((3e6).toString());
    await expect(
      api3Pool
        .connect(roles.claimsManager)
        .createClaim(roles.claimBeneficiary._address, claimAmount)
    ).to.be.revertedWith("Not enough funds in the collateral pool");
  });

  it("Claims manager can accept active claims", async function () {
    // Create the claim
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    const totalPooledBefore = await api3Pool.totalPooled();
    const user1Share = await api3Pool.getShare(poolers[0].account._address);
    const totalShares = await api3Pool.totalShares();
    // Accept the claim
    tx = await api3Pool
      .connect(roles.claimsManager)
      .acceptClaim(log.args.claimId);
    await verifyLog(api3Pool, tx, "ClaimAccepted(bytes32)", {
      claimId: log.args.claimId,
    });
    const totalPooledAfter = await api3Pool.totalPooled();
    const user1PooledAfter = await api3Pool.getPooled(
      poolers[0].account._address
    );
    const claim = await api3Pool.getClaim(log.args.claimId);
    expect(claim.beneficiary).to.equal(roles.claimBeneficiary._address);
    expect(claim.amount).to.equal(claimAmount);
    expect(claim.status).to.equal(ClaimStatus.Accepted);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(0);
    expect(await api3Pool.getActiveClaims()).to.deep.equal([]);
    expect(await api3Token.balanceOf(roles.claimBeneficiary._address)).to.equal(
      claimAmount
    );
    expect(totalPooledAfter).to.equal(totalPooledBefore.sub(claimAmount));
    expect(user1PooledAfter).to.equal(
      user1Share.mul(totalPooledAfter).div(totalShares)
    );
  });

  it("Claims manager cannot accept non-existent claims", async function () {
    await expect(
      api3Pool
        .connect(roles.claimsManager)
        .acceptClaim(
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        )
    ).to.be.revertedWith("No such active claim exists");
  });

  it("Non-claims manager accounts cannot accept active claims", async function () {
    // Create the claim
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    await expect(
      api3Pool.connect(roles.randomPerson).acceptClaim(log.args.claimId)
    ).to.be.revertedWith("Caller is not the claims manager");
  });

  it("Claims manager can deny active claims", async function () {
    // Create the claim
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    const totalPooled = await api3Pool.getTotalRealPooled();
    const user1PooledBefore = await api3Pool.getPooled(
      poolers[0].account._address
    );
    // Deny the claim
    tx = await api3Pool
      .connect(roles.claimsManager)
      .denyClaim(log.args.claimId);
    await verifyLog(api3Pool, tx, "ClaimDenied(bytes32)", {
      claimId: log.args.claimId,
    });
    const user1PooledAfter = await api3Pool.getPooled(
      poolers[0].account._address
    );
    expect(user1PooledBefore).to.equal(user1PooledAfter);
    const claim = await api3Pool.getClaim(log.args.claimId);
    expect(claim.beneficiary).to.equal(roles.claimBeneficiary._address);
    expect(claim.amount).to.equal(claimAmount);
    expect(claim.status).to.equal(ClaimStatus.Denied);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(0);
    expect(await api3Pool.getActiveClaims()).to.deep.equal([]);
    expect(await api3Token.balanceOf(roles.claimBeneficiary._address)).to.equal(
      0
    );
    expect(await api3Pool.getTotalRealPooled()).to.equal(totalPooled);
  });

  it("Claims manager cannot deny non-existent claims", async function () {
    await expect(
      api3Pool
        .connect(roles.claimsManager)
        .acceptClaim(
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        )
    ).to.be.revertedWith("No such active claim exists");
  });

  it("Non-claims manager accounts cannot deny active claims", async function () {
    // Create the claim
    const claimAmount = ethers.utils.parseEther((3e3).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    await expect(
      api3Pool.connect(roles.randomPerson).denyClaim(log.args.claimId)
    ).to.be.revertedWith("Caller is not the claims manager");
  });

  it("Multiple claims work", async function () {
    // Create 3 claims
    const claimAmount = ethers.utils.parseEther((1).toString());
    let tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log1 = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log2 = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    tx = await api3Pool
      .connect(roles.claimsManager)
      .createClaim(roles.claimBeneficiary._address, claimAmount);
    const log3 = await verifyLog(
      api3Pool,
      tx,
      "ClaimCreated(bytes32,address,uint256)",
      {
        beneficiary: roles.claimBeneficiary._address,
        amount: claimAmount,
      }
    );
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(
      claimAmount.mul(3)
    );
    expect(await api3Pool.getActiveClaims()).to.deep.equal([
      log1.args.claimId,
      log2.args.claimId,
      log3.args.claimId,
    ]);
    // Deny claim #2
    await api3Pool.connect(roles.claimsManager).denyClaim(log2.args.claimId);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(
      claimAmount.mul(2)
    );
    expect(await api3Pool.getActiveClaims()).to.deep.equal([
      log1.args.claimId,
      log3.args.claimId,
    ]);
    // Accept claim #1
    await api3Pool.connect(roles.claimsManager).acceptClaim(log1.args.claimId);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(claimAmount);
    expect(await api3Pool.getActiveClaims()).to.deep.equal([log3.args.claimId]);
    // Deny claim #3
    await api3Pool.connect(roles.claimsManager).denyClaim(log3.args.claimId);
    expect(await api3Pool.totalActiveClaimsAmount()).to.equal(0);
    expect(await api3Pool.getActiveClaims()).to.deep.equal([]);
  });
});
