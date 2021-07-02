# @version 0.2.12
"""
@title Bird Protocol Token
@license MIT
@author Ether Pigeon
@dev Follows the standard ERC-20 specification
"""


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
minter: public(address)
owner: public(address)


@external
def __init__():
    self.minter = msg.sender
    self.owner = msg.sender

    self.name = "Guano"
    self.symbol = "GUA"
    self.decimals = 18


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
def mint(_to: address, _value: uint256) -> bool:
    assert msg.sender == self.minter  # dev: only minter
    self.balanceOf[_to] += _value
    self.totalSupply += _value
    log Transfer(ZERO_ADDRESS, _to, _value)
    return True


@external
def set_minter(_minter: address) -> bool:
    assert msg.sender == self.owner  # dev: only owner
    self.minter = _minter
    return True


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
