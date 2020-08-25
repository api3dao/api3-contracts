# API3 Pool Contract

## Terminology

**Epoch:**
The period that is used to quantize time (default=1 week, non-governable)

**Claim:**
Short for insurance claim

**Pooling:**
Locking funds in the collateral pool to receive shares.
Pooled funds are under collateral risk (i.e., will contribute to claim payouts).

**Shares:**
Users are minted shares in return of locking funds in the pool:

```
Shares_to_be_received = Tokens_to_be_pooled / (Total_tokens / Total_shares)
```

Shares can be unpooled to receive tokens back (unpooled shares get burned).

```
Tokens_to_be_received = Shares_to_be_unpooled * (Total_tokens / Total_shares)
```

Each share is worth `(Total_tokens / Total_shares)`.
Paying out insurance claims depreciates shares, as it decreases `Total_tokens` without changing `Total_shares`.
This is the mechanic that has all pooled parties contribute to claim payouts.

The pool is seeded with 1 (Wei) token and 1 ghost share (see below) to initialize share price at 1 and avoid division by zero errors.

**Staking:**
The action that the user has to take every epoch to receive staking rewards and voting rights in the next epoch.
Note that the user stakes shares, rather than the tokens themselves.

**Vesting:**
A vestings disallows a user to withdraw a specified amount of tokens until a specified epoch.
The user is free to pool and stake these funds.
A transaction is needed to vest the tokens when the vesting has matured.

**IOU:**
A user can redeem their IOUs to receive a specified amount of funds (denoted in number of shares) with a transaction if/when a specificed claim is finalized with a specified outcome (see below for further details).
IOUs cannot be pooled.

## How to stake?

1. Call `deposit()` to deposit funds to the contract.
Doing so does not provide any rewards, nor does it expose the user to collateral risk.

2. Call `pool()` to lock funds in the pool and receive shares.
Doing so does not provide any rewards, yet it exposes the user to collateral risk.

Note that an IOU will provided for each active claim process at the moment `pool()` is called.
See below for more details.

3. Call `stake()` to stake shares every epoch.
Doing so provides staking rewards and governance rights in the next epoch.
Therefore, if a user has any shares, it is in their best interest to stake them.

## How to receive staking rewards?

Call `collect()` to receive staking rewards.
Inflationary rewards will be vested, revenue distribution will be instantly withdrawable.
The reward amounts will be proportional to the shares the user has staked the previous epoch.

## How to receive voting power?

The user will automatically receive voting power proportional to the shares they have staked in the previous epoch.
The DAO reads from a `getVotingPower(userAddress, timestamp)` method to get the voting power of an address for a particular proposal.

## How to withdraw staked/pooled funds?

1. Call `requestToUnpool()` to request to unpool shares (no need to specify the amount beforehand) `unpoolWaitingPeriod` epochs (default=2, governable) later.
This limit is to prevent users from front-running insurance claims (i.e., withdraw as soon as there is a possibility for a claim to be made).
Note that this request can only be done every `unpoolRequestCooldown` epochs (default=4, governable) to prevent users from having an active unpooling request at all times (which would allow them to withdraw anytime and defeat the purpose).

`unpoolWaitingPeriod` and `unpoolRequestCooldown` will be set to `0` until insurance is implemented for convenience.
This will allow users with non-vested funds to unpool and withdraw at will.

2. Exactly `unpoolWaitingPeriod` epochs after the unpooling request, call `unpool()` with the amount of shares you want to unpool.

Note that a portion of the funds will stay locked in an IOU for each active claim process at the moment `unpool()` is called.
See below for more details.

3. Call `withdraw()` anytime you want.

## What are vestings for?

1. Partners, investors, etc. receive tokens that will be vested after a time period
2. Inflationary staking rewards are vested after `rewardVestingPeriod` epochs (default=52, governable)

## What are IOUs for?

In the insurance scheme, collateral losses are not instantaneous like in DeFi (Kyber/Synthetix).
Instead, the losses first get locked, then get realized (or not) weeks later.

This creates two problem cases:
1. Total pool: 1000 tokens.
The user has pooled 500 tokens.
A claim has been made for 500 tokens.
If the Kleros court accepts the claim, the user will lose 500 * (500 / 1000) = 250 tokens.
The user wants to withdraw before the claim is finalized because they need to pay their rent.
2. Total pool: 1000 tokens.
The user did not pool yet.
A claim has been made for 500 tokens.
Now the user wants to pool their 1000 tokens.
If the Kleros court accepts the claim, the user will lose 500 * (1000 / 2000) = 250 tokens even though the user had not pooled yet at the time the claim was made.

Both cases have trivial solutions:
1. The user can withdraw 250 tokens and forfeit the remaining 250.
2. The user can accept the potential undeserved 250 token loss.

Neither of these is acceptable, so we utilize IOUs.
An IOU is a promise to the user to pay back tokens corresponding to the amount of shares that would recover their loss right after the claim finalization.
Let us continue from the examples above

1. Say there were 1000 shares for 1000 tokens at the start.
If the claim was denied, the user would have suffered 250 tokens worth of undeserved loss.
Then, the user is provided an IOU worth of 250 shares that can be redeemed if/when the claim is denied.

In addition, the 250 tokens and the corresponding shares are left in the pool to remain as collateral.
These funds/shares without owners are called _ghost shares_ and are removed from the pool if/when the respective IOU is redeemed.

2. Again, say there were 1000 shares for 1000 tokens at the start.
If the claim was accepted, the user would have suffered 250 tokens worth of undeserved loss.
After the payout, there would have been 1500 tokens for 1000 shares.
Then, the user is provided an IOU worth of (1000/1500)*250 = 167 shares that can be redeemed if/when the claim is accepted.

Note that share value decreases with each claim payout.
Therefore, the users should redeem their eligible IOUs as soon as a claim is finalized.
However, there is an edge case where an independent claim starts and ends before the IOU becomes eligible for redemption (i.e., claims do not follow FIFO ordering).
This means that IOUs are partly under collateral risk, even though they do not grant staking rewards or voting power.

## Keeping track of vestings, IOUs and claims

We do not keep the vestings/IOUs of users in an array because handling that is too gas heavy.
Instead, the user (or the dapp they use) needs to keep track of these through past events and refer to specific IDs to vest/redeem them when they have matured.

## Notes

The actions are implemented discretely for simplicity.
In the final version, the user should be able to deposit&pool&stake, or stake&collect staking rewards with a single transaction.

The user should be able to delegate staking renewals and voting power trustlessly to third parties through contracts that wrap this one.
The final version will be adjusted to allow this.
