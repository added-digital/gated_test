"""Young cherry tree in bloom, 2.2 m tall with a 1.6 m canopy: a slim six-sided bark trunk (0.13 m at the foot, tapering) forking into two angled branches (one right, one front-left) that each run up into one of five unevenly squashed icosphere blossom clouds, pale sakura_light on the sunlit crown and left lobe, sakura elsewhere; declares sakura_tris_max 800 because a sapling is a background piece and should cost well under the hero tree."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

SEGMENTS = 6        # slim trunk: six sides is enough and the contract allows 6 to 10
CANOPY_SUBDIV = 2   # bmesh level 2 is the 80-tri "subdivision-1" icosphere the contract asks for
                    # (bmesh level 1 is the bare 20-face icosahedron)
TRIS_MAX = 800      # brief: a young tree, well under the 1400 tree budget

# Trunk: a truncated cone standing on the origin, 0.13 m across at the foot.
TRUNK_R0, TRUNK_R1, TRUNK_H = 0.065, 0.045, 1.45

# Branches: (start on the trunk axis, end buried in a canopy lobe, base radius, tip radius)
BRANCHES = [
    ((0.0, 0.0, 0.80), (0.50, 0.06, 1.62), 0.050, 0.026),    # right, forks lowest, leans a touch back
    ((0.0, 0.0, 0.90), (-0.30, -0.36, 1.60), 0.045, 0.024),  # front-left, into the low lobe
]

# Canopy: five icospheres scaled unevenly so none reads the same; they overlap into
# one cloud 1.6 m wide whose top sits at 2.2 m.  (centre, radius, (sx, sy, sz), colour)
CANOPY = [
    ((0.00, 0.00, 1.75), 0.50, (1.00, 1.00, 0.85), "sakura"),         # core, trunk top buried in it
    ((0.06, -0.04, 1.92), 0.36, (1.00, 1.00, 0.78), "sakura_light"),  # sunlit crown, top at 2.2
    ((0.48, -0.10, 1.66), 0.42, (0.82, 0.95, 0.80), "sakura"),        # right lobe, out to x = +0.8
    ((-0.44, 0.14, 1.76), 0.44, (0.86, 0.90, 0.78), "sakura_light"),  # left lobe, out to x = -0.8
    ((-0.22, -0.36, 1.62), 0.38, (1.00, 0.90, 0.75), "sakura"),       # low front-left lobe on the second branch
]


def _tris(p, faces, color):
    """Triangulate the hexagonal caps among `faces` (quads and tris only) and recolour them."""
    caps = [f for f in faces if len(f.verts) > 4]
    rest = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"] if caps else []
    p.paint(tris, color)
    return rest + tris


def _branch(p, start, end, r0, r1):
    """A tapered bark tube from `start` to `end`, its axis tracked onto the segment."""
    a, b = Vector(start), Vector(end)
    d = b - a
    rot = [math.degrees(v) for v in d.normalized().to_track_quat("Z", "Y").to_euler("XYZ")]
    faces = p.cylinder(r0, d.length, at=tuple(a), rot=rot, segments=SEGMENTS, color="bark", radius_top=r1)
    return _tris(p, faces, "bark")


def build():
    p = Piece("sakura_tree_sakura_b", "tree")

    # Trunk, then the two branches that fork out of its upper third.
    trunk = p.cylinder(TRUNK_R0, TRUNK_H, at=(0, 0, 0), segments=SEGMENTS, color="bark", radius_top=TRUNK_R1)
    _tris(p, trunk, "bark")
    for start, end, r0, r1 in BRANCHES:
        _branch(p, start, end, r0, r1)

    # Blossom clouds.
    for at, r, scale, color in CANOPY:
        p.sphere(r, at=at, subdivisions=CANOPY_SUBDIV, color=color, scale=scale)

    # The canopy is deliberately lopsided: recentre the footprint on the origin (XY only).
    xs = [v.co.x for v in p.bm.verts]
    ys = [v.co.y for v in p.bm.verts]
    shift = (-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0.0)
    bmesh.ops.translate(p.bm, verts=list(p.bm.verts), vec=shift)

    obj = p.finish()
    obj["sakura_tris_max"] = TRIS_MAX
    return obj
