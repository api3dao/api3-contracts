const ethers = require("ethers");
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
const timelockManagerArtifact = require("../artifacts/TimelockManager.json");

async function timelockPartner() {
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

  const partners = [
    {
      owner: "0x0000000000000000000000000000000000000001",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000002",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000003",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000004",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000005",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000006",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000007",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000008",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000009",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
    {
      owner: "0x0000000000000000000000000000000000000010",
      amount: ethers.utils.parseEther((100e6).toString()).mul(25).div(1000),
      reversible: true,
    },
  ];

  const owners = [];
  const amounts = [];
  const releaseTimes = [];
  const reversibles = [];
  const now = Math.floor(Date.now() / 1000);
  for (const partner of partners) {
    owners.push(partner.owner);
    owners.push(partner.owner);
    owners.push(partner.owner);
    amounts.push(partner.amount.mul(25).div(100));
    amounts.push(partner.amount.mul(30).div(100));
    amounts.push(partner.amount.mul(45).div(100));
    releaseTimes.push(now + 6 * 30 * 24 * 60 * 60);
    releaseTimes.push(now + 12 * 30 * 24 * 60 * 60);
    releaseTimes.push(now + 24 * 30 * 24 * 60 * 60);
    reversibles.push(partner.reversible);
    reversibles.push(partner.reversible);
    reversibles.push(partner.reversible);
  }

  await timelockManager.transferAndLockMultiple(
    api3DaoAddresses[chainId],
    owners,
    amounts,
    releaseTimes,
    reversibles,
    Array(9).fill(false), //all partners have no cliff
    { gasLimit: 9000000 }
  );
}

timelockPartner();
