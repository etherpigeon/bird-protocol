import pytest


@pytest.fixture(scope="module")
def guano(alice, GuanoToken):
    return GuanoToken.deploy({"from": alice})


@pytest.fixture(scope="module")
def am3crv_nest(alice, NestAM3CRV):
    return NestAM3CRV.deploy({"from": alice})
