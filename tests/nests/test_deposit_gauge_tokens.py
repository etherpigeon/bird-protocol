import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, am3crv_gauge):
    am3crv_gauge._mint_for_testing(alice, 100 * 10 ** 18)


def test_minted_shares(alice, am3crv_gauge, am3crv_nest):
    am3crv_gauge.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_gauge_tokens(100 * 10 ** 18, {"from": alice})
    assert am3crv_gauge.balanceOf(am3crv_nest) == 100 * 10 ** 18
    assert am3crv_nest.balanceOf(alice) == 100 * 10 ** 18


def test_multiple_depositors_nest_grows(alice, bob, am3crv_gauge, am3crv_nest):

    # alice deposits
    am3crv_gauge.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_gauge_tokens(100 * 10 ** 18, {"from": alice})

    # nest balance grows
    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)

    # bob deposits
    am3crv_gauge._mint_for_testing(bob, 100 * 10 ** 18)
    am3crv_gauge.approve(am3crv_nest, 100 * 10 ** 18, {"from": bob})
    am3crv_nest.deposit_gauge_tokens(100 * 10 ** 18, {"from": bob})

    assert am3crv_nest.balanceOf(alice) == 100 * 10 ** 18
    assert am3crv_nest.balanceOf(bob) == 50 * 10 ** 18  # 100 * 100 // 200


def test_bad_response_reverts(alice, am3crv_nest):
    with brownie.reverts("dev: bad response"):
        am3crv_nest.deposit_gauge_tokens(100 * 10 ** 18, {"from": alice})
