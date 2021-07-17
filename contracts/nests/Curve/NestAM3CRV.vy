# @version 0.2.12
"""
@title Curve am3CRV Nest
@license MIT
@author Ether Pigeon
"""
from vyper.interfaces import ERC20

implements: ERC20


AM3POOL: constant(address) = 0x445FE580eF8d70FF569aB36e80c647af338db351  # Curve Pool
AM3CRV: constant(address) = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171  # Pool LP Token
AM3CRV_GAUGE: constant(address) = 0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c  # Pool Gauge
N_COINS: constant(uint256) = 3
MAX_REWARDS: constant(uint256) = 8


interface CurvePool:
    def add_liquidity(
        _amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool
    ) -> uint256: nonpayable
    def coins(arg0: uint256) -> address: view
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

interface CurveGauge:
    def claim_rewards(_addr: address, _receiver: address): nonpayable
    def deposit(_value: uint256, _addr: address, _claim_rewards: bool): nonpayable
    def reward_tokens(arg0: uint256) -> address: view
    def withdraw(_value: uint256, _claim_rewards: bool): nonpayable


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
reward_tokens: public(address[MAX_REWARDS])


@external
def __init__():
    self.owner = msg.sender

    self.name = "Curve am3Pool Nest"
    self.symbol = "EGG-am3CRV"
    self.decimals = 18

    for i in range(N_COINS):
        coin: address = CurvePool(AM3POOL).coins(i)
        underlying_coin: address = CurvePool(AM3POOL).underlying_coins(i)
        self.coins[i] = coin
        self.underlying_coins[i] = underlying_coin

        assert ERC20(coin).approve(AM3POOL, MAX_UINT256)  # dev: bad response
        assert ERC20(underlying_coin).approve(AM3POOL, MAX_UINT256)  # dev: bad response

    assert ERC20(AM3CRV).approve(AM3CRV_GAUGE, MAX_UINT256)  # dev: bad response

    for i in range(MAX_REWARDS):
        reward_token: address = CurveGauge(AM3CRV_GAUGE).reward_tokens(i)
        if reward_token == ZERO_ADDRESS:
            break
        self.reward_tokens[i] = reward_token


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


@pure
@internal
def _calc_mint_shares(
    _deposit_value: uint256,
    _total_supply: uint256,
    _prev_balance: uint256
) -> uint256:
    if _total_supply == 0:
        return _deposit_value
    else:
        shares: uint256 = (_deposit_value * _total_supply) / _prev_balance
        return shares


@pure
@internal
def _calc_burn_shares(
    _withdraw_value: uint256,
    _total_supply: uint256,
    _current_balance: uint256
) -> uint256:
    if _total_supply == _withdraw_value:
        return _current_balance
    else:
        return (_current_balance * _withdraw_value) / _total_supply


@view
@external
def calc_shares(_value: uint256, _is_deposit: bool) -> uint256:
    am3crv_gauge_balance: uint256 = ERC20(AM3CRV_GAUGE).balanceOf(self)
    total_supply: uint256 = self.totalSupply
    if _is_deposit:
        return self._calc_mint_shares(_value, total_supply, am3crv_gauge_balance)
    else:
        return self._calc_burn_shares(_value, total_supply, am3crv_gauge_balance)


@external
def deposit_gauge_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV_GAUGE).transferFrom(msg.sender, self, _value)  # dev: bad response
    self._mint(msg.sender, mint_amount)
    return mint_amount


@external
def deposit_lp_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV).transferFrom(msg.sender, self, _value)  # dev: bad response
    CurveGauge(AM3CRV_GAUGE).deposit(_value, self, False)
    self._mint(msg.sender, mint_amount)
    return mint_amount


@external
def deposit_coins(_amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool, _min_shares: uint256) -> uint256:
    for i in range(N_COINS):
        coin: address = ZERO_ADDRESS
        if _use_underlying:
            coin = self.underlying_coins[i]
        else:
            coin = self.coins[i]
        assert ERC20(coin).transferFrom(msg.sender, self, _amounts[i])  # dev: bad response

    value: uint256 = CurvePool(AM3POOL).add_liquidity(_amounts, _min_mint_amount, _use_underlying)  # dev: bad response
    mint_amount: uint256 = self._calc_mint_shares(value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    CurveGauge(AM3CRV_GAUGE).deposit(value, self, False)
    self._mint(msg.sender, mint_amount)
    return mint_amount


@external
def withdraw_gauge_tokens(_value: uint256) -> uint256:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    assert ERC20(AM3CRV_GAUGE).transfer(msg.sender, amount)
    return amount


@external
def withdraw_lp_tokens(_value: uint256) -> uint256:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    assert ERC20(AM3CRV).transfer(msg.sender, amount)
    return amount


@external
def withdraw_coins(_value: uint256, _min_amounts: uint256[N_COINS], _use_underlying: bool) -> uint256[N_COINS]:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    CurvePool(AM3POOL).remove_liquidity(amount, _min_amounts, _use_underlying)
    coin_amounts: uint256[N_COINS] = empty(uint256[N_COINS])
    for i in range(N_COINS):
        coin: address = ZERO_ADDRESS
        if _use_underlying:
            coin = self.underlying_coins[i]
        else:
            coin = self.coins[i]
        coin_balance: uint256 = ERC20(coin).balanceOf(self)
        coin_amounts[i] = coin_balance
        assert ERC20(coin).transfer(msg.sender, coin_balance)
    return coin_amounts


@external
def withdraw_coins_imbalance(_amounts: uint256[N_COINS], _max_burn_amount: uint256, _use_underlying: bool) -> uint256:
    max_lp_burn: uint256 = self._calc_burn_shares(_max_burn_amount, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _max_burn_amount)
    CurveGauge(AM3CRV_GAUGE).withdraw(max_lp_burn, False)
    lp_burned: uint256 = CurvePool(AM3POOL).remove_liquidity_imbalance(_amounts, max_lp_burn, _use_underlying)
    lp_remainder: uint256 = max_lp_burn - lp_burned
    if lp_remainder > 0:
        mint_amount: uint256 = self._calc_mint_shares(lp_remainder, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
        self._mint(msg.sender, mint_amount)
        CurveGauge(AM3CRV_GAUGE).deposit(lp_remainder, self, False)
    coin: address = ZERO_ADDRESS
    for i in range(N_COINS):
        if _use_underlying:
            coin = self.underlying_coins[i]
        else:
            coin = self.coins[i]
        coin_balance: uint256 = ERC20(coin).balanceOf(self)
        ERC20(coin).transfer(msg.sender, coin_balance)
    return lp_burned


@external
def withdraw_coins_single(_value: uint256, _i: int128, _min_amount: uint256, _use_underlying: bool) -> uint256:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    CurvePool(AM3POOL).remove_liquidity_one_coin(amount, _i, _min_amount, _use_underlying)
    coin: address = ZERO_ADDRESS
    if _use_underlying:
        coin = self.underlying_coins[_i]
    else:
        coin = self.coins[_i]
    coin_balance: uint256 = ERC20(coin).balanceOf(self)
    ERC20(coin).transfer(msg.sender, coin_balance)

    return coin_balance


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
