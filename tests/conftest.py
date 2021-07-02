import pytest


@pytest.fixture(scope="session")
def alice(accounts):
    return accounts[0]


@pytest.fixture(scope="session")
def bob(accounts):
    return accounts[1]


@pytest.fixture(scope="session")
def charlie(accounts):
    return accounts[2]


@pytest.fixture(scope="module")
def guano(alice, GuanoToken):
    return GuanoToken.deploy({"from": alice})


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
