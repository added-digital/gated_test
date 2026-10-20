"""BROKEN ON PURPOSE: a 0.98 m wall on a 1 m grid. Must fail wall_width_exact."""
from sakura_kit.contract import Piece, WALL_H

MUST_FAIL = "wall_width_exact"


def build():
    p = Piece("sakura_wall_short", "wall")
    p.box((0.98, 0.12, WALL_H), color="plaster")
    return p.finish()
