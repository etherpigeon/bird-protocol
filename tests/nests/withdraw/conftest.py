import pytest


@pytest.fixture(scope="module", autouse=True)
def deposit_setup(am3crv_nest, am3crv_gauge, alice):
    am3crv_gauge._mint_for_testing(alice, 100 * 10 ** 18, {"from": alice})
    am3crv_gauge.approve(am3crv_nest, 100 * 10 ** 18, {"from": alice})
    am3crv_nest.deposit_gauge_tokens(100 * 10 ** 18, 0, {"from": alice})
