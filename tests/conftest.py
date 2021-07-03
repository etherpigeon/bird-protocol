import pytest

pytest_plugins = ["fixtures.accounts", "fixtures.deployments"]


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
