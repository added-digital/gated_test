"""Soribashi, a gently arched wooden garden footbridge 2 m long and 1 m wide: seven pale hinoki deck planks laid across two curved cedar stringers that rise 0.35 m at mid-span and touch the ground at both ends, with six dark posts a side (the heavier end posts standing on the ground) carrying a top and a mid hand-rail of short dark box segments that follow the arch."""
import math

from mathutils import Vector

from sakura_kit.contract import Piece

LENGTH, WIDTH = 2.0, 1.0        # declared footprint: span along X, width along Y
RISE = 0.35                     # arch rise at mid-span, measured on the stringer underside
PLANKS = 7
SINK = 0.004                    # parts sink this far into each other: nothing floats, no coplanar faces

# The arch: a parabola sampled at the plank joints, so every part sits on the
# same piecewise-linear curve (planks, beams, posts and rails all agree).
JOINTS = [-LENGTH / 2 + LENGTH * j / PLANKS for j in range(PLANKS + 1)]

# Stringers: the two curved beams under the deck. Underside on the arc,
# constant vertical depth, vertical cut at each joint and at the ends.
STRINGER_W, STRINGER_D = 0.08, 0.10
STRINGER_Y = 0.41               # beam centre; outer face at y = 0.45

# Deck planks: a vertical-cut slab per arc segment, sunk SINK into the beams.
PLANK_W = 0.92                  # across Y, overhanging the beams by 1 cm
PLANK_T = 0.045                 # vertical thickness
PLANK_GAP = 0.012               # daylight between planks
DECK = STRINGER_D - SINK + PLANK_T   # deck top above the arc

# Balustrade: posts clamp the outside of the beams, rails are inset into the posts.
POST_X = (0.965, 0.579, 0.193)  # mirrored in X; the first is the end post
POST_W, POST_D = 0.06, 0.055    # mid post: along X, along Y (inner face 5 mm into the beam)
POST_Y = 0.4725                 # mid post and rail centre; outer face at y = 0.50
POST_FOOT = 0.03                # mid posts stop this far above the beam underside
END_POST = 0.07                 # end post (oyabashira): square, stands on the ground
END_POST_Y = 0.465              # outer face at y = 0.50
RAIL_TOP = (0.74, 0.045, 0.05)  # centre height above the deck, width (Y), height (Z)
RAIL_MID = (0.40, 0.04, 0.04)
POST_RISE, END_POST_RISE = 0.03, 0.10   # post tops above the top rail


def _arc(x):
    return RISE * (1.0 - (2.0 * x / LENGTH) ** 2)


def _chord_z(x):
    """Height of the arch polyline (the parabola joined straight between joints) at x."""
    x = max(-LENGTH / 2, min(LENGTH / 2, x))
    j = min(int((x + LENGTH / 2) / (LENGTH / PLANKS)), PLANKS - 1)
    xa, xb = JOINTS[j], JOINTS[j + 1]
    t = (x - xa) / (xb - xa)
    return _arc(xa) + t * (_arc(xb) - _arc(xa))


def _deck_top(x):
    return _chord_z(x) + DECK


def _strip(p, rings, color):
    """A closed strip: quads between consecutive 4-vertex rings plus two end caps."""
    verts = [[p.bm.verts.new(Vector(c)) for c in ring] for ring in rings]
    faces = [p.bm.faces.new(list(reversed(verts[0]))), p.bm.faces.new(verts[-1])]
    for a, b in zip(verts, verts[1:]):
        for i in range(4):
            faces.append(p.bm.faces.new([a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]]))
    return p.paint(faces, color)


def build():
    p = Piece("sakura_garden_bridge_2m", "garden", footprint=(LENGTH, WIDTH))

    # Stringers: one curved beam each side, bottom edge on the ground at x = +-1.
    for sy in (-1, 1):
        y0, y1 = sy * (STRINGER_Y - STRINGER_W / 2), sy * (STRINGER_Y + STRINGER_W / 2)
        rings = [[(x, y0, _arc(x)), (x, y1, _arc(x)), (x, y1, _arc(x) + STRINGER_D), (x, y0, _arc(x) + STRINGER_D)]
                 for x in JOINTS]
        _strip(p, rings, "wood")

    # Deck: seven planks, each a vertical-cut slab following its arc segment.
    # Built in the XZ plane and extruded along -Y across the full plank width.
    for j in range(PLANKS):
        xa, xb = JOINTS[j] + PLANK_GAP / 2, JOINTS[j + 1] - PLANK_GAP / 2
        za, zb = _chord_z(xa) + STRINGER_D - SINK, _chord_z(xb) + STRINGER_D - SINK
        pts = [(xa, za), (xb, zb), (xb, zb + PLANK_T), (xa, za + PLANK_T)]
        p.prism(pts, PLANK_W, at=(0, PLANK_W / 2, 0), rot=(90, 0, 0), color="wood_light")

    # Posts: end posts stand on the ground astride the beam ends; mid posts
    # clamp the outer face of the beam and stop part-way down its side.
    rail_top_z = RAIL_TOP[0] + RAIL_TOP[2] / 2
    for sy in (-1, 1):
        for sx in (-1, 1):
            for i, px in enumerate(POST_X):
                x = sx * px
                if i == 0:
                    h = _deck_top(x) + rail_top_z + END_POST_RISE
                    p.box((END_POST, END_POST, h), at=(x, sy * END_POST_Y, 0), color="wood_dark")
                else:
                    z0 = _chord_z(x) + POST_FOOT
                    h = _deck_top(x) + rail_top_z + POST_RISE - z0
                    p.box((POST_W, POST_D, h), at=(x, sy * POST_Y, z0), color="wood_dark")

    # Rails: a tilted box between each pair of posts, ends buried in the posts.
    posts = sorted(sx * px for px in POST_X for sx in (-1, 1))
    for height, w, t in (RAIL_TOP, RAIL_MID):
        for sy in (-1, 1):
            for xa, xb in zip(posts, posts[1:]):
                za, zb = _deck_top(xa) + height, _deck_top(xb) + height
                length = math.hypot(xb - xa, zb - za)
                tilt = math.degrees(math.atan2(zb - za, xb - xa))
                p.box((length, w, t), at=((xa + xb) / 2, sy * POST_Y, (za + zb) / 2),
                      rot=(0, -tilt, 0), anchor="center", color="wood_dark")

    return p.finish()
