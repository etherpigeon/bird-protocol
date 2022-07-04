import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, guano):
    guano.mint(alice, 10**18, {"from": alice})


def test_modify_sender_and_recipient_balances(alice, bob, chain, guano):
    guano.transfer(bob, 10**18, {"from": alice})
    assert guano.balanceOf(bob, block_identifier=chain.height - 1) == 0
    assert guano.balanceOf(alice) == 0
    assert guano.balanceOf(bob) == 10**18


def test_log_transfer_event(alice, bob, guano):
    tx = guano.transfer(bob, 10**18, {"from": alice})
    expected = dict(_from=alice, _to=bob, _value=10**18)
    assert "Transfer" in tx.events
    assert tx.events["Transfer"] == expected


def test_return_value(alice, bob, guano):
    tx = guano.transfer(bob, 10**18, {"from": alice})
    assert tx.return_value is True


def test_sender_insufficient_balance(alice, bob, guano):
    with brownie.reverts("Integer underflow"):
        guano.transfer(bob, 10**21, {"from": alice})
