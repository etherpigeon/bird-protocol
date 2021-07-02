def test_set_approval(alice, bob, chain, guano):
    guano.approve(bob, 10 ** 18, {"from": alice})
    assert guano.allowance(alice, bob, block_identifier=chain.height - 1) == 0
    assert guano.allowance(alice, bob) == 10 ** 18


def test_remove_approval(alice, bob, chain, guano):
    guano.approve(bob, 10 ** 18, {"from": alice})
    guano.approve(bob, 0, {"from": alice})
    assert guano.allowance(alice, bob, block_identifier=chain.height - 1) == 10 ** 18
    assert guano.allowance(alice, bob) == 0


def test_nonzero_to_nonzero_approval(alice, bob, chain, guano):
    guano.approve(bob, 10 ** 18, {"from": alice})
    guano.approve(bob, 10 ** 21, {"from": alice})
    assert guano.allowance(alice, bob, block_identifier=chain.height - 1) == 10 ** 18
    assert guano.allowance(alice, bob) == 10 ** 21


def test_return_value(alice, bob, guano):
    tx = guano.approve(bob, 10 ** 18, {"from": alice})
    assert tx.return_value is True


def test_log_approval_event(alice, bob, guano):
    tx = guano.approve(bob, 10 ** 18, {"from": alice})
    expected = dict(_owner=alice, _spender=bob, _value=10 ** 18)
    assert "Approval" in tx.events
    assert tx.events["Approval"] == expected
