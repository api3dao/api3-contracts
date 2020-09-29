const ethers = require("ethers");
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
const api3TokenArtifact = require("../artifacts/Api3Token.json");

async function approve() {
  const api3TokenAddresses = {
    1: 0,
    4: "0x6B3998970db68A9Cb7Ab240017C20D22F08A3cC1",
  };
  const timelockManagerAddresses = {
    1: 0,
    4: "0x7B35bF1954a428B4C2fc04a253a2aa950CB96e6C",
  };
  const chainId = await getChainId();
  const signer = await provider.getSigner();
  const api3Token = new ethers.Contract(
    api3TokenAddresses[chainId],
    api3TokenArtifact.abi,
    signer
  );
  await api3Token.approve(
    timelockManagerAddresses[chainId],
    ethers.utils.parseEther((55e6).toString())
  );
}

approve();
