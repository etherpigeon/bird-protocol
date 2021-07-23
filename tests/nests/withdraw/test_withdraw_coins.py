import pytest
from brownie import ETH_ADDRESS

coin_amounts = [33 * 10 ** p for p in [18, 6, 6]]


@pytest.fixture(autouse=True)
def setup(coins_param, alice):
    for coin in coins_param:
        if coin.balanceOf(alice) > 0:
            coin.transfer(ETH_ADDRESS, coin.balanceOf(alice), {"from": alice})


def test_withdraw_shares(alice, am3pool, coins_param, am3crv_nest, use_underlying):
    value = am3pool.calc_token_amount(coin_amounts, False) * 1.01

    am3crv_nest.withdraw_coins(value, coin_amounts, use_underlying, {"from": alice})

    for coin, amount in zip(coins_param, coin_amounts):
        assert coin.balanceOf(alice) >= amount


def test_withdraw_shares_nest_grows(
    alice, am3pool, am3crv_gauge, coins_param, am3crv_nest, use_underlying
):
    am3crv_gauge._mint_for_testing(am3crv_nest, am3crv_gauge.balanceOf(am3crv_nest))  # double up

    min_amounts = [amt * 2 for amt in coin_amounts]
    min_lp_amt = am3pool.calc_token_amount(min_amounts, False)
    value = am3crv_nest.calc_shares(min_lp_amt, True) * 1.01

    am3crv_nest.withdraw_coins(value, min_amounts, use_underlying, {"from": alice})

    for coin, amount in zip(coins_param, coin_amounts):
        assert coin.balanceOf(alice) > 2 * amount


def test_withdraw_shares_imbalanced(alice, coins_param, am3crv_nest, use_underlying):
    balance = am3crv_nest.balanceOf(alice)
    max_burn = balance / 2

    proportion = [0.1, 0.2, 0.3]
    imbalanced_amounts = [amt * p for amt, p in zip(coin_amounts, proportion)]
    am3crv_nest.withdraw_coins_imbalance(
        imbalanced_amounts, max_burn, use_underlying, {"from": alice}
    )

    for coin, amount in zip(coins_param, imbalanced_amounts):
        assert coin.balanceOf(alice) >= amount

    assert am3crv_nest.balanceOf(alice) >= balance - max_burn


@pytest.mark.parametrize("idx", [0, 1, 2])
def test_withdraw_shares_single(alice, am3pool, coins_param, am3crv_nest, use_underlying, idx):
    balance = am3crv_nest.balanceOf(alice)
    min_amount = am3pool.calc_withdraw_one_coin(balance, idx) * 0.99  # slippage

    am3crv_nest.withdraw_coins_single(balance, idx, min_amount, use_underlying)

    assert coins_param[idx].balanceOf(alice) >= min_amount
