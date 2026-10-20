"""BROKEN ON PURPOSE: a prop left with an unapplied scale. Must fail transforms_applied."""
from sakura_kit.contract import Piece

MUST_FAIL = "transforms_applied"


def build():
    p = Piece("sakura_prop_scaled", "prop")
    p.box((0.4, 0.4, 0.4), color="wood")
    obj = p.finish()
    obj.scale = (1.2, 1.2, 1.2)
    return obj
