# Overview

Nests are the core of the Bird Protocol, as they allow anyone to stake their liquidity in an underlying [Curve.fi](https://polygon.curve.fi) liquidity gauge and start earning.
Nest contracts are written in [Vyper](https://vyper.readthedocs.io), allowing easier auditability and readability.

# API Specification

Following is the API specification for the initial set of Nest contracts.

```{note}

Nest contracts adhere to the ERC-20 specification, about which more information can be found at <https://eips.ethereum.org/EIPS/eip-20>
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

(claimable_reward)=
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
