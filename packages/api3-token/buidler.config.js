require('dotenv').config();
usePlugin("@nomiclabs/buidler-waffle");
module.exports = {
  networks: {
    buidlerevm: {
    },
    mainnet: {
      url: process.env.MAINNET_PROVIDER_URL || "",
      accounts: {mnemonic: process.env.MNEMONIC || ""}
    },
    rinkeby: {
      url: process.env.RINKEBY_PROVIDER_URL || "",
      accounts: {mnemonic: process.env.MNEMONIC || ""}
    },
  },
  solc: {
    version: "0.6.12",
  },
};
