require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");

const fs = require("fs");
let credentials = require("./credentials.example.json");
if (fs.existsSync("./credentials.json")) {
  credentials = require("./credentials.json");
}

module.exports = {
  networks: {
    mainnet: {
      url: credentials.mainnet.providerUrl || "",
      accounts: { mnemonic: credentials.mainnet.mnemonic || "" },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: "0x1Da10cDEc44538E1854791b8e71FA4Ef05b4b238",
    },
  },
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
