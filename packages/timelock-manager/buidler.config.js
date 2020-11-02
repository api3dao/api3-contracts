require('dotenv').config();
usePlugin("@nomiclabs/buidler-waffle");
usePlugin('buidler-deploy');
usePlugin('solidity-coverage');

module.exports = {
  networks: {
    buidlerevm: {
    },
    mainnet: {
      url: process.env.MAINNET_PROVIDER_URL || "",
      accounts: {mnemonic: process.env.MAINNET_MNEMONIC || ""}
    },
    rinkeby: {
      url: process.env.RINKEBY_PROVIDER_URL || "",
      accounts: {mnemonic: process.env.RINKEBY_MNEMONIC || ""}
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
      4: '0x1Da10cDEc44538E1854791b8e71FA4Ef05b4b238',
    },
  },
  solc: {
    version: "0.6.12",
  },
};
