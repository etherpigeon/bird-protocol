import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, am3crv):
    am3crv._mint_for_testing(alice, 100 * 10 ** 18)


def test_minted_shares(alice, am3crv, am3crv_gauge, am3crv_nest):
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 100 * 10 ** 18, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) == 100 * 10 ** 18
    assert am3crv_nest.balanceOf(alice) == 100 * 10 ** 18


def test_multiple_depositors_nest_grows(alice, bob, am3crv, am3crv_gauge, am3crv_nest):
    assert am3crv.allowance(am3crv_nest, am3crv_gauge) == 2 ** 256 - 1

    # alice deposits
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 100 * 10 ** 18, {"from": alice})

    assert am3crv.allowance(am3crv_nest, am3crv_gauge) == 2 ** 256 - 1
    # nest balance grows
    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)

    # bob deposits
    am3crv._mint_for_testing(bob, 100 * 10 ** 18)
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": bob})
    am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 50 * 10 ** 18, {"from": bob})

    assert am3crv_nest.balanceOf(alice) == 100 * 10 ** 18
    assert am3crv_nest.balanceOf(bob) == 50 * 10 ** 18  # 100 * 100 // 200


def test_bad_response_reverts(alice, am3crv_nest):
    with brownie.reverts("dev: bad response"):
        am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 100 * 10 ** 18, {"from": alice})


def test_min_shares_revert(alice, am3crv, am3crv_nest):
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    with brownie.reverts("dev: slippage"):
        am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 101 * 10 ** 18, {"from": alice})
