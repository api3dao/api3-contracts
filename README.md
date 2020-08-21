# API3 Pool Contract

## Terminology

**Epoch:**
The period that is used to quantize time (default=1 week, non-governable)

**Claim:**
Short for insurance claim

**Pooling:**
Locking funds in the collateral pool to receive pool shares.
Pooled funds are under collateral risk (i.e., will contribute to claim pay outs).

**Pool shares (aka REP):**
Users are minted pool shares in return of locking funds in the pool:

```
Received_shares = (Tokens_added / Total_tokens) * Total_shares
```

Pool shares can be redeemed for tokens by unpooling, which burns the shares.

```
Value_of_a_share = Total_tokens / Total_shares
```

Paying out insurance claims depreciates pool shares, as it decreases `Total_tokens` without changing `Total_shares`.
This is the mechanic that has all pooled parties share the claim payout.

**Staking:**
The action that the user has to take every epoch to receive staking rewards and voting rights in the next epoch.
Note that the user stakes pool shares, rather than the tokens themselves.

**Vesting:**
Vestings disallow to withdraw a specified amount of tokens of a user until a specified epoch.
The user is free to pool and stake these funds.

**IOU:**
IOUs timelock a specified amount of user funds until a specified claim is finalized with a specified outcome (see below for further details).
Funds in IOUs cannot be used and have to stay unpooled.

## How to stake?

1. Call `deposit()` to deposit funds to the contract.
Doing so does not provide any rewards, nor does it expose the user to collateral risk.

2. Call `pool()` to lock funds in the pool and receive pool shares.
Doing so does not provide any rewards, yet it exposes the user to collateral risk.

3. Call `stake()` to stake pool shares every epoch.
Doing so provides staking rewards and governance rights in the next epoch.
Therefore, if a user has any pool shares, it is in their best interest to stake them.

## How to receive staking rewards?

Call `collect()` to receive staking rewards.
Inflationary rewards will be vested, revenue distribution will be instantly withdrawable.
The reward amounts will be proportional to the pool shares you have staked the previous epoch.

## How to receive voting power?

You will automatically receive voting power proportional to the pool shares you have staked in the previous epoch.

## How to withdraw staked/pooled funds?

1. Call `requestUnpool()` to request to unpool funds (no need to specify the amount beforehand) `unpoolWaitingPeriod` epochs (default=2, governable) later.
This limit is to prevent users from front-running insurance claims (i.e., withdraw as soon as there is a possibility for a claim to be made).
Note that this request can only be done every `unpoolRequestCooldown` (default=4, governable) epochs to prevent users from having an active unpool request at all times (which would allow them to withdraw anytime and defeat the whole purpose).

(`unpoolWaitingPeriod` and `unpoolRequestCooldown` will be set to `0` until insurance is implemented for convenience)

2. Exactly `unpoolWaitingPeriod` epochs after the unpool request, call `unpool()` with the amount you want to unpool.

3. Call `withdraw()` anytime you want.

## What are vestings for?

1. Partners, investors, etc. receive tokens that will be vested after a time period
2. Inflationary staking rewards are vested after `inflationVestingPeriod` (default=52, governable)

## What are IOUs for?

In the insurance scheme, collateral losses are not instantaneous like in DeFi (Kyber/Synthetix).
Instead, the losses first get locked, then get realized (or not) weeks later.

This creates two problem cases:
1. Total pool: 1000 tokens.
I pooled 500 tokens.
A claim has been made for 500 tokens.
If the Kleros court accepts the claim, I will lose 500 * (500 / 1000) = 250 tokens.
I want to withdraw before the claim is finalized because I need to pay my rent.
2. Total pool: 1000 tokens.
I did not pool yet.
A claim has been made for 500 tokens.
Now I want to add my 1000 tokens to the pool.
If the Kleros court accepts the claim, I will lose 500 * (1000 / 2000) = 250 tokens, even though I had not pooled yet at the time the claim was made.

Both cases have trivial solutions:
1. I can withdraw 250 tokens and forfeit the remaining 250.
2. I can accept the potential undeserved 250 token loss.

Neither of these are acceptable.
Instead, we utilize IOUs:
1. I withdraw 250 tokens, and receive a IOU for 250 tokens that is redeemable if/when the respective claim is denied.
2. I pool my 1000 tokens, and receive a IOU for X tokens that is redeemable if/when the respective claim is accepted.

X = The amount of tokens corresponding to pool shares effectively lost during the claim payout.
In other words, the amount this IOU pays back is kept in pool shares rather than tokens.

If an independent claim is paid out before the user redeems IOU type-2, the shares will further depreciate and the user will not be fully compensated (which would be their fault).
The alternative (keeping the amount in absolute tokens) may result in the pool owing more than it can afford, which is worse than lazy users being punished.

## Keeping track of vestings, IOUs and claims

We don't keep the vestings/IOUs of users in an array because handling that is too gas heavy.
Instead, the user (or the dapp they use) needs to keep track of these through past events and refer to specific IDs to redeem them when they have matured.

## Notes

The actions are implemented discretely for simplicity.
In the final version, the user should be able to deposit&pool&stake, or stake&collect staking rewards with a single transaction.

The user should be able to delegate staking renewals and voting power trustlessly to third parties through contracts that wrap this one.
The final version will be adjusted to allow this.
We will get help from Michael (of xToken) about what exactly is needed for this.