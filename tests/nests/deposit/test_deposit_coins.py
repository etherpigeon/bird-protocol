import itertools as it

import brownie
import pytest

coin_amounts = [100 * 10 ** p for p in [18, 6, 6]]


@pytest.fixture(scope="module", autouse=True)
def setup(alice, bob, coins_param, am3crv_nest, am3pool):
    for depositor, (coin, amount) in it.product((alice, bob), zip(coins_param, coin_amounts)):
        coin._mint_for_testing(depositor, amount)
        coin.approve(am3crv_nest, 2 ** 256 - 1, {"from": depositor})
        coin.approve("0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf", 2 ** 256 - 1, {"from": am3pool})


def test_mint_shares_coins(alice, am3pool, am3crv_gauge, am3crv_nest, use_underlying):
    min_amount = am3pool.calc_token_amount(coin_amounts, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)

    am3crv_nest.deposit_coins(coin_amounts, min_amount, use_underlying, min_shares, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) >= min_amount
    assert am3crv_nest.balanceOf(alice) >= min_amount


@pytest.mark.parametrize("idx", range(3))
def test_mint_shares_single_coin(alice, am3pool, am3crv_gauge, am3crv_nest, use_underlying, idx):
    amounts = [0, 0, 0]
    amounts[idx] = coin_amounts[idx]

    min_amount = am3pool.calc_token_amount(amounts, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)

    am3crv_nest.deposit_coins(amounts, min_amount, use_underlying, min_shares, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) >= min_amount
    assert am3crv_nest.balanceOf(alice) >= min_amount


def test_mint_shares_coins_nest_grows(
    alice, bob, am3pool, am3crv_gauge, am3crv_nest, use_underlying
):
    min_amount = am3pool.calc_token_amount(coin_amounts, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(coin_amounts, min_amount, use_underlying, min_shares, {"from": alice})

    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)

    min_amount = am3pool.calc_token_amount(coin_amounts, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(coin_amounts, min_amount, use_underlying, min_shares, {"from": bob})

    assert am3crv_nest.balanceOf(bob) >= min_shares


def test_invalid_min_amount(alice, am3pool, am3crv_nest, use_underlying):
    min_amount = am3pool.calc_token_amount(coin_amounts, True) * 2
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    with brownie.reverts("dev: bad response"):
        am3crv_nest.deposit_coins(
            coin_amounts, min_amount, use_underlying, min_shares, {"from": alice}
        )


def test_invalid_min_shares(alice, coins_param, am3pool, am3crv_nest, use_underlying):
    coin_amounts = [coin.balanceOf(alice) for coin in coins_param]
    min_amount = am3pool.calc_token_amount(coin_amounts, True) * 0.99
    min_shares = am3crv_nest.calc_shares(min_amount, True) * 1.5
    with brownie.reverts("dev: slippage"):
        am3crv_nest.deposit_coins(
            coin_amounts, min_amount, use_underlying, min_shares, {"from": alice}
        )
