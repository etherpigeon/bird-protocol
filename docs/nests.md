# Overview

Nests are the core of the Bird Protocol, they allow anyone to stake their liquidity in an underlying [Curve.fi](https://polygon.curve.fi) liquidity gauge and start earning.
Nest contracts are written in [Vyper](https://vyper.readthedocs.io), allowing easier auditability and readability.

# API Specification

Following is the API specification for the initial set of Nest contracts.

```{note}

Nest contracts adhere to the ERC-20 specification, about which more information can be found at <https://eips.ethereum.org/EIPS/eip-20>
```

## External Functions

### Admin Functions

Priviledged functions only callable by the contract [owner](owner) or [future owner](future_owner).

```{function} Nest.accept_transfer_ownership(): nonpayable

Accept the transfer of ownership, only the [future owner](future_owner) can call this successfully.
```

```{function} Nest.commit_transfer_ownership(_owner: address): nonpayable

Commit a transfer of ownership, setting the [future_owner](future_owner).

- `_owner`: The address of the future owner to commit
```

```{function} Nest.revert_transfer_ownership(): nonpayable

Revert the current committed [future owner](future_owner), setting it to the `ZERO_ADDRESS`.
```

```{function} Nest.set_admin_fee(_fee: uint256): nonpayable

Set the admin fee (in bps), which on checkpoints causes a percentage of non-CRV base rewards to be set aside.

- `_fee`: Percentage in basis points
```

```{function} Nest.set_harvester(_harvester: address): nonpayable

Set the harvester address, which has the ability to claim non-CRV rewards for reinvestment.

- `_harvester`: The address of the harvester (preferrably a contract)
```

```{function} Nest.set_reward_contract(_reward_contract: address): nonpayable

Set the reward contract, which will on checkpointing provide additional rewards.

:::{warning}

The address must point to an existing smart contract and not an EOA, or the call will revert
:::

- `_reward_contract`: The address of a reward contract which follows the Reward Contract API
```

```{function} Nest.withdraw_admin_fees(): nonpayable

Withdraw collected admin fees from the nest.
```

### Harvester Functions

Priviledged functions only callable by the set harvester.

```{function} Nest.harvest(): nonpayable

Harvest the collected non-CRV rewards for reinvestment in the nest as gauge tokens.
```

### User Functions

Unpriviledged functions callable by any EOA or Contract

```{function} Nest.claim_rewards(_addr: address) -> bool: nonpayable

Claim all pending rewards (CRV + additional) for an account.

:::{note}

All rewards are sent to the address and not the caller of the function.
:::

- `_addr`: The address to claim rewards for
```

```{function} Nest.claimable_reward_write(_addr: address, _token: address) -> uint256: nonpayable

Get the number of claimable reward tokens, by first checkpointing all rewards, claiming any pending balances.

:::{note}

This function should be manually changed to "view" in the ABI. Calling it via a transaction will not claim available reward tokens, but will checkpoint a user.
:::

- `_addr`: Account to get reward amount for
- `_token`: Token to get reward amount for

:::{code-block} python

>>> nest.claimable_reward_write.call("0x66aB6D9362d4F35596279692F0251Db635165871", "0x172370d5Cd63279eFa6d502DAB29171933a610AF")
7739738344827387904
:::
```

```{function} Nest.deposit_coins(_amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool, _min_shares: uint256) -> uint256: nonpayable

Deposit either [coins](coins) or [underlying coins](underlying_coins) minting at minimum `_min_shares` to the caller. The deposited tokens are deposited into the base pool in exchange for base LP tokens, and then deposited into the underlying gauge to receive rewards.

- `_amounts`: The amount of coins to deposit, the nest contract must be approved to transfer the amounts from the `msg.sender`
- `_min_mint_amount`: The minimum amount of base LP tokens to mint from adding liquidity to the base pool. See [`StableSwap.calc_token_amount`](https://curve.readthedocs.io/exchange-pools.html#StableSwap.calc_token_amount)
- `_use_underlying`: Boolean denoting whether to use [underlying coins](underlying_coins) or [coins](coins)
- `_min_shares`: The minimum amount of shares to receive in return for depositing gauge tokens. See [calc_shares](calc_shares)
```

```{function} Nest.deposit_gauge_tokens(_value: uint256, _min_shares: uint256) -> uint256: nonpayable

Deposit gauge tokens into the nest, effectively exchanging gauge tokens for shares of the nest.

- `_value`: Amount of gauge tokens to deposit. The nest must be approved to transfer the amount from `msg.sender`.
- `_min_shares`: The minimum amount of shares to receive in exchange
```

```{function} Nest.deposit_lp_tokens(_value: uint256, _min_shares: uint256) -> uint256: nonpayable

Deposit LP tokens into the nest, effectively depositing them into the gauge and exchanging them for shares of the nest.

- `_value`: Amount of LP tokens to deposit. The nest must be approved to transfer the amount from `msg.sender`.
- `_min_shares`: The minimum amount of shares to receive in exchange
```

```{function} Nest.update_rewards(): nonpayable

Update the cached list of base rewards (from the underlying liquidity gauge) and additional rewards (from the [reward contract](reward_contract))

:::{note}

Cached rewards can never be overwritten, the maximum amount of base/additional rewards held in their respective list will never exceed **8**.
:::
```

```{function} Nest.withdraw_coins(_value: uint256, _min_amounts: uint256[N_COINS], _use_underlying: bool) -> uint256[N_COINS]: nonpayable

Withdraw [coins](coins) or [underlying coins](underlying_coins) in a balanced fashion from the base pool.

- `_value`: The amount of shares to redeem for coins
- `_min_amounts`: The minimum amount of coins to receive. See [`StableSwap.calc_token_amount`](https://curve.readthedocs.io/exchange-pools.html#StableSwap.calc_token_amount)
- `_use_underlying`: Boolean indicating whether to receive [underlying coins](underlying_coins) (`True`) or [coins](coins) (`False`)
```

```{function} Nest.withdraw_coins_imbalance(_amounts: uint256[N_COINS], _max_burn_amount: uint256, _use_underlying: bool) -> uint256: nonpayable

Withdraw [coins](coins) or [underlying coins](underlying_coins) in a imbalanced fashion from the base pool.

- `_amounts`: Amount of [coins](coins) or [underlying coins](underlying_coins) to receive
- `_max_burn_amount`: The maximum number of shares to burn in the process
- `_use_underlying`: Boolean indicating whether to receive [underlying coins](underlying_coins) (`True`) or [coins](coins) (`False`)
```

```{function} Nest.withdraw_coins_single(_value: uint256, _i: int128, _min_amount: uint256, _use_underlying: bool) -> uint256: nonpayable

Withdraw a single [coin](coins) or [underlying coin](underlying_coins) from the base pool.

- `_value`: Amount of shares to redeem in exchange for coins
- `_i`: Index of the coin to receive
- `_min_amount`: Minimum amount of the coin to receive in the process
- `_use_underlying`: Boolean indicating whether to receive an [underlying coin](underlying_coins) (`True`) or [coin](coins) (`False`)
```

```{function} Nest.withdraw_gauge_tokens(_value: uint256) -> uint256: nonpayable

Redeem shares in exchange for gauge tokens.

- `_value`: The amount of shares to redeem
```

```{function} Nest.withdraw_lp_tokens(_value: uint256) -> uint256: nonpayable

Redeem shares in exchange for underlying LP tokens.

- `_value`: The amount of shares to redeem
```

## View Functions

```{function} Nest.additional_rewards(_i: uint256) -> address: view

List of additional rewards complementary to the base rewards received from the underlying liquidity gauge.

:::{note}

The maximum number of additional rewards is hardcoded to be **8**
:::

- `_i`: An index to get from the list of additional rewards. If a reward is not set at an index, the `ZERO_ADDRESS` is returned.

:::{code-block} python

>>> [nest.rewards(i) for i in range(8)]
["0xD6DF932A45C0f255f85145f286eA0b292B21C90B", "0x0000000000000000000000000000000000000000", ...]
:::
```

```{function} Nest.admin_fee() -> uint256: view

Retrieve the admin fee (in bps) from storage.

:::{note}

Calculating basis points to percentage can be done by, dividing by 100. Ex. 500 bps -> 500/100 -> 5%
:::

:::{code-block} python

>>> nest.admin_fee()
500
:::
```

```{function} Nest.calc_shares(_value: uint256, _is_deposit: bool) -> uint256: view

Calculate the number of shares mintable/redeemable. Useful for calculating the amount of gauge tokens which can be redeemed.

- `_value`: The amount of gauge tokens or shares being deposited/withdrawn.
- `_is_deposit`: Boolean indicating whether gauge tokens are being deposited.

:::{code-block} python

>>> nest.calc_shares(100 * 10 ** 18, True)
100000000000000000000
:::
```

```{function} Nest.claimable_reward(_addr: address, _token: address) -> uint256: view

Get the number of claimable reward tokens for a user

:::{note}

This call does not consider pending claimable amounts in [`reward_contract`](reward_contract). Off-chain callers should instead use [`claimable_reward_write`](claimable_reward_write) as a view method.
:::

- `_addr`: Account to get reward balance for
- `_token` Token to get reward balance for

:::{code-block} python

>>> nest.claimable_reward("0x66aB6D9362d4F35596279692F0251Db635165871", "0x172370d5Cd63279eFa6d502DAB29171933a610AF")
3128052326400000000
:::
```

```{function} Nest.claimed_reward(_addr: address, _token: address) -> uint256: view

Get the number of already claimed reward tokens for a user.

- `_addr`: Account to get reward amount for
- `_token`: Token to get reward amount for

:::{code-block} python

>>> nest.claimed_reward("0x66aB6D9362d4F35596279692F0251Db635165871", "0x172370d5Cd63279eFa6d502DAB29171933a610AF")
6871947673600000000
:::
```

```{function} Nest.coins(_i: uint256) -> address: view

List of underlying curve pool's depositable coins. Indexes above the number of coins in the pool will revert.

- `_i`: Index of the coin to retrieve

:::{code-block} python

>>> [nest.coins(i) for i in range(3)]
["0x27F8D03b3a2196956ED754baDc28D73be8830A6e", "0x1a13F4Ca1d028320A707D99520AbFefca3998b7F", "0x60D55F02A771d515e077c9C2403a1ef324885CeC"]
:::
```

```{function} Nest.future_owner() -> address: view

Retrieve the address of the committed future owner.

:::{code-block} python

>>> nest.future_owner()
0x0000000000000000000000000000000000000000
:::
```

```{function} Nest.harvester() -> address: view

Retrieve the harvester address.

:::{code-block} python

>>> nest.harvester()
0x0000000000000000000000000000000000000000
:::
```

```{function} Nest.owner() -> address: view

Retrieve the current owner address.

:::{code-block} python

>>> nest.owner()
0x66aB6D9362d4F35596279692F0251Db635165871
:::
```

```{function} Nest.reward_balances(_addr: address) -> uint256: view

Mapping of reward token to balance of token, used in checkpointing.

:::{code-block}

>>> nest.reward_balances("0x172370d5Cd63279eFa6d502DAB29171933a610AF")
3500283000000000000000000
:::
```

```{function} Nest.reward_contract() -> address: view

Retrieve the address of the additional rewards contract.

:::{code-block} python

>>> nest.reward_contract()
0x1de441Ef347c3E7fd512B1662B77B5bc4AC28Cc9
:::
```

```{function} Nest.reward_integral(_addr: address) -> uint256: view

The global ratio of reward tokens to shares.

- `_addr`: The token address to retrieve the integral for

:::{code-block} python

>>> nest.reward_integral("0x172370d5Cd63279eFa6d502DAB29171933a610AF")
350000000000000000
:::
```

```{function} Nest.reward_integral_for(_user: address, _token: address) -> uint256: view

The current ratio of reward tokens to shares for a user. Checkpointing a user updates this value, increasing their [claimable_reward](claimable_reward) amount.

- `_user`: The address of a user to query
- `_token`: The address of the token to retrieve the user's reward integral for

:::{code-block} python

>>> nest.reward_integral_for("0x66aB6D9362d4F35596279692F0251Db635165871", "0x172370d5Cd63279eFa6d502DAB29171933a610AF")
150000000000000000
:::
```

```{function} Nest.reward_tokens(_i: uint256) -> address: view

List of reward tokens from the underlying Curve liquidity gauge. Indexes where a reward token is not set will return the `ZERO_ADDRESS`.

:::{note}

The maximum number of reward tokens is hardcoded to be **8**
:::

- `_i`: Index to query

:::{code-block} python

>>> nest.reward_tokens(0)
0x172370d5Cd63279eFa6d502DAB29171933a610AF
:::
```

```{function} Nest.underlying_coins(_i: uint256) -> address: view

List of underlying curve pool's underlying depositable coins. Indexes above the number of coins in the pool will revert.

- `_i`: Index of the coin to retrieve

:::{code-block} python

>>> [nest.underlying_coins(i) for i in range(3)]
["0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"]
:::
```
