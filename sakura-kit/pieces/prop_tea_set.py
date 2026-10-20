"""A tea set on a 0.4 x 0.28 m dark wood tray with a low lip: a squat ink kyusu teapot with a lid knob, a short side spout and a stub handle, and three small paper cups holding green tea."""
import math

import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

# Tray
TRAY_W, TRAY_D, TRAY_T = 0.40, 0.28, 0.02
LIP_W, LIP_H = 0.012, 0.012          # low rim around the tray edge
Z0 = TRAY_T                          # everything stands on the tray top

# Kyusu teapot: 8-segment squat body 0.12 m across
POT_AT = (-0.10, 0.02)
POT_SEG = 8
POT_PHASE = math.pi / POT_SEG        # flat faces toward +-X and +-Y
POT_RINGS = [(0.042, 0.0), (0.060, 0.030), (0.046, 0.066)]   # (radius, height above tray)
LID_RINGS = [(0.040, 0.062), (0.028, 0.078)]                # lid sunk 4 mm into the body
KNOB_R, KNOB_H = 0.009, 0.013
SPOUT_R, SPOUT_R_TIP, SPOUT_L = 0.016, 0.010, 0.060
HANDLE_R, HANDLE_R_TIP, HANDLE_L = 0.013, 0.011, 0.055

# Cups: 6-segment, 0.06 m across at the rim
CUP_AT = [(0.06, -0.075), (0.06, 0.075), (0.145, 0.0)]
CUP_SEG = 6
CUP_R, CUP_R_BOTTOM, CUP_H = 0.030, 0.026, 0.045
CUP_WALL = 0.006
TEA_H = 0.034                        # tea surface, recessed below the rim


def _ring(p, cx, cy, r, z, n, phase=0.0):
    return [p.bm.verts.new(Vector((cx + r * math.cos(phase + 2 * math.pi * i / n),
                                   cy + r * math.sin(phase + 2 * math.pi * i / n), z)))
            for i in range(n)]


def _band(p, a, b):
    n = len(a)
    return [p.bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]) for i in range(n)]


def _cap(p, ring, flip=False):
    """Close a ring with a polygon, then split it to tris (no n-gons)."""
    f = p.bm.faces.new(list(reversed(ring)) if flip else ring)
    return bmesh.ops.triangulate(p.bm, faces=[f])["faces"]


def _tri_caps(p, faces, color):
    """Triangulate the n-gon caps a Piece cylinder leaves behind."""
    caps = [f for f in faces if len(f.verts) > 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"]
    return p.paint(tris, color)


def _lathe(p, cx, cy, rings, n, phase, color):
    """Closed surface of revolution through (radius, z) rings, bottom to top."""
    rs = [_ring(p, cx, cy, r, z, n, phase) for r, z in rings]
    faces = []
    for a, b in zip(rs, rs[1:]):
        faces += _band(p, a, b)
    faces += _cap(p, rs[0], flip=True)
    faces += _cap(p, rs[-1])
    return p.paint(faces, color)


def _cup(p, cx, cy):
    """A hollow flared cup: outer wall, flat rim, inner wall down to the tea."""
    ph = math.pi / CUP_SEG
    outer_b = _ring(p, cx, cy, CUP_R_BOTTOM, Z0, CUP_SEG, ph)
    outer_t = _ring(p, cx, cy, CUP_R, Z0 + CUP_H, CUP_SEG, ph)
    inner_t = _ring(p, cx, cy, CUP_R - CUP_WALL, Z0 + CUP_H, CUP_SEG, ph)
    tea = _ring(p, cx, cy, CUP_R - CUP_WALL - 0.002, Z0 + TEA_H, CUP_SEG, ph)
    p.paint(_band(p, outer_b, outer_t), "paper")
    p.paint(_band(p, outer_t, inner_t), "paper")
    p.paint(_band(p, inner_t, tea), "paper_shadow")
    p.paint(_cap(p, tea), "bamboo_node")
    p.paint(_cap(p, outer_b, flip=True), "paper")


def build():
    p = Piece("sakura_prop_tea_set", "prop")

    # Tray: a dark slab with a low dark-trim lip on all four edges.
    p.box((TRAY_W, TRAY_D, TRAY_T), at=(0, 0, 0), color="wood_dark")
    for y in (-TRAY_D / 2 + LIP_W / 2, TRAY_D / 2 - LIP_W / 2):
        p.box((TRAY_W, LIP_W, LIP_H), at=(0, y, Z0), color="lattice")
    for x in (-TRAY_W / 2 + LIP_W / 2, TRAY_W / 2 - LIP_W / 2):
        p.box((LIP_W, TRAY_D - 2 * LIP_W, LIP_H), at=(x, 0, Z0), color="lattice")

    # Teapot body and lid: lathed octagons; the lid starts inside the body.
    tx, ty = POT_AT
    _lathe(p, tx, ty, [(r, Z0 + z) for r, z in POT_RINGS], POT_SEG, POT_PHASE, "ink")
    _lathe(p, tx, ty, [(r, Z0 + z) for r, z in LID_RINGS], POT_SEG, POT_PHASE, "ink")
    lid_top = Z0 + LID_RINGS[-1][1]
    knob = p.cylinder(KNOB_R, KNOB_H, at=(tx, ty, lid_top - 0.003), segments=6, color="ink")
    _tri_caps(p, knob, "ink")

    # Spout: a short tapered stub pointing -Y and tilted up, rooted inside the body.
    spout = p.cylinder(SPOUT_R, SPOUT_L, at=(tx, ty - 0.040, Z0 + 0.034), rot=(65, 0, 0),
                       segments=6, color="ink", radius_top=SPOUT_R_TIP)
    _tri_caps(p, spout, "ink")

    # Side handle: a kyusu's straight stub, at 90 degrees to the spout, pointing -X.
    handle = p.cylinder(HANDLE_R, HANDLE_L, at=(tx - 0.040, ty, Z0 + 0.036), rot=(0, -78, 0),
                        segments=6, color="ink", radius_top=HANDLE_R_TIP)
    _tri_caps(p, handle, "ink")

    # Three cups in a loose triangle on the other side of the tray.
    for cx, cy in CUP_AT:
        _cup(p, cx, cy)

    return p.finish()
