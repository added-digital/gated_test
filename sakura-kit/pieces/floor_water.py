"""Pond water tile: a 1 x 1 m stone basin whose water surface lies 0.20 m below the walking plane, the coping's stone_dark inner wall showing as a bank above it, a thin water_deep band darkening the water against that wall, and a 1 cm stone_dark coping lip at z = 0 along all four edges so neighbouring tiles join into one gridded pond. The slab hangs to -0.30 (FLOOR_T_MAX), the one floor deeper than FLOOR_T: at 2 cm the walk found "no height difference between water and the things around" (breaks.md 2026-10-21)."""
from mathutils import Vector

from sakura_kit.contract import Piece, FLOOR_T_MAX, GRID

COPING_W = 0.01   # stone lip width; two tiles side by side make a 2 cm line
WATER_Z = -0.20   # water surface, sunk below the walking plane
SLAB_Z = -FLOOR_T_MAX   # the basin's underside: 0.10 of stone under the water
RIM_W = 0.06      # water_deep band just inside the coping


def _loop(p, half, z):
    """Four verts of a square of half-size `half` at height z, CCW from above."""
    return [p.bm.verts.new(Vector((sx * half, sy * half, z)))
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def _ring(p, a, b, color):
    """Four quads joining loop `a` to loop `b` (same vertex order)."""
    faces = [p.bm.faces.new([a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]]) for i in range(4)]
    return p.paint(faces, color)


def build():
    p = Piece("sakura_floor_water", "floor", walkable=False)   # a character may not stand on the pond
    # One closed shell, 18 quads: a slab with a stepped recess. Built by hand
    # so the coping, its inner wall, the rim band and the water surface share
    # edges instead of being five overlapping boxes (which would be 60 tris).
    half = GRID / 2
    outer_bottom = _loop(p, half, SLAB_Z)
    outer_top = _loop(p, half, 0.0)
    lip = _loop(p, half - COPING_W, 0.0)
    lip_foot = _loop(p, half - COPING_W, WATER_Z)
    rim_inner = _loop(p, half - COPING_W - RIM_W, WATER_Z)

    p.paint([p.bm.faces.new(list(reversed(outer_bottom)))], "stone_dark")  # underside
    _ring(p, outer_bottom, outer_top, "stone_dark")   # outer walls of the basin
    _ring(p, outer_top, lip, "stone_dark")            # coping top, the walking edge at z = 0
    _ring(p, lip, lip_foot, "stone_dark")             # coping inner wall, down to the water
    _ring(p, lip_foot, rim_inner, "water_deep")       # deep band where water meets stone
    p.paint([p.bm.faces.new(rim_inner)], "water")     # open water surface
    return p.finish()
