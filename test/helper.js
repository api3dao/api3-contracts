module.exports = {
  setUpPool: async function (api3Token, api3Pool, owner, poolers) {
    for (const pooler of poolers) {
      await api3Token.connect(owner).approve(api3Pool.address, pooler.amount);
      await api3Pool
        .connect(owner)
        .deposit(owner._address, pooler.amount, pooler.account._address);
      await api3Pool
        .connect(pooler.account)
        .pool(pooler.amount);
    }
  },
};
