import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, am3crv):
    am3crv._mint_for_testing(alice, 100 * 10 ** 18)


def test_minted_shares(alice, am3crv, am3crv_gauge, am3crv_nest):
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, {"from": alice})
    assert am3crv.balanceOf(alice) == 0
    assert am3crv_gauge.balanceOf(am3crv_nest) == 100 * 10 ** 18
    assert am3crv_nest.balanceOf(alice) == 100 * 10 ** 18


def test_bad_response_reverts(alice, am3crv_nest):
    with brownie.reverts("dev: bad response"):
        am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, {"from": alice})
