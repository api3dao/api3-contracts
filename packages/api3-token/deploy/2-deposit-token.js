const { deploymentAddresses } = require("@api3-contracts/helpers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log } = deployments;
  const { deployer } = await getNamedAccounts();
  const accounts = await ethers.getSigners();
  const deployerSigner = accounts.filter(
    (account) => account._address == deployer
  )[0];

  const api3DaoVaultAddress =
    deploymentAddresses.api3DaoVault[(await getChainId()).toString()];

  const Api3Token = await deployments.get("Api3Token");
  const api3Token = new ethers.Contract(
    Api3Token.address,
    Api3Token.abi,
    deployerSigner
  );
  const deployerBalance = await api3Token.balanceOf(deployer);
  await api3Token.approve(api3DaoVaultAddress, deployerBalance);

  const vaultAbi = [
    {
      inputs: [
        {
          internalType: "address",
          name: "_token",
          type: "address",
        },
        {
          internalType: "uint256",
          name: "_value",
          type: "uint256",
        },
      ],
      name: "deposit",
      outputs: [],
      stateMutability: "payable",
      type: "function",
    },
  ];

  const api3Dao = new ethers.Contract(
    api3DaoVaultAddress,
    vaultAbi,
    deployerSigner
  );
  await api3Dao.deposit(api3Token.address, deployerBalance, {
    gasLimit: 500000,
  });

  log(`Deposited ${deployerBalance} API3 tokens to ${api3Dao.address}`);
};

module.exports.tags = ["deposit-token"];
