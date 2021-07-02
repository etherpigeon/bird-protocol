import brownie
from brownie import ZERO_ADDRESS


def test_increase_total_supply(alice, guano):
    guano.mint(alice, 10 ** 18, {"from": alice})
    assert guano.totalSupply() == 10 ** 18


def test_increase_user_balance(alice, chain, guano):
    guano.mint(alice, 10 ** 18, {"from": alice})
    assert guano.balanceOf(alice, block_identifier=chain.height - 1) == 0
    assert guano.balanceOf(alice) == 10 ** 18


def test_log_transfer_event(alice, guano):
    tx = guano.mint(alice, 10 ** 18, {"from": alice})
    expected = dict(_from=ZERO_ADDRESS, _to=alice, _value=10 ** 18)
    assert "Transfer" in tx.events
    assert tx.events["Transfer"] == expected


def test_return_value(alice, guano):
    tx = guano.mint(alice, 10 ** 18, {"from": alice})
    assert tx.return_value is True


def test_only_minter(charlie, guano):
    with brownie.reverts("dev: only minter"):
        guano.mint(charlie, 10 ** 18, {"from": charlie})
