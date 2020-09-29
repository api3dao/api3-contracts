const { assert } = require("chai");
const ethers = require("ethers");
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
const timelockManagerArtifact = require("../artifacts/TimelockManager.json");

async function timelockPrivate() {
  const timelockManagerAddresses = {
    1: 0,
    4: "0x7B35bF1954a428B4C2fc04a253a2aa950CB96e6C",
  };
  const api3DaoAddresses = {
    1: 0,
    4: "0x0c26bb185ad09c5a41e8fd127bf7b8c99e81e5dc",
  };
  const chainId = await getChainId();
  const signer = await provider.getSigner();
  const timelockManager = new ethers.Contract(
    timelockManagerAddresses[chainId],
    timelockManagerArtifact.abi,
    signer
  );

  const totalAmount = ethers.utils.parseEther((10e6).toString());
  const amounts = [
    totalAmount.mul(25).div(1000),
    totalAmount.mul(25).div(1000),
    totalAmount.mul(50).div(1000),
    totalAmount.mul(75).div(1000),
    totalAmount.mul(100).div(1000),
    totalAmount.mul(150).div(1000),
    totalAmount.mul(175).div(1000),
    totalAmount.mul(200).div(1000),
    totalAmount.mul(200).div(1000),
  ];
  const accAmount = amounts.reduce(
    (acc, amount) => acc.add(amount),
    ethers.BigNumber.from(0)
  );
  assert(totalAmount.eq(accAmount));

  const now = Math.floor(Date.now() / 1000);
  const releaseTimes = [
    now,
    now + 3 * 30 * 24 * 60 * 60,
    now + 6 * 30 * 24 * 60 * 60,
    now + 9 * 30 * 24 * 60 * 60,
    now + 12 * 30 * 24 * 60 * 60,
    now + 15 * 30 * 24 * 60 * 60,
    now + 18 * 30 * 24 * 60 * 60,
    now + 21 * 30 * 24 * 60 * 60,
    now + 24 * 30 * 24 * 60 * 60,
  ];

  await timelockManager.transferAndLockMultiple(
    api3DaoAddresses[chainId],
    Array(9).fill("0x0000000000000000000000000000000000000123"),
    amounts,
    releaseTimes,
    Array(9).fill(false),
    { gasLimit: 9000000 }
  );
}

timelockPrivate();
