"""Tobi-ishi stepping-stone tile: a 1 x 1 m moss slab (top at z = 0) carrying three irregular flat stones, 1.5 cm thick, laid corner to corner on the SW-NE diagonal so rotated copies chain into a winding path. Three open-bottomed stone prisms (13 + 16 + 13 tris) on a closed 12-tri slab: 54 tris, inside the 64-tri floor budget."""
import math

import bmesh

from sakura_kit.contract import Piece, FLOOR_T, GRID

STONE_H = 0.015  # stone thickness above the moss (contract allows <= 0.02)

# Each stone: centre on the tile, then its rim as (angle in degrees, radius)
# pairs in counter-clockwise order. All hand-picked, so the tile is deterministic.
STONES = (
    # near the SW corner, 5 points
    dict(at=(-0.30, -0.27), top="stone",
         rim=((10, 0.17), (85, 0.15), (160, 0.16), (230, 0.14), (300, 0.17))),
    # centre, the largest, 6 points
    dict(at=(0.02, -0.01), top="stone_dark",
         rim=((0, 0.18), (55, 0.16), (120, 0.18), (180, 0.17), (235, 0.15), (300, 0.18))),
    # near the NE corner, 5 points
    dict(at=(0.29, 0.30), top="stone",
         rim=((30, 0.15), (100, 0.17), (170, 0.15), (250, 0.16), (320, 0.14))),
)


def _stone(p, at, rim, top_color, side_color="stone_dark"):
    """One flat stone: a prism (its caps come as triangle fans from the Piece
    API) whose bottom, hidden against the moss, is dropped."""
    pts = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a, r in rim]
    faces = p.prism(pts, STONE_H, at=(at[0], at[1], 0.0), color=side_color)
    bottom = p.faces_facing(faces, (0, 0, -1))
    bmesh.ops.delete(p.bm, geom=bottom, context="FACES")
    p.paint(p.faces_facing([f for f in faces if f.is_valid], (0, 0, 1)), top_color)


def build():
    p = Piece("sakura_floor_stone_path", "floor")
    # The moss bed: walking surface at z = 0, hanging FLOOR_T below; earthy sides and bottom.
    slab = p.box((GRID, GRID, FLOOR_T), at=(0, 0, -FLOOR_T), color="moss_dark")
    p.paint(p.faces_facing(slab, (0, 0, 1)), "moss")
    for s in STONES:
        _stone(p, s["at"], s["rim"], s["top"])
    return p.finish()
