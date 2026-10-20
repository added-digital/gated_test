"""Hero cherry tree in full bloom, 3.5 m tall with a 2.8 m canopy: a tapering eight-sided bark trunk 1.4 m tall forking into four angled branches that carry nine unevenly squashed icosphere blossom clouds, sunlit pale pink on top and deeper pink underneath."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

SEGMENTS = 8        # contract: round things use 6 to 10 segments
CANOPY_SUBDIV = 2   # bmesh level 2 is the 80-tri "subdivision-1" icosphere the contract asks for
                    # (bmesh level 1 is the bare 20-face icosahedron, which reads as a crystal)

# Trunk: a truncated cone standing on the origin.
TRUNK_R0, TRUNK_R1, TRUNK_H = 0.30, 0.18, 1.40

# Branches: (start inside the trunk, end buried in a canopy lobe, base radius, tip radius)
BRANCHES = [
    ((0.04, -0.02, 1.12), (0.72, -0.18, 2.47), 0.13, 0.06),    # right
    ((-0.04, 0.02, 1.20), (-0.74, 0.10, 2.42), 0.12, 0.06),    # left
    ((0.02, -0.04, 1.05), (0.18, -0.72, 2.32), 0.11, 0.055),   # front
    ((-0.02, 0.04, 1.26), (-0.22, 0.72, 2.52), 0.10, 0.05),    # back
]

# Canopy: icospheres, each scaled unevenly so no two read the same; the lot overlaps
# into one connected cloud that the branches run up into.  (centre, radius, (sx, sy, sz), colour)
CANOPY = [
    ((0.00, 0.00, 2.65), 0.90, (1.00, 0.95, 0.85), "sakura"),         # core
    ((0.10, -0.10, 2.95), 0.65, (1.05, 1.00, 0.85), "sakura_light"),  # sunlit crown, top at 3.5
    ((-0.45, 0.30, 3.05), 0.52, (1.00, 1.00, 0.80), "sakura_light"),  # second sunlit lobe
    ((-0.82, 0.10, 2.52), 0.72, (0.85, 1.00, 0.78), "sakura"),        # left lobe, out to x = -1.4
    ((0.79, -0.20, 2.57), 0.75, (0.85, 0.90, 0.80), "sakura"),        # right lobe, out to x = +1.4
    ((0.20, -0.80, 2.42), 0.70, (1.00, 0.85, 0.75), "sakura"),        # front lobe, out to y = -1.4
    ((-0.25, 0.80, 2.62), 0.70, (0.95, 0.85, 0.80), "sakura"),        # back lobe, out to y = +1.4
    ((0.60, 0.50, 2.20), 0.55, (1.05, 1.00, 0.80), "sakura_deep"),    # shaded underside, front-right
    ((-0.55, -0.45, 2.25), 0.58, (1.00, 0.95, 0.80), "sakura_deep"),  # shaded underside, back-left
]


def _tris(p, faces, color):
    """Triangulate the octagonal caps among `faces` (quads and tris only) and recolour them."""
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
    p = Piece("sakura_tree_sakura_a", "tree")

    # Trunk, then the branches that fork out of its upper third.
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
    return p.finish()
