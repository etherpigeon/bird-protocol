import itertools as it

import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, bob, coins, underlying_coins):
    for depositor in (alice, bob):
        for coin in coins + underlying_coins:
            amt = 100 * 10 ** coin.decimals()
            coin._mint_for_testing(depositor, amt)


@pytest.mark.parametrize("use_underlying", [False, True])
def test_mint_shares_coins(
    alice, coins, underlying_coins, am3pool, am3crv_gauge, am3crv_nest, use_underlying
):
    balances = []
    _coins = underlying_coins if use_underlying else coins
    for coin in _coins:
        balance = coin.balanceOf(alice)
        balances.append(balance)
        coin.approve(am3crv_nest, balance, {"from": alice})
    min_amount = am3pool.calc_token_amount(balances, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) >= min_amount
    assert am3crv_nest.balanceOf(alice) >= min_amount


@pytest.mark.parametrize("use_underlying,idx", it.product([False, True], range(3)))
def test_mint_shares_single_coin(
    alice, coins, underlying_coins, am3pool, am3crv_gauge, am3crv_nest, use_underlying, idx
):
    _coins = underlying_coins if use_underlying else coins
    balances = [0, 0, 0]
    balances[idx] = _coins[idx].balanceOf(alice)
    _coins[idx].approve(am3crv_nest, balances[idx], {"from": alice})
    min_amount = am3pool.calc_token_amount(balances, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) >= min_amount
    assert am3crv_nest.balanceOf(alice) >= min_amount


@pytest.mark.parametrize("use_underlying", [False, True])
def test_mint_shares_coins_nest_grows(
    alice, bob, coins, underlying_coins, am3pool, am3crv_gauge, am3crv_nest, use_underlying
):

    balances = []
    _coins = underlying_coins if use_underlying else coins
    for coin in _coins:
        balance = coin.balanceOf(alice)
        balances.append(balance)
        coin.approve(am3crv_nest, balance, {"from": alice})
    min_amount = am3pool.calc_token_amount(balances, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": alice})

    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)

    balances = []
    for coin in _coins:
        balance = coin.balanceOf(bob)
        balances.append(balance)
        coin.approve(am3crv_nest, balance, {"from": bob})
    min_amount = am3pool.calc_token_amount(balances, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": bob})

    assert am3crv_nest.balanceOf(bob) >= min_shares


@pytest.mark.parametrize("use_underlying", [False, True])
def test_invalid_min_amount(alice, coins, underlying_coins, am3pool, am3crv_nest, use_underlying):
    balances = []
    _coins = underlying_coins if use_underlying else coins
    for coin in _coins:
        balance = coin.balanceOf(alice)
        balances.append(balance)
        coin.approve(am3crv_nest, balance, {"from": alice})
    min_amount = am3pool.calc_token_amount(balances, True) * 1.01
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    with brownie.reverts("dev: bad response"):
        am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": alice})


@pytest.mark.parametrize("use_underlying", [False, True])
def test_invalid_min_shares(alice, coins, underlying_coins, am3pool, am3crv_nest, use_underlying):
    balances = []
    _coins = underlying_coins if use_underlying else coins
    for coin in _coins:
        balance = coin.balanceOf(alice)
        balances.append(balance)
        coin.approve(am3crv_nest, balance, {"from": alice})
    min_amount = am3pool.calc_token_amount(balances, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True) * 1.5
    with brownie.reverts("dev: slippage"):
        am3crv_nest.deposit_coins(balances, min_amount, use_underlying, min_shares, {"from": alice})
