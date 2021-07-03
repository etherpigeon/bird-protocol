import pytest

pytest_plugins = ["fixtures.accounts", "fixtures.coins", "fixtures.deployments"]


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
