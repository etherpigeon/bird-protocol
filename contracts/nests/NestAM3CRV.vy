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
    def deposit(_value: uint256, _addr: address, _claim_rewards: bool): nonpayable
    def withdraw(_value: uint256, _claim_rewards: bool): nonpayable

interface RewardContract:
    def claim_rewards(): nonpayable
    def reward_tokens(arg0: uint256) -> address: view


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

admin_balances: public(HashMap[address, uint256])
admin_fee: public(uint256)

reward_contract: public(address)
additional_rewards: public(address[MAX_REWARDS])


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
        reward_token: address = RewardContract(AM3CRV_GAUGE).reward_tokens(i)
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
    """
    @dev Calculate the amount of am3crv-gauge tokens that are redeemable
    @param _withdraw_value The amount of am3crv-egg tokens to redeem
    @param _total_supply The total supply of am3crv-egg tokens
    @param _current_balance The current balance of am3crv-gauge tokens 
    @return The amount of am3crv-gauge tokens `_withdraw_value` is redeemable for.
    """
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
    """
    @dev Calculate the amount of am3crv-egg tokens mintable
    @param _deposit_value The amount of am3crv-gauge tokens being deposited
    @param _total_supply The total supply of of am3crv-egg tokens
    @param _prev_balance The balance of am3crv-gauge tokens prior to deposit
    @return The amount of am3crv-egg tokens mintable for `_deposit_value` amount of
        am3crv-gauge tokens.
    """
    if _total_supply == 0:
        return _deposit_value
    else:
        shares: uint256 = (_deposit_value * _total_supply) / _prev_balance
        return shares


@internal
def _checkpoint_reward(_token: address, _user: address, _user_balance: uint256, _total_supply: uint256, _claim: bool, _apply_fee: bool, _receiver: address):
    """
    @dev Checkpoint a reward, updating the claim amount as well as taking a fee
    @param _token The token to checkpoint
    @param _user The user which is being checkpointed
    @param _user_balance The balance of am3crv-egg tokens the user has
    @param _total_supply The total supply of am3crv-egg tokens
    @param _claim Boolean indicating whether to distribute the reward token
    @param _apply_fee Boolean indicating whether to apply the admin fee to the amount
    @param _receiver Address of the recipient if `_claim` is set to True
    """
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
def _checkpoint_rewards(_user: address, _total_supply: uint256, _claim: bool, _caller: address):
    """
    @dev Checkpoint all rewards for a user, including additional incentives
    @param _user The user to checkpoint all rewards for
    @param _total_supply The total supply of am3crv-egg tokens
    @param _claim Boolean indicating whether to claim rewards
    @param _caller Address of the caller of the outer function
    """
    RewardContract(AM3CRV_GAUGE).claim_rewards()

    token: address = ZERO_ADDRESS
    user_balance: uint256 = self.balanceOf[_user]
    harvest_claim: bool = _claim and _caller == self.harvester
    for i in range(MAX_REWARDS):
        token = self.reward_tokens[i]
        if token == ZERO_ADDRESS:
            break
        if token == CRV:
            self._checkpoint_reward(token, _user, user_balance, _total_supply, _claim, True, _user)
        else:
            # non CRV rewards are all given to the ZERO_ADDRESS and received by the harvester
            self._checkpoint_reward(token, ZERO_ADDRESS, 10 ** 18, 10 ** 18, harvest_claim, True, self.harvester)
    
    # additional incentives

    reward_contract: address = self.reward_contract
    if reward_contract != ZERO_ADDRESS:
        RewardContract(reward_contract).claim_rewards()
        
    for i in range(MAX_REWARDS):
        token = self.additional_rewards[i]
        if token == ZERO_ADDRESS:
            break
        # additional rewards aren't charged a fee
        self._checkpoint_reward(token, _user, user_balance, _total_supply, _claim, False, _user)


@internal
def _burn(_from: address, _value: uint256, _caller: address) -> bool:
    """
    @dev Burn am3crv-egg tokens
    @param _from The address to burn tokens from
    @param _value The amount of tokens to burn
    @param _caller The address of the outer function caller
    @return True on success
    """
    self._checkpoint_rewards(_from, self.totalSupply, False, _caller)
    self.balanceOf[_from] -= _value
    self.totalSupply -= _value
    log Transfer(_from, ZERO_ADDRESS, _value)
    return True


@internal
def _mint(_to: address, _value: uint256, _caller: address) -> bool:
    """
    @dev Mint am3crv-egg tokens
    @param _to The address to mint tokens to
    @param _value The amount of tokens to mint
    @param _caller The address of the outer function caller
    @return True on success
    """
    self._checkpoint_rewards(_to, self.totalSupply, False, _caller)
    self.balanceOf[_to] += _value
    self.totalSupply += _value
    log Transfer(ZERO_ADDRESS, _to, _value)
    return True


@internal
def _transferFrom(_from: address, _to: address, _value: uint256, _caller: address) -> bool:
    """
    @dev Transfer am3crv-egg tokens `_from` to `_to`. Utilizes underflow security built into
        vyper to prevent insufficient balance transfers
    @param _from The address to transfer tokens from
    @param _to The address to transfer tokens to
    @return True on success
    """
    assert ZERO_ADDRESS not in [_from, _to]  # dev: disallowed
    total_supply: uint256 = self.totalSupply

    self._checkpoint_rewards(_from, total_supply, False, _caller)
    self.balanceOf[_from] -= _value  # dev: insufficient balance

    self._checkpoint_rewards(_to, total_supply, False, _caller)
    self.balanceOf[_to] += _value

    log Transfer(_from, _to, _value)
    return True


@external
@nonreentrant("lock")
def approve(_spender: address, _value: uint256) -> bool:
    """
    @notice Allows `_spender` to withdraw from your account multiple times, up to the `_value` amount.
        If this function is called again it overwrites the current allowance with _value.
    @dev Non-zero to non-zero approvals are allowed, however to prevent front-running one should perform
        two txs, one to set allowance to 0, then to the preferred allowance.
    @param _spender The address of the party allowed to withdraw from the caller's account
    @param _value The amount allotted to the _spender
    @return True on success
    """
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True


@external
@nonreentrant("lock")
def transfer(_to: address, _value: uint256) -> bool:
    """
    @notice Transfers `_value` amount of tokens to address `_to`
    @param _to The address to send tokens to
    @param _value The amount of tokens to send
    @return True on success
    """
    return self._transferFrom(msg.sender, _to, _value, msg.sender)


@external
@nonreentrant("lock")
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    """
    @notice Used for a withdraw workflow, allowing contracts/third-parties to transfer tokens on your behalf.
        The third party must have a previous approval allowing the transfer of `_value` tokens.
    @param _from The party to withdraw funds from
    @param _to The party to deposit funds to
    @param _value The amount of funds
    @return True on success
    """
    self.allowance[_from][msg.sender] -= _value  # dev: insufficient approval
    return self._transferFrom(_from, _to, _value, msg.sender)


@view
@external
def calc_shares(_value: uint256, _is_deposit: bool) -> uint256:
    """
    @notice Calculate the am3crv-egg tokens mintable for `_value` am3crv-gauge tokens on a deposit.
        Or, calculate the am3crv-gauge tokens redeemable for `_value` am3crv-egg tokens on a withdrawl.
    @param _value The amount being deposited (am3crv-gauge) or withdrawn (am3crv-egg)
    @param _is_deposit Boolean to determine whether to calculate a deposit or withdrawl
    @return The amount of tokens mintable/redeemable
    """
    am3crv_gauge_balance: uint256 = ERC20(AM3CRV_GAUGE).balanceOf(self)
    total_supply: uint256 = self.totalSupply
    if _is_deposit:
        return self._calc_mint_shares(_value, total_supply, am3crv_gauge_balance)
    else:
        return self._calc_burn_shares(_value, total_supply, am3crv_gauge_balance)


@external
@nonreentrant("lock")
def deposit_gauge_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    """
    @notice Deposit am3crv-gauge tokens directly
    @param _value The amount of am3crv-gauge tokens to deposit
    @param _min_shares The minimum amount of am3crv-egg tokens to receive
    @return The minted amount of am3crv-egg tokens
    """
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV_GAUGE).transferFrom(msg.sender, self, _value)  # dev: bad response
    self._mint(msg.sender, mint_amount, msg.sender)
    log Deposit(msg.sender, _value)
    return mint_amount


@external
@nonreentrant("lock")
def deposit_lp_tokens(_value: uint256, _min_shares: uint256) -> uint256:
    """
    @notice Deposit am3crv tokens, which are automatically staked in the am3crv gauge
    @dev am3crv and am3crv-gauge tokens are 1:1 redeemable/mintable
    @param _value The amount of am3crv lp tokens to deposit
    @param _min_shares The minimum amount of am3crv-egg tokens to receive
    """
    mint_amount: uint256 = self._calc_mint_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    assert mint_amount >= _min_shares  # dev: slippage
    assert ERC20(AM3CRV).transferFrom(msg.sender, self, _value)  # dev: bad response
    CurveGauge(AM3CRV_GAUGE).deposit(_value, self, False)
    self._mint(msg.sender, mint_amount, msg.sender)
    log Deposit(msg.sender, _value)
    return mint_amount


@external
@nonreentrant("lock")
def deposit_coins(_amounts: uint256[N_COINS], _min_mint_amount: uint256, _use_underlying: bool, _min_shares: uint256) -> uint256:
    """
    @notice Deposit coins/underlying coins which are automatically deposited into the underlying pool for lp tokens and then staked
    @param _amounts The amounts of the base coins to deposit
    @param _min_mint_amount The minimum amount of am3crv lp tokens to be minted from the base pool (See am3pool.calc_token_amount)
    @param _use_underlying Boolean identifying whether to use underlying coins or atokens
    @param _min_shares The minimum amount of am3crv-egg tokens to receive
    @return The amount of minted am3crv-egg tokens
    """
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
    self._mint(msg.sender, mint_amount, msg.sender)
    log Deposit(msg.sender, value)
    return mint_amount


@external
@nonreentrant("lock")
def withdraw_gauge_tokens(_value: uint256) -> uint256:
    """
    @notice Withdraw the gauge tokens underlying the am3crv-egg tokens
    @param _value The amount of am3crv-egg tokens to redeem for am3crv-gauge tokens
    @return The amount of am3crv-gauge tokens withdrawn
    """
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value, msg.sender)
    assert ERC20(AM3CRV_GAUGE).transfer(msg.sender, amount)
    log Withdraw(msg.sender, amount)
    return amount


@external
@nonreentrant("lock")
def withdraw_lp_tokens(_value: uint256) -> uint256:
    """
    @notice Withdraw the underlying am3crv lp token
    @param _value The amount of am3crv-egg tokens to redeem for am3crv tokens
    @return The amount of redeemed am3crv tokens
    """
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value, msg.sender)
    CurveGauge(AM3CRV_GAUGE).withdraw(amount, False)
    assert ERC20(AM3CRV).transfer(msg.sender, amount)
    log Withdraw(msg.sender, amount)
    return amount


@external
@nonreentrant("lock")
def withdraw_coins(_value: uint256, _min_amounts: uint256[N_COINS], _use_underlying: bool) -> uint256[N_COINS]:
    """
    @notice Withdraw coins from the base pool in a balanced manner
    @param _value amount of am3crv-egg tokens to redeem
    @param _min_amounts The minimum amount of coins to receive from removing liquidity
    @param _use_underlying Boolean indicating whether to withdraw base coins or atokens
    @return Array of coins redeemed
    """
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value, msg.sender)
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
    """
    @notice Withdraw underlying coins from pool in imbalanced fashion
    @dev This method requires first the burning of _max_burn_amount tokens, and then the minting of any leftover lp tokens
    @param _amounts The amount of coins to redeem for
    @param _max_burn_amount The maximum amount of am3crv-egg tokens to burn in the process
    @param _use_underlying Boolean indicating whether to return underlying coins or atokens
    @return The amount of am3crv tokens burned in the process
    """
    max_lp_burn: uint256 = self._calc_burn_shares(_max_burn_amount, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _max_burn_amount, msg.sender)
    CurveGauge(AM3CRV_GAUGE).withdraw(max_lp_burn, False)
    lp_burned: uint256 = CurvePool(AM3POOL).remove_liquidity_imbalance(_amounts, max_lp_burn, _use_underlying)

    lp_remainder: uint256 = max_lp_burn - lp_burned
    if lp_remainder > 0:
        mint_amount: uint256 = self._calc_mint_shares(lp_remainder, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
        self._mint(msg.sender, mint_amount, msg.sender)
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
    """
    @notice Withdrwa _value into a single coin
    @param _value The amount of am3crv-egg tokens to redeem
    @param _i The index of the coin in the base pool to redeem for
    @param _min_amount The minimum amount of the `_i`th coin to receive
    @param _use_underlying Boolean indicating whether to receive underlying or atoken
    @return The amount of coin received in the process
    """
    amount: uint256 = self._calc_burn_shares(_value, self.totalSupply, ERC20(AM3CRV_GAUGE).balanceOf(self))
    self._burn(msg.sender, _value, msg.sender)
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
    """
    @notice Withdraw admin fees, only callable by owner
    """
    assert msg.sender == self.owner
    token: address = ZERO_ADDRESS
    amount: uint256 = 0
    for i in range(MAX_REWARDS):
        token = self.reward_tokens[i]
        if token == ZERO_ADDRESS:
            break
        amount = self.admin_balances[token]
        if amount == 0:
            continue
        self.admin_balances[token] = 0
        self.reward_balances[token] -= amount
        assert ERC20(token).transfer(self.owner, amount)  # dev: bad response


@external
@nonreentrant("lock")
def set_reward_contract(_reward_contract: address):
    """
    @notice Set the reward contract for addtional rewards
    @param _reward_contract The address of the `_reward_contract`, which must be a contract
    """
    assert msg.sender == self.owner  # dev: only owner
    assert _reward_contract.is_contract
    self._checkpoint_rewards(ZERO_ADDRESS, self.totalSupply, False, msg.sender)
    self.reward_contract = _reward_contract


@external
@nonreentrant("lock")
def update_rewards():
    """
    @notice Update the reward tokens stored/cached
    """
    base_rewards: address[MAX_REWARDS] = empty(address[MAX_REWARDS])
    reward_token: address = ZERO_ADDRESS
    for i in range(MAX_REWARDS):
        reward_token = RewardContract(AM3CRV_GAUGE).reward_tokens(i)
        if reward_token == ZERO_ADDRESS:
            break
        self.reward_tokens[i] = reward_token
        base_rewards[i] = reward_token

    reward_contract: address = self.reward_contract
    if reward_contract != ZERO_ADDRESS:
        return

    stored_reward: address = ZERO_ADDRESS
    for i in range(MAX_REWARDS):
        reward_token = RewardContract(reward_contract).reward_tokens(i)
        stored_reward = self.additional_rewards[i]
        if reward_token == stored_reward:
            if reward_token == ZERO_ADDRESS:
                break
        else:
            assert stored_reward == ZERO_ADDRESS  # dev: cannot overwrite a reward
            assert reward_token not in base_rewards  # dev: duplicate reward
            self.additional_rewards[i] = reward_token


@external
@nonreentrant("lock")
def claim_rewards(_addr: address = msg.sender) -> bool:
    """
    @notice Claim pending rewards less any applicable fees
    @dev Claiming for another account sends the rewards directly to that account
    @param _addr The account to claim for
    @return True on success
    """
    self._checkpoint_rewards(_addr, self.totalSupply, True, msg.sender)
    return True


@external
@nonreentrant("lock")
def claimable_reward_write(_addr: address, _token: address) -> uint256:
    """
    @notice Get the number of claimable reward tokens for a user
    @dev This function should be manually changed to "view" in the ABI
        Calling it via a transaction will not claim available reward tokens
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Claimable reward token amount
    """
    self._checkpoint_rewards(_addr, self.totalSupply, False, msg.sender)
    return shift(self.claim_data[_addr][_token], -128)


@view
@external
def claimed_reward(_addr: address, _token: address) -> uint256:
    """
    @notice Get the number of already-claimed reward tokens for a user
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Total amount of `_token` already claimed by `_addr`
    """
    return self.claim_data[_addr][_token] % 2**128


@view
@external
def claimable_reward(_addr: address, _token: address) -> uint256:
    """
    @notice Get the number of claimable reward tokens for a user
    @dev This call does not consider pending claimable amount in `reward_contract`.
        Off-chain callers should instead use `claimable_rewards_write` as a
        view method.
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Claimable reward token amount
    """
    return shift(self.claim_data[_addr][_token], -128)


@external
@nonreentrant("lock")
def harvest():
    """
    @notice Harvest extra reward tokens for dumping and reinvesting as am3crv-gauge tokens 
    @dev Only callable by harvester which is by default ZERO_ADDRESS
    """
    assert msg.sender == self.harvester  # dev: only harvester
    self._checkpoint_rewards(ZERO_ADDRESS, self.totalSupply, True, msg.sender)



@external
def commit_transfer_ownership(_owner: address):
    """
    @notice Commit transfer of ownership, has to be accepted by future owner
    @param _owner The address to transfer ownership to
    """
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = _owner


@external
def accept_transfer_ownership():
    """
    @notice Accept transfer of ownership. Only callable by the future owner
    """
    owner: address = self.future_owner
    assert msg.sender == owner  # dev: only future owner
    self.owner = owner


@external
def revert_transfer_ownership():
    """
    @notice Revert a commit of ownership transfer, setting future owner to
        ZERO_ADDRESS, thereby nullifying it.
    """
    assert msg.sender == self.owner  # dev: only owner
    self.future_owner = ZERO_ADDRESS


@external
def set_harvester(_harvester: address):
    """
    @notice Set the harvester, which claims the extra reward tokens
    @param _harvester The address of the harvester
    """
    assert msg.sender == self.owner  # dev: only owner
    self.harvester = _harvester


@external
def set_admin_fee(_fee: uint256):
    """
    @notice Set the admin fee
    @param _fee The numerator for the fee, denominator is 10_000
    """
    assert msg.sender == self.owner  # dev: only owner
    assert _fee <= FEE_DENOMINATOR
    self.admin_fee = _fee
