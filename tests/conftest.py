import pytest

pytest_plugins = "fixtures.accounts"


@pytest.fixture(scope="module")
def guano(alice, GuanoToken):
    return GuanoToken.deploy({"from": alice})


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
