import pytest


@pytest.fixture(scope="module")
def guano(alice, GuanoToken):
    return GuanoToken.deploy({"from": alice})


@pytest.fixture(scope="module")
def am3crv_nest(alice, NestAM3CRV):
    return NestAM3CRV.deploy({"from": alice})


@pytest.fixture(scope="module")
def am3pool(interface, coins, decimals):
    pool = interface.StableSwap("0x445FE580eF8d70FF569aB36e80c647af338db351")
    pool.donate_admin_fees({"from": pool.owner()})

    scalers = [18 - precision for precision in decimals]
    balances = [pool.balances(i) * 10**precision for i, precision in enumerate(scalers)]
    mint_amounts = [
        (max(balances) - balances[i]) // 10**precision for i, precision in enumerate(scalers)
    ]

    for coin, mint_amt in zip(coins, mint_amounts):
        if mint_amt == 0:
            continue
        coin._mint_for_testing(pool, mint_amt)

    return pool
