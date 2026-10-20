"""Tsukubai: a rough seven-sided stone water basin 0.5 m across and 0.4 m tall with a disc of still water recessed 3 cm below its rim, fed by a bamboo kakei (a 0.7 m vertical culm with node rings and a thinner slant-cut pipe angled out over the bowl, a thin trickle falling from it), a pale wooden hishaku ladle laid across the rim with its cup on one side and its handle on the other, and three small dark stones and a moss patch at the foot."""
import math

import bmesh
from mathutils import Matrix, Vector

from sakura_kit.contract import Piece

# Basin: a seven-sided boulder lathed from four rings, each vertex pushed in
# or out a little so the facets read as rough stone. 0.5 m across at its widest.
BASIN_SEG = 7
BASIN_H = 0.40
WATER_DROP = 0.03                     # water surface this far below the rim
RIM_R = 0.16                          # radius of the opening in the rim
BOWL_R = 0.15                         # radius of the water disc (inner wall leans in)
BASIN_RINGS = [(0.0, 0.20), (0.13, 0.24), (0.28, 0.245), (BASIN_H, 0.23)]   # (z, mean radius)
JITTER = [1.00, 0.93, 1.05, 0.97, 1.04, 0.92, 1.02]                           # per-vertex, fixed

# Kakei spout: a vertical culm beside the basin and a thinner pipe through its top.
POST_AT = (-0.28, -0.28)
POST_R, POST_H = 0.030, 0.70
POST_NODES = (0.24, 0.48)
PIPE_R, PIPE_LEN = 0.021, 0.46
PIPE_Z = 0.62                         # the pipe leaves the post at this height
PIPE_HEADING, PIPE_TILT = 45.0, 10.0  # toward the basin centre, dipping 10 degrees
PIPE_CUT = 0.9                        # tan of the slant at the pipe mouth (lower lip longer)
NODE_H, NODE_FLARE = 0.025, 0.005
BAMBOO_SEG = 6
TRICKLE_R = 0.007

# Hishaku ladle: cup on the +X rim, handle sloping down across the bowl to the -X rim.
CUP_AT = 0.195                        # cup centre, radial distance from the basin axis
CUP_R0, CUP_R1, CUP_H, CUP_WALL = 0.028, 0.034, 0.05, 0.006
HANDLE_R = 0.008
HANDLE_END = -0.225                   # far end of the handle, x (overhangs the rim a little)
LADLE_SEG = 6

# Rocks and moss at the foot: (x, y, radius, height)
ROCKS = [(0.21, -0.25, 0.075, 0.10), (-0.06, 0.29, 0.06, 0.075), (0.30, 0.11, 0.05, 0.06)]
MOSS_AT, MOSS_R, MOSS_H = (-0.17, -0.21), 0.09, 0.02


# -- mesh helpers -----------------------------------------------------------
def _circle(r, z, n, phase=0.0, jitter=None, shift=0, slant=0.0):
    """Points of an n-gon ring: radius `r` (times a per-vertex jitter), height `z`,
    optionally cut on a slant (z falls with local y, so the ring stays planar)."""
    pts = []
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        ri = r * (jitter[(i + shift) % len(jitter)] if jitter else 1.0)
        x, y = ri * math.cos(a), ri * math.sin(a)
        pts.append(Vector((x, y, z - slant * y)))
    return pts


def _ring(p, m, pts):
    return [p.bm.verts.new(m @ v) for v in pts]


def _band(p, a, b, color, tri=False):
    n = len(a)
    faces = [p.bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]) for i in range(n)]
    if tri:
        faces = bmesh.ops.triangulate(p.bm, faces=faces)["faces"]
    return p.paint(faces, color)


def _cap(p, ring, color, flip=False):
    """Close a ring with a polygon, then split it to tris (no n-gons)."""
    f = p.bm.faces.new(list(reversed(ring)) if flip else ring)
    return p.paint(bmesh.ops.triangulate(p.bm, faces=[f])["faces"], color)


def _frame(origin, direction):
    """Matrix whose local Z runs along `direction` from `origin`."""
    d = Vector(direction).normalized()
    rot = Matrix.Identity(4) if d.z > 0.9999 else d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return Matrix.Translation(Vector(origin)) @ rot


def _tube(p, origin, direction, r0, r1, length, n, color, mouth_color=None, slant=0.0):
    """A closed tapered tube along `direction`; its far cap may be cut on a slant."""
    m = _frame(origin, direction)
    phase = math.pi / n
    base = _ring(p, m, _circle(r0, 0.0, n, phase))
    tip = _ring(p, m, _circle(r1, length, n, phase, slant=slant))
    _band(p, base, tip, color)
    _cap(p, base, color, flip=True)
    _cap(p, tip, mouth_color or color)
    return m


def _node_ring(p, origin, direction, r, z):
    """An open collar a touch wider than the culm, centred `z` along its axis."""
    m = _frame(origin, direction)
    phase = math.pi / BAMBOO_SEG
    a = _ring(p, m, _circle(r + NODE_FLARE, z - NODE_H / 2, BAMBOO_SEG, phase))
    b = _ring(p, m, _circle(r + NODE_FLARE, z + NODE_H / 2, BAMBOO_SEG, phase))
    _band(p, a, b, "bamboo_node")


# -- parts ------------------------------------------------------------------
def _basin(p):
    m = Matrix.Identity(4)
    rings = [_ring(p, m, _circle(r, z, BASIN_SEG, 0.0, JITTER, shift=k * 2))
             for k, (z, r) in enumerate(BASIN_RINGS)]
    # Outer skin: the lowest band dark (damp), the rest pale, all split to rough facets.
    _band(p, rings[0], rings[1], "stone_dark", tri=True)
    _band(p, rings[1], rings[2], "stone", tri=True)
    _band(p, rings[2], rings[3], "stone", tri=True)
    _cap(p, rings[0], "stone_dark", flip=True)
    # Rim, the leaning inner wall, and the water disc 3 cm down.
    rim = _ring(p, m, _circle(RIM_R, BASIN_H, BASIN_SEG))
    bowl = _ring(p, m, _circle(BOWL_R, BASIN_H - WATER_DROP, BASIN_SEG))
    _band(p, rings[3], rim, "stone")
    _band(p, rim, bowl, "stone_dark")
    _cap(p, bowl, "water")


def _kakei(p):
    px, py = POST_AT
    up = (0, 0, 1)
    _tube(p, (px, py, 0.0), up, POST_R, POST_R * 0.92, POST_H, BAMBOO_SEG, "bamboo", mouth_color="bamboo_node")
    for z in POST_NODES:
        _node_ring(p, (px, py, 0.0), up, POST_R - (POST_R * 0.08) * z / POST_H, z)
    # The pipe starts on the post's axis and runs out over the bowl, dipping slightly.
    h, t = math.radians(PIPE_HEADING), math.radians(PIPE_TILT)
    d = Vector((math.cos(h) * math.cos(t), math.sin(h) * math.cos(t), -math.sin(t)))
    origin = Vector((px, py, PIPE_Z))
    _tube(p, origin, d, PIPE_R, PIPE_R, PIPE_LEN, BAMBOO_SEG, "bamboo", mouth_color="bamboo_node", slant=PIPE_CUT)
    _node_ring(p, origin, d, PIPE_R, POST_R + 0.10)
    # A thin trickle from the mouth down into the water.
    tip = origin + d * PIPE_LEN
    water_z = BASIN_H - WATER_DROP
    _tube(p, (tip.x, tip.y, water_z - 0.012), up, TRICKLE_R, TRICKLE_R, tip.z - water_z + 0.012 + 0.004,
          BAMBOO_SEG, "water")


def _ladle(p):
    m = Matrix.Identity(4)
    phase = math.pi / LADLE_SEG
    z0 = BASIN_H
    cx = CUP_AT
    ob = _ring(p, m, [Vector((cx, 0, 0)) + v for v in _circle(CUP_R0, z0, LADLE_SEG, phase)])
    ot = _ring(p, m, [Vector((cx, 0, 0)) + v for v in _circle(CUP_R1, z0 + CUP_H, LADLE_SEG, phase)])
    it = _ring(p, m, [Vector((cx, 0, 0)) + v for v in _circle(CUP_R1 - CUP_WALL, z0 + CUP_H, LADLE_SEG, phase)])
    ib = _ring(p, m, [Vector((cx, 0, 0)) + v for v in _circle(CUP_R0 - CUP_WALL, z0 + 0.008, LADLE_SEG, phase)])
    _band(p, ob, ot, "wood_light")
    _band(p, ot, it, "wood_light")
    _band(p, it, ib, "wood")
    _cap(p, ib, "wood")
    _cap(p, ob, "wood_light", flip=True)
    # Handle: rooted in the cup wall near its top, sloping down to rest on the far rim.
    start = Vector((cx - CUP_R1 + 0.004, 0, z0 + CUP_H - HANDLE_R - 0.002))
    end = Vector((HANDLE_END, 0, z0 + HANDLE_R - 0.004))   # underside sinks ~2 mm into the rim
    _tube(p, start, end - start, HANDLE_R, HANDLE_R, (end - start).length, LADLE_SEG, "wood_light")


def _rock(p, x, y, r, h, color):
    m = Matrix.Translation(Vector((x, y, 0)))
    n = 6
    rings = [_ring(p, m, _circle(r * s, z * h, n, 0.0, JITTER, shift=k * 3))
             for k, (s, z) in enumerate([(0.8, 0.0), (1.0, 0.45), (0.6, 1.0)])]
    _band(p, rings[0], rings[1], color, tri=True)
    _band(p, rings[1], rings[2], color, tri=True)
    _cap(p, rings[0], color, flip=True)
    _cap(p, rings[2], color)


def _moss(p):
    m = Matrix.Translation(Vector((*MOSS_AT, 0)))
    a = _ring(p, m, _circle(MOSS_R, 0.0, 6, 0.3, JITTER))
    b = _ring(p, m, _circle(MOSS_R * 0.9, MOSS_H, 6, 0.3, JITTER))
    _band(p, a, b, "moss_dark")
    _cap(p, a, "moss_dark", flip=True)
    _cap(p, b, "moss")


def build():
    p = Piece("sakura_garden_water_basin", "garden")
    _basin(p)
    _kakei(p)
    _ladle(p)
    for (x, y, r, h), color in zip(ROCKS, ("stone_dark", "stone", "stone_dark")):
        _rock(p, x, y, r, h, color)
    _moss(p)
    # The spout post and rocks sit off to one side, so recentre the footprint on the origin.
    xs = [v.co.x for v in p.bm.verts]
    ys = [v.co.y for v in p.bm.verts]
    shift = (-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, 0.0)
    bmesh.ops.translate(p.bm, verts=list(p.bm.verts), vec=shift)
    return p.finish()
