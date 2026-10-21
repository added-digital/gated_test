"""Hero cherry tree in full bloom, 3.5 m tall with a 2.8 m canopy: a tapering eight-sided bark trunk 1.4 m tall forking into four angled branches that carry nine unevenly squashed icosphere blossom clouds in four pinks, no two of which share a colour where they show a seam against each other: sakura_light on the sunlit crown and back lobe, sakura and sakura_deep alternating round the sides, sakura_bud on the buried core (the re-walk: "no contrast between blobs of the same pink", breaks.md 2026-10-21)."""
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
# Colours: no two blobs that show a seam against each other share a pink (asserted
# by check_contrast below). The buried core takes the fourth pink, sakura_bud: it
# shows a seam with every lobe, and the lobes need three pinks among themselves.
CANOPY = [
    ((0.00, 0.00, 2.65), 0.90, (1.00, 0.95, 0.85), "sakura_bud"),     # core: 20% of its surface shows, at the heart of the cloud
    ((0.10, -0.10, 2.95), 0.65, (1.05, 1.00, 0.85), "sakura_light"),  # sunlit crown, top at 3.5
    ((-0.45, 0.30, 3.05), 0.52, (1.00, 1.00, 0.80), "sakura"),        # second sunlit lobe
    ((-0.82, 0.10, 2.52), 0.72, (0.85, 1.00, 0.78), "sakura_deep"),   # left lobe, out to x = -1.4
    ((0.79, -0.20, 2.57), 0.75, (0.85, 0.90, 0.80), "sakura"),        # right lobe, out to x = +1.4
    ((0.20, -0.80, 2.42), 0.70, (1.00, 0.85, 0.75), "sakura_deep"),   # front lobe, out to y = -1.4
    ((-0.25, 0.80, 2.62), 0.70, (0.95, 0.85, 0.80), "sakura_light"),  # back lobe, out to y = +1.4
    ((0.60, 0.50, 2.20), 0.55, (1.05, 1.00, 0.80), "sakura_deep"),    # shaded underside, front-right
    ((-0.55, -0.45, 2.25), 0.58, (1.00, 0.95, 0.80), "sakura"),       # shaded underside, back-left
]
BLOSSOM_PINKS = ("sakura_light", "sakura", "sakura_deep", "sakura_bud")

# Contrast test. Two blobs "touch" where the surface of one crosses the surface
# of the other outside every third blob: a seam the eye can see. (The plain
# bounding-sphere overlap graph of this cloud needs five pinks, the core and the
# crown overlapping every lobe and three lobes overlapping each other, and the
# palette has four; the visible seams need four.) Sampled on the ellipsoids:
# SEAM_SAMPLES fixed directions per blob, SEAM_TOL on the normalised radius^2.
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
    check_contrast(CANOPY)
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
