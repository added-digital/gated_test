"""BROKEN ON PURPOSE: a floor whose walking surface sits 5 cm above z = 0. Must fail floor_top_at_zero."""
from sakura_kit.contract import Piece, GRID

MUST_FAIL = "floor_top_at_zero"


def build():
    p = Piece("sakura_floor_offset", "floor")
    p.box((GRID, GRID, 0.1), at=(0, 0, -0.05), color="moss")
    return p.finish()
