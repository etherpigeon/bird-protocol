import math

import pytest


@pytest.fixture(scope="module")
def amounts(decimals):
    return [100 * 10 ** precision for precision in decimals]


@pytest.fixture(scope="module")
def pool_ratio(am3pool, decimals):
    balances = [am3pool.balances(i) / 10 ** precision for i, precision in enumerate(decimals)]
    _sum = sum(balances)
    return [val / _sum for val in balances]


@pytest.fixture(autouse=True)
def setup(alice, amounts, coins_param, am3crv_nest, am3pool, use_underlying):
    for coin, amount in zip(coins_param, amounts):
        coin._mint_for_testing(alice, amount - coin.balanceOf(alice))
        coin.approve(am3crv_nest, amount, {"from": alice})
    min_amount = am3pool.calc_token_amount(amounts, True) * 0.99  # 1% slippage
    min_shares = am3crv_nest.calc_shares(min_amount, True)
    am3crv_nest.deposit_coins(amounts, min_amount, use_underlying, min_shares, {"from": alice})


def test_withdraw_shares(alice, coins_param, decimals, pool_ratio, am3crv_nest, use_underlying):
    value = am3crv_nest.balanceOf(alice)

    am3crv_nest.withdraw_coins(value, [0] * 3, use_underlying, {"from": alice})

    for coin, proportion, precision in zip(coins_param, pool_ratio, decimals):
        assert math.isclose(
            coin.balanceOf(alice), proportion * (300 * 10 ** precision), rel_tol=0.01
        )


def test_withdraw_shares_nest_grows(
    alice, am3crv_gauge, coins_param, pool_ratio, decimals, am3crv_nest, use_underlying
):
    am3crv_gauge._mint_for_testing(am3crv_nest, am3crv_gauge.balanceOf(am3crv_nest))  # double up
    value = am3crv_nest.balanceOf(alice)

    am3crv_nest.withdraw_coins(value, [0] * 3, use_underlying, {"from": alice})
    for coin, proportion, precision in zip(coins_param, pool_ratio, decimals):
        assert math.isclose(
            coin.balanceOf(alice), proportion * (2 * 300 * 10 ** precision), rel_tol=0.01
        )


def test_withdraw_shares_imbalanced(alice, coins_param, decimals, am3crv_nest, use_underlying):
    balance = am3crv_nest.balanceOf(alice)
    max_burn = balance / 2

    proportion = [0.2, 0.4, 0.4]
    amounts = [100 * p * 10 ** precision for p, precision in zip(proportion, decimals)]
    am3crv_nest.withdraw_coins_imbalance(amounts, max_burn, use_underlying, {"from": alice})

    for coin, amount in zip(coins_param, amounts):
        assert math.isclose(coin.balanceOf(alice), amount, rel_tol=0.001)
    assert am3crv_nest.balanceOf(alice) >= balance - max_burn


@pytest.mark.parametrize("idx", [0, 1, 2])
def test_withdraw_shares_single(alice, am3pool, coins_param, am3crv_nest, use_underlying, idx):
    balance = am3crv_nest.balanceOf(alice)
    min_amount = am3pool.calc_withdraw_one_coin(balance, idx) * 0.99  # slippage

    am3crv_nest.withdraw_coins_single(balance, idx, min_amount, use_underlying)

    assert coins_param[idx].balanceOf(alice) >= min_amount
