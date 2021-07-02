import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def setup(alice, bob, guano):
    guano.approve(bob, 10 ** 18, {"from": alice})
    guano.mint(alice, 10 ** 21, {"from": alice})


def test_modify_sender_and_recipient_balances(alice, bob, chain, guano):
    guano.transferFrom(alice, bob, 10 ** 18, {"from": bob})
    assert guano.balanceOf(bob, block_identifier=chain.height - 1) == 0
    assert guano.balanceOf(alice) == 999 * 10 ** 18
    assert guano.balanceOf(bob) == 10 ** 18


def test_reduce_allowance(alice, bob, guano):
    guano.transferFrom(alice, bob, 10 ** 18, {"from": bob})
    assert guano.allowance(alice, bob) == 0


def test_log_transfer_event(alice, bob, guano):
    tx = guano.transferFrom(alice, bob, 10 ** 18, {"from": bob})
    expected = dict(_from=alice, _to=bob, _value=10 ** 18)
    assert "Transfer" in tx.events
    assert tx.events["Transfer"] == expected


def test_return_value(alice, bob, guano):
    tx = guano.transferFrom(alice, bob, 10 ** 18, {"from": bob})
    assert tx.return_value is True


def test_sender_insufficient_allowance(alice, bob, guano):
    with brownie.reverts("Integer underflow"):
        guano.transferFrom(alice, bob, 10 ** 21, {"from": bob})
