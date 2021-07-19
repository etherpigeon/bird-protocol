import pytest


@pytest.fixture(scope="module")
def guano(alice, GuanoToken):
    return GuanoToken.deploy({"from": alice})


@pytest.fixture(scope="module")
def am3crv_nest(alice, NestAM3CRV):
    return NestAM3CRV.deploy({"from": alice})


@pytest.fixture(scope="session")
def am3pool(interface, coins, decimals):
    pool = interface.StableSwap("0x445FE580eF8d70FF569aB36e80c647af338db351")
    pool.donate_admin_fees({"from": pool.owner()})

    scalers = [18 - precision for precision in decimals]
    balances = [pool.balances(i) * 10 ** precision for i, precision in enumerate(scalers)]
    optimal_balances = [max(balances) // 10 ** precision for precision in scalers]

    for coin, optimal_balance in zip(coins, optimal_balances):
        coin._mint_for_testing(pool, optimal_balance)

    return pool
