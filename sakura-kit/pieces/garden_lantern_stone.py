"""Ishidoro, a granite garden lantern 1.6 m tall on a 0.6 m square base: two-step base, six-sided shaft with a mid band and collars, flared square platform, cubic light box open on all four sides over a pale paper core, square pyramid roof on a flared eave, and a lotus-cup finial carrying the small jewel sphere (hoju)."""
import math

import bmesh

from sakura_kit.contract import Piece

SINK = 0.005        # each part sinks this far into the one below it, so nothing floats
                    # and no two faces of different shells are coplanar
SQ = math.sqrt(2)   # 4-segment cylinders are diamonds; rotated 45 deg, radius = half-side * SQ

# Base (kidan): two square steps, the lower one the full 0.6 m footprint.
BASE1, BASE1_H = 0.60, 0.08
BASE2, BASE2_H = 0.46, 0.06
BASE_TOP = BASE1_H + BASE2_H                      # 0.14

# Shaft (sao): hexagonal column with a collar at each end and a band mid-way.
COLLAR_R, COLLAR_H = 0.105, 0.03
SHAFT_R = 0.085
SHAFT_Z0 = BASE_TOP + COLLAR_H                    # 0.17
SHAFT_Z1 = 0.71                                   # top collar sits here
BAND_R, BAND_H = 0.10, 0.04
BAND_Z = 0.42
PLAT_Z = SHAFT_Z1 + COLLAR_H                      # 0.74: platform starts here

# Platform (chudai): a square frustum flaring out, then a flat square slab.
PLAT_HALF0, PLAT_HALF1, PLAT_H = 0.12, 0.21, 0.08
SLAB, SLAB_H = 0.44, 0.05
BOX_Z = PLAT_Z + PLAT_H + SLAB_H                  # 0.87: light box starts here

# Light box (hibukuro): bottom plate, four corner posts, top plate, with a
# recessed paper core showing through the four square openings.
PLATE, PLATE_H = 0.35, 0.04
POST = 0.05
POST_C = 0.145                                    # post centres: outer faces at 0.17
OPEN_H = 0.24                                     # opening height = opening width (0.34 - 2 * 0.05)
CORE = 0.26
POST_Z0 = BOX_Z + PLATE_H                         # 0.91
POST_Z1 = POST_Z0 + OPEN_H                        # 1.15
BOX_TOP = POST_Z1 + PLATE_H                       # 1.19

# Roof (kasa): a short flared square eave, then a low square pyramid frustum.
EAVE_HALF0, EAVE_HALF1, EAVE_H = 0.23, 0.30, 0.06
ROOF_HALF0, ROOF_HALF1, ROOF_H = 0.29, 0.05, 0.20
EAVE_Z = BOX_TOP                                  # 1.19
ROOF_Z = EAVE_Z + EAVE_H                          # 1.25
ROOF_TOP = ROOF_Z + ROOF_H                        # 1.45

# Finial: a six-sided lotus cup (ukebana) and the jewel sphere (hoju).
CUP_R0, CUP_R1, CUP_H = 0.035, 0.06, 0.04
JEWEL_R = 0.055
JEWEL_Z = ROOF_TOP + CUP_H + JEWEL_R - 0.015      # 1.53: sunk 1.5 cm into the cup; top at 1.585


def _hex(p, radius, depth, at, color, radius_top=None):
    """A capped 6-sided cylinder whose hexagonal caps are triangulated (quads and tris only)."""
    faces = p.cylinder(radius, depth, at=at, segments=6, color=color, radius_top=radius_top)
    caps = [f for f in faces if len(f.verts) > 4]
    sides = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"]
    p.paint(tris, color)
    return sides + tris


def _square_frustum(p, half0, half1, depth, at, color):
    """An axis-aligned square frustum: a 4-segment cylinder turned 45 degrees; caps are quads."""
    return p.cylinder(half0 * SQ, depth, at=at, rot=(0, 0, 45), segments=4, color=color, radius_top=half1 * SQ)


def build():
    p = Piece("sakura_garden_lantern_stone", "garden", footprint=(BASE1, BASE1))

    # Base: the lower step is the full footprint and dark; the upper step lighter.
    p.box((BASE1, BASE1, BASE1_H), at=(0, 0, 0), color="stone_dark")
    p.box((BASE2, BASE2, BASE2_H + SINK), at=(0, 0, BASE1_H - SINK), color="stone")

    # Shaft: foot collar, hexagonal column, mid band, top collar.
    _hex(p, COLLAR_R, COLLAR_H + SINK, at=(0, 0, BASE_TOP - SINK), color="stone_dark")
    _hex(p, SHAFT_R, SHAFT_Z1 - SHAFT_Z0 + 2 * SINK, at=(0, 0, SHAFT_Z0 - SINK), color="stone")
    _hex(p, BAND_R, BAND_H, at=(0, 0, BAND_Z), color="stone_dark")
    _hex(p, COLLAR_R, COLLAR_H + SINK, at=(0, 0, SHAFT_Z1 - SINK), color="stone_dark")

    # Platform: flaring square frustum, then the slab the light box stands on.
    _square_frustum(p, PLAT_HALF0, PLAT_HALF1, PLAT_H + SINK, at=(0, 0, PLAT_Z - SINK), color="stone_dark")
    p.box((SLAB, SLAB, SLAB_H + SINK), at=(0, 0, PLAT_Z + PLAT_H - SINK), color="stone")

    # Light box: bottom plate, paper core, four corner posts, top plate.
    p.box((PLATE, PLATE, PLATE_H + SINK), at=(0, 0, BOX_Z - SINK), color="stone")
    p.box((CORE, CORE, OPEN_H + 2 * SINK), at=(0, 0, POST_Z0 - SINK), color="paper_shadow")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((POST, POST, OPEN_H + 2 * SINK), at=(sx * POST_C, sy * POST_C, POST_Z0 - SINK), color="stone")
    p.box((PLATE, PLATE, PLATE_H), at=(0, 0, POST_Z1), color="stone")

    # Roof: the flared eave (dark, its underside is in shadow) and the pyramid.
    _square_frustum(p, EAVE_HALF0, EAVE_HALF1, EAVE_H + SINK, at=(0, 0, EAVE_Z - SINK), color="stone_dark")
    _square_frustum(p, ROOF_HALF0, ROOF_HALF1, ROOF_H + SINK, at=(0, 0, ROOF_Z - SINK), color="stone")

    # Finial: lotus cup flaring up to the jewel sphere.
    _hex(p, CUP_R0, CUP_H + SINK, at=(0, 0, ROOF_TOP - SINK), color="stone_dark", radius_top=CUP_R1)
    p.sphere(JEWEL_R, at=(0, 0, JEWEL_Z), subdivisions=1, color="stone")

    return p.finish()
