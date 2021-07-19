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
CHECKPOINT_DELAY: constant(uint256) = 1800  # 30 min delay
CRV: constant(address) = 0x172370d5Cd63279eFa6d502DAB29171933a610AF  # CRV Token
MAX_REWARDS: constant(uint256) = 8
N_COINS: constant(uint256) = 3

FEE_DENOMINATOR: constant(uint256) = 10_000


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
    def claim_rewards(): nonpayable
    def deposit(_value: uint256, _addr: address, _claim_rewards: bool): nonpayable
    def reward_tokens(arg0: uint256) -> address: view
    def withdraw(_value: uint256, _claim_rewards: bool): nonpayable


event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Deposit:
    _user: indexed(address)
    _value: uint256

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Withdraw:
    _user: indexed(address)
    _value: uint256


allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)
name: public(String[32])
symbol: public(String[32])
decimals: public(uint256)

future_owner: public(address)
owner: public(address)
harvester: public(address)

coins: public(address[N_COINS])
underlying_coins: public(address[N_COINS])
reward_tokens: public(address[MAX_REWARDS])

# For tracking external rewards
reward_balances: public(HashMap[address, uint256])
# reward token -> integral
reward_integral: public(HashMap[address, uint256])
# reward token -> claiming address -> integral
reward_integral_for: public(HashMap[address, HashMap[address, uint256]])
# user -> [uint128 claimable amount][uint128 claimed amount]
claim_data: public(HashMap[address, HashMap[address, uint256]])

last_checkpoint: public(uint256)

admin_balances: public(HashMap[address, uint256])
admin_fee: public(uint256)


@external
def __init__():
    self.owner = msg.sender
    self.harvester = msg.sender

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


@internal
def _checkpoint_reward(_token: address, _user: address, _user_balance: uint256, _total_supply: uint256, _claim: bool, _apply_fee: bool, _receiver: address):
    reward_slope: uint256 = 0
    if _total_supply != 0:
        new_rewards: uint256 = ERC20(_token).balanceOf(self) - self.reward_balances[_token]
        fee: uint256 = 0
        if _apply_fee:
            fee = self.admin_fee * new_rewards / FEE_DENOMINATOR

        # reward_slope = ratio of new reward token per LP token
        reward_slope = 10**18 * (new_rewards - fee) / _total_supply
        self.reward_balances[_token] += new_rewards
        self.admin_balances[_token] += fee

    # integral = sum of reward_slope over the course of nest lifetime
    integral: uint256 = self.reward_integral[_token] + reward_slope
    if reward_slope != 0:
        self.reward_integral[_token] = integral

    # integral_for = per user integral, which for new users starts at current integral
    integral_for: uint256 = self.reward_integral_for[_token][_user]
    if integral_for <= integral or _total_supply == 0:
        new_claimable: uint256 = _user_balance * (integral - integral_for) / 10**18
        self.reward_integral_for[_token][_user] = integral

        claim_data: uint256 = self.claim_data[_user][_token]
        total_claimed: uint256 = claim_data % 2 ** 128  # lower order bytes
        total_claimable: uint256 = shift(claim_data, -128) + new_claimable

        if _claim and total_claimable > 0:
            assert ERC20(_token).transfer(_receiver, total_claimable)
            self.reward_balances[_token] -= total_claimable
            # update amount claimed (lower order bytes)
            self.claim_data[_user][_token] = total_claimed + total_claimable
        elif new_claimable > 0:
            # update total_claimable (higher order bytes)
            self.claim_data[_user][_token] = total_claimed + shift(total_claimable, 128)


@internal
def _checkpoint_rewards(_user: address, _total_supply: uint256, _claim: bool):
    if block.timestamp < self.last_checkpoint + CHECKPOINT_DELAY:
        return

    CurveGauge(AM3CRV_GAUGE).claim_rewards()

    token: address = ZERO_ADDRESS
    user_balance: uint256 = self.balanceOf[_user]
    for i in range(MAX_REWARDS):
        token = self.reward_tokens[i]
        if token == ZERO_ADDRESS:
            break
        if token == CRV:
            self._checkpoint_reward(token, _user, user_balance, _total_supply, _claim, True, _user)
        else:
            # non CRV rewards are all given to the ZERO_ADDRESS and received by the harvester
            self._checkpoint_reward(token, ZERO_ADDRESS, 10 ** 18, 10 ** 18, _claim, True, self.harvester)

    self.last_checkpoint = block.timestamp


@internal
def _burn(_from: address, _value: uint256) -> bool:
    self._checkpoint_rewards(_from, self.totalSupply, False)
    self.balanceOf[_from] -= _value
    self.totalSupply -= _value
    log Transfer(_from, ZERO_ADDRESS, _value)
    return True


@internal
def _mint(_to: address, _value: uint256) -> bool:
    self._checkpoint_rewards(_to, self.totalSupply, False)
    self.balanceOf[_to] += _value
    self.totalSupply += _value
    log Transfer(ZERO_ADDRESS, _to, _value)
    return True


@internal
def _transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    assert ZERO_ADDRESS not in [_from, _to]  # dev: disallowed
    total_supply: uint256 = self.totalSupply

    self._checkpoint_rewards(_from, total_supply, False)
    self.balanceOf[_from] -= _value  # dev: insufficient balance

    self._checkpoint_rewards(_to, total_supply, False)
    self.balanceOf[_to] += _value

    log Transfer(_from, _to, _value)
    return True


@external
def approve(_spender: address, _value: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True


@external
def transfer(_to: address, _value: uint256) -> bool:
    return self._transferFrom(msg.sender, _to, _value)


@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    self.allowance[_from][msg.sender] -= _value  # dev: insufficient approval
    return self._transferFrom(_from, _to, _value)


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
@nonreentrant("lock")
def deposit_gauge_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV_GAUGE).transferFrom(msg.sender, self, _value)  # dev: bad response
    self._mint(msg.sender, mint_amount)
    log Deposit(msg.sender, _value)
    return mint_amount


@external
@nonreentrant("lock")
def deposit_lp_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV).transferFrom(msg.sender, self, _value)  # dev: bad response
    CurveGauge(AM3CRV_GAUGE).deposit(_value, self, False)
    self._mint(msg.sender, mint_amount)
    log Deposit(msg.sender, _value)
    return mint_amount


@external
@nonreentrant("lock")
def deposit_coins(_amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool, _min_shares: uint256) -> uint256:
    amount: uint256 = 0
    for i in range(N_COINS):
        amount = _amounts[i]
        if amount == 0:
            continue

        if _use_underlying:
            assert ERC20(self.underlying_coins[i]).transferFrom(msg.sender, self, amount)  # dev: bad response
        else:
            assert ERC20(self.coins[i]).transferFrom(msg.sender, self, amount)  # dev: bad response

    value: uint256 = CurvePool(AM3POOL).add_liquidity(_amounts, _min_mint_amount, _use_underlying)  # dev: bad response
    mint_amount: uint256 = self._calc_mint_shares(value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    CurveGauge(AM3CRV_GAUGE).deposit(value, self, False)
    self._mint(msg.sender, mint_amount)
    log Deposit(msg.sender, value)
    return mint_amount


@external
@nonreentrant("lock")
def withdraw_gauge_tokens(_value: uint256) -> uint256:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    assert ERC20(AM3CRV_GAUGE).transfer(msg.sender, amount)
    log Withdraw(msg.sender, amount)
    return amount


@external
@nonreentrant("lock")
def withdraw_lp_tokens(_value: uint256) -> uint256:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    assert ERC20(AM3CRV).transfer(msg.sender, amount)
    log Withdraw(msg.sender, amount)
    return amount


@external
@nonreentrant("lock")
def withdraw_coins(_value: uint256, _min_amounts: uint256[N_COINS], _use_underlying: bool) -> uint256[N_COINS]:
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    CurvePool(AM3POOL).remove_liquidity(amount, _min_amounts, _use_underlying)

    coin: address = ZERO_ADDRESS
    coin_balance: uint256 = 0
    coin_amounts: uint256[N_COINS] = empty(uint256[N_COINS])
    for i in range(N_COINS):
        if _use_underlying:
            coin = self.underlying_coins[i]
        else:
            coin = self.coins[i]
        coin_balance = ERC20(coin).balanceOf(self)
        coin_amounts[i] = coin_balance
        assert ERC20(coin).transfer(msg.sender, coin_balance)
    log Withdraw(msg.sender, amount)
    return coin_amounts


@external
@nonreentrant("lock")
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
    coin_balance: uint256 = 0
    for i in range(N_COINS):
        if _use_underlying:
            coin = self.underlying_coins[i]
        else:
            coin = self.coins[i]
        coin_balance = ERC20(coin).balanceOf(self)
        if coin_balance > 0:
            assert ERC20(coin).transfer(msg.sender, coin_balance)  # dev: bad response
    log Withdraw(msg.sender, lp_burned)
    return lp_burned


@external
@nonreentrant("lock")
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
    assert ERC20(coin).transfer(msg.sender, coin_balance)  # dev: bad response

    log Withdraw(msg.sender, amount)
    return coin_balance


@external
@nonreentrant("lock")
def withdraw_admin_fees():
    assert msg.sender == self.owner
    token: address = ZERO_ADDRESS
    amount: uint256 = 0
    for i in range(MAX_REWARDS):
        token = self.reward_tokens[i]
        if token == ZERO_ADDRESS:
            break
        amount = self.admin_balances[token]
        if amount > 0:
            self.admin_balances[token] = 0
            self.reward_balances[token] -= amount
            assert ERC20(token).transfer(self.owner, amount)  # dev: bad response


@external
def update_reward_tokens():
    for i in range(MAX_REWARDS):
        reward_token: address = CurveGauge(AM3CRV_GAUGE).reward_tokens(i)
        if reward_token == ZERO_ADDRESS:
            break
        self.reward_tokens[i] = reward_token


@external
@nonreentrant("lock")
def claimable_reward_write(_addr: address, _token: address) -> uint256:
    self._checkpoint_rewards(_addr, self.totalSupply, False)
    return shift(self.claim_data[_addr][_token], -128)


@view
@external
def claimed_reward(_addr: address, _token: address) -> uint256:
    return self.claim_data[_addr][_token] % 2**128


@view
@external
def claimable_reward(_addr: address, _token: address) -> uint256:
    return shift(self.claim_data[_addr][_token], -128)


@external
@nonreentrant("lock")
def harvest():
    assert msg.sender == self.harvester  # dev: only harvester
    self._checkpoint_rewards(ZERO_ADDRESS, 0, True)


@external
def commit_transfer_ownership(_owner: address):
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = _owner


@external
def accept_transfer_ownership():
    owner: address = self.future_owner
    assert msg.sender == owner  # dev: only future owner
    self.owner = owner


@external
def revert_transfer_ownership():
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = ZERO_ADDRESS


@external
def set_harvester(_harvester: address):
    assert msg.sender == self.owner  # dev: only owner
    self.harvester = _harvester


@external
def set_admin_fee(_fee: uint256):
    assert msg.sender == self.owner  # dev: only owner
    assert _fee <= FEE_DENOMINATOR
    self.admin_fee = _fee
