"""Bamboo clump: five slightly splayed culms 2.2 to 2.9 m tall and 5 to 7 cm thick on a 0.8 m footprint, each a six-sided tapering tube with a darker swollen node ring every 0.4 m, and eight drooping leaf blades near the tops."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

FOOTPRINT = 0.8
SEGMENTS = 6             # contract: round things use 6 to 10 segments
NODE_STEP = 0.4          # a node ring every 0.4 m along the culm
NODE_H = 0.03            # node ring height
NODE_FLARE = 0.006       # node ring radius beyond the culm's radius at that height
NODE_TOP_GAP = 0.1       # no ring closer than this to the culm's tip
TAPER = 0.78             # culm radius at the tip / radius at the base
LEAF = (0.25, 0.05, 0.005)
LEAF_INSET = 0.015       # the leaf's inner end is buried this far past the culm axis

# Culms: (x, y, base radius, length, tilt from vertical in degrees, heading of the tilt in degrees)
CULMS = [
    (0.00, 0.02, 0.035, 2.90, 2.0, 200),
    (0.16, -0.10, 0.030, 2.60, 3.5, -30),
    (-0.15, -0.12, 0.028, 2.35, 4.0, 215),
    (-0.12, 0.15, 0.032, 2.75, 3.0, 120),
    (0.13, 0.14, 0.025, 2.20, 4.5, 55),
]

# Leaves: (culm index, distance below that culm's tip along its axis,
#          heading in degrees, droop below horizontal in degrees, roll about the blade)
LEAVES = [
    (0, 0.08, 150, 35, 15),
    (0, 0.22, -40, 45, -20),
    (1, 0.06, 90, 40, 10),
    (1, 0.20, 200, 30, -15),
    (2, 0.07, 60, 40, 20),
    (2, 0.19, -20, 45, -10),
    (3, 0.06, -60, 35, 15),
    (4, 0.07, 250, 40, -15),
]


def _tris(p, faces, color):
    """Triangulate the hexagonal caps among `faces` (quads and tris only) and recolour them."""
    caps = [f for f in faces if len(f.verts) > 4]
    rest = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"] if caps else []
    p.paint(tris, color)
    return rest + tris


def _axis(tilt, heading):
    """Unit vector `tilt` degrees off vertical, leaning toward the horizontal `heading`."""
    t, h = math.radians(tilt), math.radians(heading)
    return Vector((math.sin(t) * math.cos(h), math.sin(t) * math.sin(h), math.cos(t)))


def _culm(p, x, y, r0, length, tilt, heading):
    """One culm: a tapered 6-sided tube from (x, y, 0) along its tilted axis, its
    base pressed flat onto the ground, with an open node ring every NODE_STEP."""
    base = Vector((x, y, 0.0))
    axis = _axis(tilt, heading)
    rot = [math.degrees(v) for v in axis.to_track_quat("Z", "Y").to_euler("XYZ")]
    r1 = r0 * TAPER

    faces = p.cylinder(r0, length, at=tuple(base), rot=rot, segments=SEGMENTS, color="bamboo", radius_top=r1)
    # The tilted bottom cap would dip below z = 0 on one side: press it flat onto the ground.
    for f in p.faces_facing(faces, (0, 0, -1), min_dot=0.9):
        for v in f.verts:
            v.co.z = 0.0
    _tris(p, faces, "bamboo")

    # Node rings: short open tubes a touch wider than the culm, sharing its axis.
    s = NODE_STEP
    while s < length - NODE_TOP_GAP:
        r = r0 + (r1 - r0) * s / length
        p.cylinder(r + NODE_FLARE, NODE_H, at=tuple(base + axis * s), rot=rot, segments=SEGMENTS,
                   color="bamboo_node", anchor="center", caps=False)
        s += NODE_STEP
    return base, axis, length


def _leaf(p, culm, below_tip, heading, droop, roll):
    """A thin blade whose inner end is buried in the culm, pointing out along `heading` and drooping."""
    base, axis, length = culm
    attach = base + axis * (length - below_tip)
    h, d = math.radians(heading), math.radians(droop)
    direction = Vector((math.cos(h) * math.cos(d), math.sin(h) * math.cos(d), -math.sin(d)))
    centre = attach + direction * (LEAF[0] / 2 - LEAF_INSET)
    # Euler XYZ: roll about the blade's long axis, then droop about Y, then heading about Z.
    p.box(LEAF, at=tuple(centre), rot=(roll, droop, heading), color="bamboo_node", anchor="center")


def build():
    p = Piece("sakura_garden_bamboo_cluster", "garden", footprint=(FOOTPRINT, FOOTPRINT))
    culms = [_culm(p, *c) for c in CULMS]
    for leaf in LEAVES:
        _leaf(p, culms[leaf[0]], *leaf[1:])

    # The culms lean, so recentre the whole clump's footprint on the origin.
    xs = [v.co.x for v in p.bm.verts]
    ys = [v.co.y for v in p.bm.verts]
    shift = (-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0.0)
    bmesh.ops.translate(p.bm, verts=list(p.bm.verts), vec=shift)
    return p.finish()
