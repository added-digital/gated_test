"""Young cherry tree in bloom, 2.2 m tall with a 1.6 m canopy: a slim six-sided bark trunk (0.13 m at the foot, tapering) forking into two angled branches (one right, one front-left) that each run up into one of five unevenly squashed icosphere blossom clouds in three pinks, no two of which share a colour where they show a seam against each other: sakura_light on the sunlit crown and left lobe, sakura on the core, sakura_deep on the right and low lobes (the re-walk: "no contrast between blobs of the same pink", breaks.md 2026-10-21); declares sakura_tris_max 800 because a sapling is a background piece and should cost well under the hero tree."""
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
# Colours: no two blobs that show a seam against each other share a pink (asserted
# by check_contrast below); three pinks are enough for this cloud.
CANOPY = [
    ((0.00, 0.00, 1.75), 0.50, (1.00, 1.00, 0.85), "sakura"),         # core, trunk top buried in it
    ((0.06, -0.04, 1.92), 0.36, (1.00, 1.00, 0.78), "sakura_light"),  # sunlit crown, top at 2.2
    ((0.48, -0.10, 1.66), 0.42, (0.82, 0.95, 0.80), "sakura_deep"),   # right lobe, out to x = +0.8
    ((-0.44, 0.14, 1.76), 0.44, (0.86, 0.90, 0.78), "sakura_light"),  # left lobe, out to x = -0.8
    ((-0.22, -0.36, 1.62), 0.38, (1.00, 0.90, 0.75), "sakura_deep"),  # low front-left lobe on the second branch
]
BLOSSOM_PINKS = ("sakura_light", "sakura", "sakura_deep", "sakura_bud")

# Contrast test. Two blobs "touch" where the surface of one crosses the surface
# of the other outside every third blob: a seam the eye can see. (The plain
# bounding-sphere overlap graph of this cloud needs four pinks, the core, crown,
# right and low lobes all overlapping each other; the visible seams need three.)
# Sampled on the ellipsoids: SEAM_SAMPLES fixed directions per blob, SEAM_TOL on
# the normalised radius^2.
SEAM_SAMPLES = 4000
SEAM_TOL = 0.15


def _directions(n):
    """A fixed Fibonacci sphere: the same n directions every build."""
    golden = math.pi * (3 - math.sqrt(5))
    out = []
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        out.append((r * math.cos(golden * i), r * math.sin(golden * i), z))
    return out


def _depth(pt, blob):
    """Normalised radius^2 of `pt` in `blob`'s ellipsoid: < 1 inside, 1 on the surface."""
    (cx, cy, cz), r, (sx, sy, sz), _ = blob
    return ((pt[0] - cx) / (r * sx)) ** 2 + ((pt[1] - cy) / (r * sy)) ** 2 + ((pt[2] - cz) / (r * sz)) ** 2


def visible_seams(canopy):
    """Pairs (i, j) of blobs whose surfaces cross outside every other blob."""
    seams = set()
    for i, (c, r, s, _) in enumerate(canopy):
        others = [j for j in range(len(canopy)) if j != i]
        for d in _directions(SEAM_SAMPLES):
            pt = (c[0] + d[0] * r * s[0], c[1] + d[1] * r * s[1], c[2] + d[2] * r * s[2])
            depths = {j: _depth(pt, canopy[j]) for j in others}
            for j, dj in depths.items():
                if abs(dj - 1) < SEAM_TOL and all(dk > 1 for k, dk in depths.items() if k != j):
                    seams.add((min(i, j), max(i, j)))
    return seams


def check_contrast(canopy):
    """Assert no two blobs with a visible seam share a palette pink; returns the seams."""
    for _, _, _, colour in canopy:
        assert colour in BLOSSOM_PINKS, f"{colour} is not a blossom pink"
    seams = visible_seams(canopy)
    same = [(i, j) for i, j in sorted(seams) if canopy[i][3] == canopy[j][3]]
    assert not same, f"blobs sharing a pink across a visible seam: {same} ({[canopy[i][3] for i, _ in same]})"
    return seams


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
    check_contrast(CANOPY)
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
