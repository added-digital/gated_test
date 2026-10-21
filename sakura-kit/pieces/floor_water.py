"""Pond water tile: a 1 x 1 m sheet of water lying 0.20 m below the walking plane (WATER_Z), the full tile wide with no rim, so neighbouring water tiles meet edge to edge as one sheet; its slab hangs to -0.30 (FLOOR_T_MAX) with stone_dark sides and underside, and the bank is simply the neighbouring tile's slab side. The one floor whose top is not at z = 0: at 2 cm the walk found "no height difference between water and the things around", and with a coping on every edge "pond tiles read as separate ponds" (breaks.md 2026-10-21)."""
from sakura_kit.contract import Piece, FLOOR_T_MAX, GRID, WATER_Z

SLAB_Z = -FLOOR_T_MAX   # the slab's underside: 0.10 m of stone under the water


def build():
    p = Piece("sakura_floor_water", "floor", walkable=False)   # a character may not stand on the pond
    # One closed shell, 6 quads: a slab from SLAB_Z up to WATER_Z whose top face
    # is the water. No coping, no inner wall, no rim band: anything standing
    # above the water on a tile edge becomes a ridge between two water tiles.
    slab = p.box((GRID, GRID, WATER_Z - SLAB_Z), at=(0, 0, SLAB_Z), color="stone_dark")
    p.paint(p.faces_facing(slab, (0, 0, 1)), "water")
    return p.finish()
