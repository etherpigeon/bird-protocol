# @version 0.2.12
"""
@title Curve am3CRV Nest
@license MIT
@author Ether Pigeon
"""
from vyper.interfaces import ERC20


AM3POOL: constant(address) = 0x445FE580eF8d70FF569aB36e80c647af338db351  # Curve Pool
AM3CRV: constant(address) = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171  # Pool LP Token
AM3POOL_GAUGE: constant(address) = 0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c  # Pool Gauge
N_COINS: constant(uint256) = 3


interface AToken:
    def UNDERLYING_ASSET_ADDRESS() -> address: view

interface CurvePool:
    def add_liquidity(
        _amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool
    ) -> uint256: nonpayable
    def calc_token_amount(_amounts: uint256[N_COINS], is_deposit: bool) -> uint256: view
    def calc_withdraw_one_coin(_token_amount: uint256, i: int128) -> uint256: view
    def coins(arg0: uint256) -> address: view
    def lp_token() -> address: view
    def remove_liquidity(
        _amount: uint256, _min_amounts: uint256[N_COINS], _use_underlying: bool
    ) -> uint256[N_COINS]: nonpayable
    def remove_liquidity_imbalance(
        _amounts: uint256[N_COINS], _max_burn_amount: uint256, _use_underlying: bool
    ) -> uint256: nonpayable
    def remove_liquidity_one_coin(
        _token_amount: uint256, i: int128, _min_amount: uint256, _use_underlying: bool
    ) -> uint256: nonpayable
    def underlying_coins(arg0: uint256) -> address: view


event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256


allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)
name: public(String[32])
symbol: public(String[32])
decimals: public(uint256)

future_owner: public(address)
owner: public(address)

coins: public(address[N_COINS])
underlying_coins: public(address[N_COINS])


@external
def __init__():
    self.owner = msg.sender

    self.name = "Curve am3Pool Nest"
    self.symbol = "EGG-am3CRV"
    self.decimals = 18

    for i in range(N_COINS):
        coin: address = CurvePool(AM3POOL).coins(i)
        underlying_coin: address = AToken(coin).UNDERLYING_ASSET_ADDRESS()
        self.coins[i] = coin
        self.underlying_coins[i] = underlying_coin

        assert ERC20(coin).approve(AM3POOL, MAX_UINT256)  # dev: bad response
        assert ERC20(underlying_coin).approve(AM3POOL, MAX_UINT256)  # dev: bad response

    assert ERC20(AM3CRV).approve(AM3POOL_GAUGE, MAX_UINT256)  # dev: bad response


@internal
def _mint(_to: address, _value: uint256) -> bool:
    self.balanceOf[_to] += _value
    self.totalSupply += _value
    log Transfer(ZERO_ADDRESS, _to, _value)
    return True


@internal
def _burn(_from: address, _value: uint256) -> bool:
    self.balanceOf[_from] -= _value
    self.totalSupply -= _value
    log Transfer(_from, ZERO_ADDRESS, _value)
    return True


@external
def approve(_spender: address, _value: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True


@internal
def _transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    self.balanceOf[_from] -= _value  # dev: insufficient balance
    self.balanceOf[_to] += _value
    log Transfer(_from, _to, _value)
    return True


@external
def transfer(_to: address, _value: uint256) -> bool:
    return self._transferFrom(msg.sender, _to, _value)


@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    self.allowance[_from][msg.sender] -= _value  # dev: insufficient approval
    return self._transferFrom(_from, _to, _value)


@external
def commit_transfer_ownership(_owner: address):
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = _owner


@external
def accept_transfer_ownership():
    owner: address = self.future_owner
    assert msg.sender == owner  # dev: only future owner
    self.owner = owner
    self.future_owner = ZERO_ADDRESS


@external
def revert_transfer_ownership():
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = ZERO_ADDRESS
