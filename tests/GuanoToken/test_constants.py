def test_name(guano):
    assert guano.name() == "Guano"


def test_decimals(guano):
    assert guano.decimals() == 18


def test_symbol(guano):
    assert guano.symbol() == "GUA"
