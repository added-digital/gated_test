"""A moribana ikebana: a shallow dark stone suiban 0.25 m across filled with water, one bark branch rising from it and bending left with a short twig to the right, carrying four small rounded sakura blossoms, 0.33 m tall in all."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

# Bowl (suiban): an 8-sided tapered dish, wider at the rim, with a flat rim
# ring and a recessed water surface inside.
BOWL_SEGMENTS = 8
BOWL_R_TOP = 0.125      # 0.25 m across at the rim
BOWL_R_BOT = 0.10
BOWL_H = 0.06
RIM_W = 0.012           # flat rim ring width
WATER_DROP = 0.015      # water surface sits this far below the rim

# Branch: thin tapered bark cylinders, 6 segments each (contract: 6 to 10).
TWIG_SEGMENTS = 6
LEFT = (-math.sqrt(0.5), -math.sqrt(0.5))     # image-left in the preview
RIGHT = (math.sqrt(0.5), math.sqrt(0.5))      # image-right in the preview
TWIG_UP = 0.01          # the side twig leaves the stem this far above the bend

BLOSSOM_R = 0.04        # brief: "subdivision-1" icospheres, radius 0.04
BLOSSOM_SUBDIV = 2      # bmesh level 2 is the 80-tri "subdivision-1" icosphere the contract
                        # asks for (level 1 is the bare 20-face icosahedron, which reads as
                        # a gem); the same level the kit's tree canopies use.


def _unit(tilt_deg, heading):
    """Unit vector tilted `tilt_deg` from vertical toward the horizontal `heading`."""
    hx, hy = heading
    s, c = math.sin(math.radians(tilt_deg)), math.cos(math.radians(tilt_deg))
    return Vector((hx * s, hy * s, c))


def _tris(p, faces, color):
    """Triangulate any n-gon in `faces` (cylinder caps) and return quads + tris."""
    caps = [f for f in faces if len(f.verts) > 4]
    rest = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"] if caps else []
    p.paint(tris, color)
    return rest + tris


def _twig(p, start, end, r0, r1, overshoot=(0.0, 0.0)):
    """A tapered bark cylinder from `start` to `end`, extended by `overshoot`
    at each end so joints overlap and no notch opens on the outside of a bend."""
    start, end = Vector(start), Vector(end)
    axis = (end - start).normalized()
    a = start - axis * overshoot[0]
    b = end + axis * overshoot[1]
    length = (b - a).length
    rot = [math.degrees(v) for v in axis.to_track_quat("Z", "Y").to_euler("XYZ")]
    faces = p.cylinder(r0, length, at=tuple(a), rot=rot, segments=TWIG_SEGMENTS,
                       color="bark", radius_top=r1)
    return _tris(p, faces, "bark")


def _bowl(p):
    faces = p.cylinder(BOWL_R_BOT, BOWL_H, at=(0, 0, 0), segments=BOWL_SEGMENTS,
                       color="stone_dark", radius_top=BOWL_R_TOP)
    top = p.highest_faces(faces, 1)[0]
    bottom = p.faces_facing(faces, (0, 0, -1))
    # Flat rim ring, then a tiny second inset whose quads become the inner wall
    # once the inner face is pushed down to the water level.
    rim = bmesh.ops.inset_individual(p.bm, faces=[top], thickness=RIM_W, depth=0.0)["faces"]
    wall = bmesh.ops.inset_individual(p.bm, faces=[top], thickness=0.002, depth=0.0)["faces"]
    bmesh.ops.translate(p.bm, verts=list(top.verts), vec=(0, 0, -WATER_DROP))
    p.paint(rim + wall, "stone_dark")
    p.paint(_tris(p, [top], "water"), "water")
    _tris(p, bottom, "stone_dark")


def build():
    p = Piece("sakura_prop_ikebana", "prop")
    _bowl(p)

    # Branch path: a near-vertical base inside the water, a long bend to the
    # left, and a short twig leaning the other way from just above the joint.
    p0 = Vector((0.0, 0.0, 0.02))                     # buried in the bowl
    d1, d2, d3 = _unit(12, LEFT), _unit(48, LEFT), _unit(60, RIGHT)
    p1 = p0 + d1 * 0.16
    p2 = p1 + d2 * 0.17
    t0 = p1 + d2 * TWIG_UP                            # twig root, on the stem axis
    p3 = t0 + d3 * 0.10
    _twig(p, p0, p1, 0.013, 0.010, overshoot=(0.0, 0.012))
    _twig(p, p1, p2, 0.010, 0.007, overshoot=(0.012, 0.0))
    # No start overshoot on the twig: its base cap (r 0.008) sits centred on
    # the stem axis, inside the stem's 0.0084 m apothem, so the twig grows out
    # of the bark with nothing poking out on the inside of the bend.
    _twig(p, t0, p3, 0.008, 0.005, overshoot=(0.0, 0.0))

    # Blossoms: centred on the branch axis so each one wraps a bit of stem.
    # Slightly uneven scales so no two read as the same ball.
    blossoms = [
        (p2, "sakura_deep", (1.05, 0.9, 1.0)),            # tip of the main branch
        (p1 + d2 * 0.085, "sakura", (0.95, 1.05, 0.9)),   # mid bend
        (p3, "sakura", (1.0, 0.9, 1.05)),                 # twig tip
        (p0 + d1 * 0.12, "sakura_deep", (0.9, 1.0, 0.95)),  # low on the base stem
    ]
    for at, color, scale in blossoms:
        p.sphere(BLOSSOM_R, at=tuple(at), subdivisions=BLOSSOM_SUBDIV, color=color, scale=scale)

    # The branch leans, so recentre the whole footprint on the origin (the
    # bowl ends up a few cm off-centre, which is how a real arrangement sits).
    xs = [v.co.x for v in p.bm.verts]
    ys = [v.co.y for v in p.bm.verts]
    shift = (-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0.0)
    bmesh.ops.translate(p.bm, verts=list(p.bm.verts), vec=shift)

    return p.finish()
