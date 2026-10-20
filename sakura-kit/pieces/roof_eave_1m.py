"""A 1 m wide tiled roof slope (kawara-buki): a 1.2 m deep wedge 0.7 m tall at
its ridge edge (y = 0, the piece's origin) sloping down to a dark wood eave
beam at y = 1.2, with five rows of half-round cover tiles ending in round tile
caps along the eave. Two of these on one ridge line, at rot 0 and rot 2, make
a gable; the assembler lifts them to the top of the walls."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece, GRID

DEPTH, RISE = 1.2, 0.7          # wedge footprint along Y and its height at the high end
BEAM_D, BEAM_H = 0.10, 0.08     # eave beam section (Y depth, Z height)
RIDGE_R, N_RIDGES = 0.045, 5    # half-round cover tiles running down the slope
CAP_R, CAP_T = 0.06, 0.02       # round tile-end caps at the eave
SINK = 0.005                    # tiles sit this far into the slope so nothing floats
TOP_GAP = 0.04                  # tiles stop short of the high edge (a ridge piece covers it)


def build():
    p = Piece("sakura_roof_eave_1m", "roof")

    # Slope body. Piece.wedge rises toward +Y, so turn it round to slope DOWN toward +Y.
    body = p.wedge((GRID, DEPTH, RISE), rot=(0, 0, 180), color="roof_tile")
    p.paint(p.faces_facing(body, (0, 0, -1)), "wood")   # underside is the eave boarding

    # Eave beam along the low edge: stands on the base, flush with the +Y face.
    p.box((GRID, BEAM_D, BEAM_H), at=(0, DEPTH / 2 - BEAM_D / 2, 0), color="wood_dark")

    # Slope frame: unit vectors down the slope and out of its surface.
    theta = math.atan2(RISE, DEPTH)
    down = Vector((0, math.cos(theta), -math.sin(theta)))
    normal = Vector((0, math.sin(theta), math.cos(theta)))
    top_edge = Vector((0, -DEPTH / 2, RISE))

    def on_slope(x, s):
        """Point `s` metres down the slope from the high edge, sunk SINK into it."""
        return top_edge + Vector((x, 0, 0)) + down * s - normal * SINK

    # A prism extrudes along its local Z; rotate so local Z runs UP the slope and
    # local Y points out of the slope, so the half-round bulges outward.
    rot = (90 - math.degrees(theta), 0, 0)

    def half_round(r):
        """Half of a 6-segment cylinder: 4 points, so the end caps stay quads."""
        return [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a in (0, 60, 120, 180)]

    s_eave = (DEPTH - BEAM_D) / math.cos(theta)   # where the tiles meet the beam's inner face
    for i in range(N_RIDGES):
        x = (i - (N_RIDGES - 1) / 2) * (GRID / N_RIDGES)
        p.prism(half_round(RIDGE_R), s_eave - TOP_GAP, at=on_slope(x, s_eave), rot=rot, color="roof_dark")
        p.prism(half_round(CAP_R), CAP_T, at=on_slope(x, s_eave + CAP_T / 2), rot=rot, color="roof_dark")

    # Roof pivot rule: the ridge edge sits on the origin, the eave at +DEPTH.
    bmesh.ops.translate(p.bm, verts=p.bm.verts, vec=(0, DEPTH / 2, 0))
    return p.finish()
