import pytest
from brownie import ZERO_ADDRESS, convert, interface
from brownie_tokens import MintableForkToken


class PolygonForkToken(MintableForkToken):
    def __init__(self, address, interface_name, lp_token=None):
        self._lp_token = lp_token
        abi = getattr(interface, interface_name).abi
        self.from_abi("PolygonForkToken", address, abi)
        super().__init__(address)

    def _mint_for_testing(self, target, amount, tx=None):
        if self._lp_token is not None:
            # gauge
            prev_allowance = self._lp_token.allowance(target, self)
            self._lp_token._mint_for_testing(target, amount)
            self._lp_token.approve(self, amount, {"from": target})
            self.deposit(amount, target, True, {"from": target})
            self._lp_token.approve(self, prev_allowance, {"from": target})
        elif hasattr(self, "deposit") and not self.deposit.payable:
            # child ERC20
            depositor_role = "0x8f4f2da22e8ac8f11e15f9fc141cddbb5deea8800186560abb6e68c5496619a9"
            depositor = self.getRoleMember(depositor_role, 0)
            self.deposit(target, convert.to_bytes(amount), {"from": depositor})
        elif hasattr(self, "deposit") and self.deposit.payable:
            self.deposit({"from": target, "value": amount})
        elif hasattr(self, "ATOKEN_REVISION"):
            # aToken
            underlying_token = PolygonForkToken(self.UNDERLYING_ASSET_ADDRESS(), "UChildERC20")
            lending_pool = interface.LendingPool(self.POOL())
            underlying_token._mint_for_testing(target, amount)
            underlying_token.approve(lending_pool, amount, {"from": target})
            lending_pool.deposit(underlying_token, amount, target, 0, {"from": target})
        elif hasattr(self, "mint") and hasattr(self, "minter"):
            # lp token
            self.mint(target, amount, {"from": self.minter()})
        else:
            return super()._mint_for_testing(target, amount, tx=tx)


@pytest.fixture(scope="session")
def dai():
    return PolygonForkToken("0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", "UChildERC20")


@pytest.fixture(scope="session")
def usdc():
    return PolygonForkToken("0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", "UChildERC20")


@pytest.fixture(scope="session")
def usdt():
    return PolygonForkToken("0xc2132D05D31c914a87C6611C10748AEb04B58e8F", "UChildERC20")


@pytest.fixture(scope="session")
def underlying_coins(dai, usdc, usdt):
    return [dai, usdc, usdt]


@pytest.fixture(scope="session")
def adai():
    return PolygonForkToken("0x27F8D03b3a2196956ED754baDc28D73be8830A6e", "AToken")


@pytest.fixture(scope="session")
def ausdc():
    return PolygonForkToken("0x1a13F4Ca1d028320A707D99520AbFefca3998b7F", "AToken")


@pytest.fixture(scope="session")
def ausdt():
    return PolygonForkToken("0x60D55F02A771d515e077c9C2403a1ef324885CeC", "AToken")


@pytest.fixture(scope="session")
def coins(adai, ausdc, ausdt):
    return [adai, ausdc, ausdt]


@pytest.fixture(scope="session")
def am3pool(interface):
    return interface.StableSwap("0x445FE580eF8d70FF569aB36e80c647af338db351")


@pytest.fixture(scope="session")
def am3crv():
    return PolygonForkToken("0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171", "CurveTokenV3")


@pytest.fixture(scope="session")
def am3crv_gauge(am3crv):
    return PolygonForkToken(
        "0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c", "RewardsOnlyGauge", am3crv
    )


@pytest.fixture(scope="session")
def crv():
    return PolygonForkToken("0x172370d5Cd63279eFa6d502DAB29171933a610AF", "UChildERC20")


@pytest.fixture(scope="session")
def wmatic():
    return PolygonForkToken("0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", "WMatic")


@pytest.fixture(scope="session")
def reward_tokens(crv, wmatic):
    return [wmatic, crv]


@pytest.fixture(scope="session")
def decimals():
    return [18, 6, 6]


@pytest.fixture(scope="module", params=(False, True))
def use_underlying(request):
    return request.param


@pytest.fixture(scope="module")
def coins_param(coins, underlying_coins, use_underlying):
    return underlying_coins if use_underlying else coins
