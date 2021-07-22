import math


def test_claim_crv_rewards(alice, am3crv_nest, crv, wmatic):

    am3crv_nest.claim_rewards(alice, {"from": alice})

    assert crv.balanceOf(alice) > 0
    assert wmatic.balanceOf(alice) == 0
    assert crv.balanceOf(am3crv_nest) == 0  # admin fee is 0%
    assert wmatic.balanceOf(am3crv_nest) > 0  # harvester hasn't claimed


def test_claim_crv_rewards_fee_set(alice, am3crv_nest, crv, wmatic):

    am3crv_nest.set_admin_fee(500, {"from": alice})
    am3crv_nest.claim_rewards(alice, {"from": alice})

    assert crv.balanceOf(alice) > 0
    assert wmatic.balanceOf(alice) == 0
    assert crv.balanceOf(am3crv_nest) > 0  # fee is 5%
    assert wmatic.balanceOf(am3crv_nest) > 0  # harvester hasn't claimed

    assert math.isclose(am3crv_nest.admin_balances(crv), crv.balanceOf(am3crv_nest))
    assert math.isclose(am3crv_nest.admin_balances(wmatic), wmatic.balanceOf(am3crv_nest) * 0.05)


def test_harvester_claims_rewards(alice, bob, am3crv_nest, crv, wmatic):
    am3crv_nest.set_harvester(bob, {"from": alice})
    am3crv_nest.harvest({"from": bob})

    assert crv.balanceOf(bob) == 0  # no harvesting of CRV for rewards
    assert wmatic.balanceOf(bob) > 0
    assert crv.balanceOf(am3crv_nest) > 0  # admin fee is 0%
    assert wmatic.balanceOf(am3crv_nest) == 0  # harvester has claimed and no admin fee


def test_harvester_claims_rewards_fee_set(alice, bob, am3crv_nest, crv, wmatic):
    am3crv_nest.set_admin_fee(500, {"from": alice})
    am3crv_nest.set_harvester(bob, {"from": alice})
    am3crv_nest.harvest({"from": bob})

    assert crv.balanceOf(bob) == 0  # no harvesting of CRV for rewards
    assert wmatic.balanceOf(bob) > 0
    assert crv.balanceOf(am3crv_nest) > 0  # admin fee is 5%
    assert wmatic.balanceOf(am3crv_nest) > 0  # harvester has claimed and there is admin fee


def test_claim_and_harvester_claims_rewards(alice, bob, am3crv_nest, crv, wmatic):
    am3crv_nest.set_harvester(bob, {"from": alice})
    am3crv_nest.claim_rewards(alice, {"from": alice})
    am3crv_nest.harvest({"from": bob})

    assert crv.balanceOf(alice) > 0
    assert wmatic.balanceOf(alice) == 0
    assert crv.balanceOf(bob) == 0  # no harvesting of CRV for rewards
    assert wmatic.balanceOf(bob) > 0

    assert crv.balanceOf(am3crv_nest) == 0
    assert wmatic.balanceOf(am3crv_nest) == 0


def test_claim_and_harvester_claims_rewards_fee_set(alice, bob, am3crv_nest, crv, wmatic):
    am3crv_nest.set_admin_fee(500, {"from": alice})
    am3crv_nest.set_harvester(bob, {"from": alice})
    am3crv_nest.claim_rewards(alice, {"from": alice})
    am3crv_nest.harvest({"from": bob})

    assert crv.balanceOf(alice) > 0
    assert wmatic.balanceOf(alice) == 0
    assert crv.balanceOf(bob) == 0  # no harvesting of CRV for rewards
    assert wmatic.balanceOf(bob) > 0

    assert crv.balanceOf(am3crv_nest) > 0  # admin fee is 5%
    assert wmatic.balanceOf(am3crv_nest) > 0  # harvester has claimed and there is admin fee


def test_claim_and_harvester_claims_rewards_fee_set(alice, bob, charlie, am3crv_nest, crv, wmatic):
    am3crv_nest.set_admin_fee(500, {"from": alice})
    am3crv_nest.set_harvester(bob, {"from": alice})
    am3crv_nest.commit_transfer_ownership(charlie, {"from": alice})
    am3crv_nest.accept_transfer_ownership({"from": charlie})

    am3crv_nest.claim_rewards(alice, {"from": alice})
    am3crv_nest.harvest({"from": bob})
    am3crv_nest.withdraw_admin_fees({"from": charlie})

    assert crv.balanceOf(alice) > 0
    assert wmatic.balanceOf(alice) == 0
    assert crv.balanceOf(bob) == 0  # no harvesting of CRV for rewards
    assert wmatic.balanceOf(bob) > 0
    assert crv.balanceOf(charlie) > 0
    assert wmatic.balanceOf(charlie) > 0

    assert max([am3crv_nest.admin_balances(tok) for tok in (crv, wmatic)]) == 0
