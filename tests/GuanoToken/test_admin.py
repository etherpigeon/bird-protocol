import brownie
from brownie import ZERO_ADDRESS


def test_set_minter(alice, bob, chain, guano):
    guano.set_minter(bob, {"from": alice})
    assert guano.minter(block_identifier=chain.height - 1) == alice
    assert guano.minter() == bob


def test_set_minter_only_owner(bob, guano):
    with brownie.reverts("dev: only owner"):
        guano.set_minter(bob, {"from": bob})


def test_commit_ownership_transfer(alice, bob, chain, guano):
    guano.commit_transfer_ownership(bob, {"from": alice})
    assert guano.future_owner(block_identifier=chain.height - 1) == ZERO_ADDRESS
    assert guano.future_owner() == bob


def test_only_owner_commit_ownership_transfer(bob, guano):
    with brownie.reverts("dev: only owner"):
        guano.commit_transfer_ownership(bob, {"from": bob})


def test_accept_ownership_transfer(alice, bob, chain, guano):
    guano.commit_transfer_ownership(bob, {"from": alice})
    guano.accept_transfer_ownership({"from": bob})
    assert guano.owner(block_identifier=chain.height - 1) == alice
    assert guano.owner() == bob
    assert guano.future_owner() == ZERO_ADDRESS


def test_only_future_owner_accept_ownership_transfer(alice, bob, charlie, guano):
    guano.commit_transfer_ownership(bob, {"from": alice})
    with brownie.reverts("dev: only future owner"):
        guano.accept_transfer_ownership({"from": charlie})


def test_revert_ownership_transfer(alice, bob, chain, guano):
    guano.commit_transfer_ownership(bob, {"from": alice})
    guano.revert_transfer_ownership({"from": alice})
    assert guano.future_owner(block_identifier=chain.height - 1) == bob
    assert guano.future_owner() == ZERO_ADDRESS
    assert guano.owner() == alice


def test_only_owner_revert_ownership_transfer(alice, bob, charlie, guano):
    guano.commit_transfer_ownership(bob, {"from": alice})
    with brownie.reverts("dev: only owner"):
        guano.revert_transfer_ownership({"from": charlie})
