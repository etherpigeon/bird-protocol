import brownie


def test_burn_shares(alice, am3crv, am3crv_gauge, am3crv_nest):
    am3crv_nest.withdraw_lp_tokens(100 * 10 ** 18, {"from": alice})

    assert am3crv.balanceOf(alice) == 100 * 10 ** 18
    assert am3crv_gauge.balanceOf(am3crv_nest) == 0


def test_nest_grows_withdraw_amount(alice, am3crv, am3crv_gauge, am3crv_nest):
    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)
    am3crv_nest.withdraw_lp_tokens(100 * 10 ** 18, {"from": alice})

    assert am3crv.balanceOf(alice) == 200 * 10 ** 18
    assert am3crv_gauge.balanceOf(am3crv_nest) == 0


def test_multiple_depositors_withdraw(alice, bob, am3crv, am3crv_gauge, am3crv_nest):

    # nest balance grows
    am3crv_gauge._mint_for_testing(am3crv_nest, 100 * 10 ** 18)

    # bob deposits
    am3crv._mint_for_testing(bob, 100 * 10 ** 18)
    am3crv.approve(am3crv_nest, 100 * 10 ** 18, {"from": bob})
    am3crv_nest.deposit_lp_tokens(100 * 10 ** 18, 50 * 10 ** 18, {"from": bob})  # 50 * 10 ** 18

    # alice and bob withdraw
    am3crv_nest.withdraw_lp_tokens(100 * 10 ** 18, {"from": alice})
    am3crv_nest.withdraw_lp_tokens(50 * 10 ** 18, {"from": bob})

    assert am3crv_gauge.balanceOf(am3crv_nest) == 0
    assert am3crv.balanceOf(alice) == 200 * 10 ** 18
    assert am3crv.balanceOf(bob) == 100 * 10 ** 18


def test_invalid_value_revert(alice, am3crv_nest):
    with brownie.reverts():
        am3crv_nest.withdraw_lp_tokens(100 * 10 ** 18 + 1, {"from": alice})
