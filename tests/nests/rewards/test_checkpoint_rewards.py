import pytest
from brownie import ZERO_ADDRESS

mint_actions = [
    ["deposit_gauge_tokens", 100 * 10**18, 0],
    ["deposit_lp_tokens", 100 * 10**18, 0],
    ["deposit_coins", [100 * 10**p for p in (18, 6, 6)], 0, True, 0],
    ["deposit_coins", [100 * 10**p for p in (18, 6, 6)], 0, False, 0],
]


@pytest.mark.parametrize("mint_action", mint_actions)
def test_checkpoint_on_mint(alice, am3crv_nest, crv, wmatic, reward_tokens, mint_action):
    assert max([token.balanceOf(am3crv_nest) for token in reward_tokens]) == 0

    getattr(am3crv_nest, mint_action.pop(0))(*mint_action, {"from": alice})

    for token in reward_tokens:
        # rewards have been transferred in
        assert token.balanceOf(am3crv_nest) > 0

    # alice + bob were checkpointed prior to the transfer
    assert am3crv_nest.claimable_reward(alice, crv) > 0
    assert am3crv_nest.claimable_reward(alice, wmatic) == 0

    # harvester (ZERO_ADDRESS) claims rewards not CRV
    assert am3crv_nest.claimable_reward(ZERO_ADDRESS, wmatic) > 0


burn_actions = [
    ["withdraw_gauge_tokens", 100 * 10**18],
    ["withdraw_lp_tokens", 100 * 10**18],
    ["withdraw_coins", 100 * 10**18, [0, 0, 0], True],
    ["withdraw_coins", 100 * 10**18, [0, 0, 0], False],
    [
        "withdraw_coins_imbalance",
        [100 * 10**18, 50 * 10**6, 25 * 10**6],
        1000 * 10**18,
        True,
    ],
    [
        "withdraw_coins_imbalance",
        [100 * 10**18, 50 * 10**6, 25 * 10**6],
        1000 * 10**18,
        False,
    ],
    ["withdraw_coins_single", 100 * 10**18, 0, 0, True],
    ["withdraw_coins_single", 100 * 10**18, 0, 0, False],
    ["withdraw_coins_single", 100 * 10**18, 1, 0, True],
    ["withdraw_coins_single", 100 * 10**18, 1, 0, False],
    ["withdraw_coins_single", 100 * 10**18, 2, 0, True],
    ["withdraw_coins_single", 100 * 10**18, 2, 0, False],
]


@pytest.mark.parametrize("burn_action", burn_actions)
def test_checkpoint_on_burn(alice, am3crv_nest, crv, wmatic, reward_tokens, burn_action):
    assert max([token.balanceOf(am3crv_nest) for token in reward_tokens]) == 0

    getattr(am3crv_nest, burn_action.pop(0))(*burn_action, {"from": alice})

    for token in reward_tokens:
        # rewards have been transferred in
        assert token.balanceOf(am3crv_nest) > 0

    assert am3crv_nest.claimable_reward(alice, crv) > 0
    assert am3crv_nest.claimable_reward(alice, wmatic) == 0

    # harvester (ZERO_ADDRESS) claims rewards not CRV
    assert am3crv_nest.claimable_reward(ZERO_ADDRESS, wmatic) > 0


def test_checkpoint_on_transfer(alice, bob, am3crv_nest, crv, wmatic, reward_tokens):
    assert max([token.balanceOf(am3crv_nest) for token in reward_tokens]) == 0

    am3crv_nest.transfer(bob, 1000 * 10**18, {"from": alice})

    for token in reward_tokens:
        # rewards have been transferred in
        assert token.balanceOf(am3crv_nest) > 0

    # alice + bob were checkpointed prior to the transfer
    assert am3crv_nest.claimable_reward(alice, crv) > 0
    assert am3crv_nest.claimable_reward(bob, crv) == 0
    for user in (alice, bob):
        assert am3crv_nest.claimable_reward(user, wmatic) == 0

    # harvester (ZERO_ADDRESS) claims rewards not CRV
    assert am3crv_nest.claimable_reward(ZERO_ADDRESS, wmatic) > 0


def test_checkpoint_user(alice, am3crv_nest, crv, wmatic, reward_tokens):
    assert max([token.balanceOf(am3crv_nest) for token in reward_tokens]) == 0

    am3crv_nest.claimable_reward_write(alice, ZERO_ADDRESS)

    for token in reward_tokens:
        # rewards have been transferred in
        assert token.balanceOf(am3crv_nest) > 0

    assert am3crv_nest.claimable_reward(alice, crv) > 0
    assert am3crv_nest.claimable_reward(alice, wmatic) == 0

    # harvester (ZERO_ADDRESS) claims rewards not CRV
    assert am3crv_nest.claimable_reward(ZERO_ADDRESS, wmatic) > 0


def test_claimable_rewards_increase(alice, am3crv_nest, crv, wmatic, reward_tokens):
    am3crv_nest.claimable_reward_write(alice, ZERO_ADDRESS, {"from": alice})

    for token in reward_tokens:
        assert token.balanceOf(am3crv_nest) > 0
    assert am3crv_nest.claimable_reward(alice, crv) > 0
    assert am3crv_nest.claimable_reward(alice, wmatic) == 0
