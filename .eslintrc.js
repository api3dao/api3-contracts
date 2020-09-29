module.exports = {
    "env": {
        "node": true
    },
    "extends": "eslint:recommended",
    "globals": {
      "beforeEach": false,
      "describe": false,
      "ethers": false,
      "it": false,
      "context": false,
      "getChainId": false
    },
    "parserOptions": {
        "ecmaVersion": 11,
        "sourceType": "module"
    },
    "rules": {
    }
};
