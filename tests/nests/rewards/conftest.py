import pytest

DAY = 86400


@pytest.fixture(scope="module", autouse=True)
def deposit_gauge_tokens(
    alice, am3crv_gauge, am3crv, coins, underlying_coins, am3crv_nest, chain, reward_tokens
):
    am3crv_gauge._mint_for_testing(alice, 1000 * 10 ** 18, {"from": alice})
    am3crv_gauge.approve(am3crv_nest, 1000 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_gauge_tokens(1000 * 10 ** 18, 1000 * 10 ** 18, {"from": alice})

    # required for mint actions
    for coin in [am3crv_gauge, am3crv] + coins:
        coin._mint_for_testing(alice, 100 * 10 ** 18)
        coin.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    for coin, precision in zip(coins + underlying_coins, [18, 6, 6, 18, 6, 6]):
        coin._mint_for_testing(alice, 100 * 10 ** precision)
        coin.approve(am3crv_nest, 100 * 10 ** precision, {"from": alice})

    assert max([token.balanceOf(am3crv_nest) for token in reward_tokens]) == 0

    chain.mine(timedelta=DAY * 7)
