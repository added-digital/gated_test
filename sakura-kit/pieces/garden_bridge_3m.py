"""Soribashi, a gently arched wooden garden footbridge 3 m long and 1.2 m wide
(three tiles of span, one of width): ten pale hinoki deck planks laid across
two crescent cedar stringers, thin at the tips where they rest on the ground
and 0.12 m deep at mid-span, carrying the deck 0.07 m above the ground at the
ends and 0.47 m at the crest (a 0.40 m arc), with eight dark posts a side (the
heavier end posts standing on the ground) carrying a top rail 1.0 m above the
deck and a mid rail at 0.5 m, both of short dark box segments that follow the
arch. Replaces garden_bridge_2m (breaks.md 2026-10-21: the 2 m bridge "feels
super small" and sat on a 3-cell pond).

The low ends matter: the player's capsule (radius 0.30, no step-up logic)
treats a contact steeper than 45 degrees as a wall, so a ledge it can step
onto is under 0.09 m; the deck starts at 0.07 m and climbs at 26 degrees.

Declares sakura_tris_max 900: the 600 garden budget is for a one-tile piece,
and planks, posts and rail segments grow with the span (816 tris here, well
under three tiles' worth).
"""
import math

from mathutils import Vector

from sakura_kit.contract import Piece

LENGTH, WIDTH = 3.0, 1.2        # declared footprint: span along X, width along Y
RISE = 0.40                     # arch rise at mid-span, measured on the plank bed (the stringer top)
PLANKS = 10
SINK = 0.004                    # parts sink this far into each other: nothing floats, no coplanar faces
TRIS_MAX = 900                  # declared budget; see the docstring

# The arch: a parabola sampled at the plank joints, so every part sits on the
# same piecewise-linear curve (planks, beams, posts and rails all agree).
JOINTS = [-LENGTH / 2 + LENGTH * j / PLANKS for j in range(PLANKS + 1)]

# Stringers: the two crescent beams under the deck. Top edge (the plank bed) on
# the arc; the depth tapers from STRINGER_D_END at the tips, which rest on the
# ground, to STRINGER_D at mid-span; vertical cut at each joint and at the ends.
STRINGER_W = 0.08
STRINGER_D, STRINGER_D_END = 0.12, 0.03
STRINGER_Y = 0.51               # beam centre; outer face at y = 0.55

# Deck planks: a vertical-cut slab per arc segment, sunk SINK into the beams.
PLANK_W = 1.12                  # across Y, overhanging the beams by 1 cm
PLANK_T = 0.045                 # vertical thickness
PLANK_GAP = 0.012               # daylight between planks
DECK = PLANK_T - SINK           # deck top above the plank bed

# Balustrade: posts clamp the outside of the beams, rails are inset into the posts.
POST_X = (1.465, 1.046, 0.628, 0.209)   # mirrored in X; the first is the end post
POST_W, POST_D = 0.06, 0.055    # mid post: along X, along Y (inner face 5 mm into the beam)
POST_Y = 0.5725                 # mid post and rail centre; outer face at y = 0.60
POST_FOOT = 0.03                # mid posts stop this far above the beam underside
END_POST = 0.07                 # end post (oyabashira): square, stands on the ground
END_POST_Y = 0.565              # outer face at y = 0.60
RAIL_TOP = (0.975, 0.045, 0.05) # centre height above the deck, width (Y), height (Z): top face at 1.0
RAIL_MID = (0.50, 0.04, 0.04)
POST_RISE, END_POST_RISE = 0.03, 0.10   # post tops above the top rail


def _bed(x):
    """The plank bed (the stringer top) on the parabola: 0.03 at the tips, 0.43 at the crest."""
    return STRINGER_D_END + RISE * (1.0 - (2.0 * x / LENGTH) ** 2)


def _sole(x):
    """The stringer underside: the bed less a depth that tapers to the tips, so it is 0 at x = +-1.5."""
    return _bed(x) - (STRINGER_D_END + (STRINGER_D - STRINGER_D_END) * (1.0 - (2.0 * x / LENGTH) ** 2))


def _chord(curve, x):
    """`curve` joined straight between the joints (the polyline every part follows), at x."""
    x = max(-LENGTH / 2, min(LENGTH / 2, x))
    j = min(int((x + LENGTH / 2) / (LENGTH / PLANKS)), PLANKS - 1)
    xa, xb = JOINTS[j], JOINTS[j + 1]
    t = (x - xa) / (xb - xa)
    return curve(xa) + t * (curve(xb) - curve(xa))


def _deck_top(x):
    return _chord(_bed, x) + DECK


def _strip(p, rings, color):
    """A closed strip: quads between consecutive 4-vertex rings plus two end caps."""
    verts = [[p.bm.verts.new(Vector(c)) for c in ring] for ring in rings]
    faces = [p.bm.faces.new(list(reversed(verts[0]))), p.bm.faces.new(verts[-1])]
    for a, b in zip(verts, verts[1:]):
        for i in range(4):
            faces.append(p.bm.faces.new([a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]]))
    return p.paint(faces, color)


def build():
    p = Piece("sakura_garden_bridge_3m", "garden", footprint=(LENGTH, WIDTH))

    # Stringers: one crescent beam each side, tips on the ground at x = +-1.5.
    for sy in (-1, 1):
        y0, y1 = sy * (STRINGER_Y - STRINGER_W / 2), sy * (STRINGER_Y + STRINGER_W / 2)
        rings = [[(x, y0, _sole(x)), (x, y1, _sole(x)), (x, y1, _bed(x)), (x, y0, _bed(x))]
                 for x in JOINTS]
        _strip(p, rings, "wood")

    # Deck: ten planks, each a vertical-cut slab following its arc segment.
    # Built in the XZ plane and extruded along -Y across the full plank width.
    for j in range(PLANKS):
        xa, xb = JOINTS[j] + PLANK_GAP / 2, JOINTS[j + 1] - PLANK_GAP / 2
        za, zb = _chord(_bed, xa) - SINK, _chord(_bed, xb) - SINK
        pts = [(xa, za), (xb, zb), (xb, zb + PLANK_T), (xa, za + PLANK_T)]
        p.prism(pts, PLANK_W, at=(0, PLANK_W / 2, 0), rot=(90, 0, 0), color="wood_light")

    # Posts: end posts stand on the ground astride the beam tips; mid posts
    # clamp the outer face of the beam and stop part-way down its side.
    rail_top_z = RAIL_TOP[0] + RAIL_TOP[2] / 2      # 1.0: the top rail's upper face above the deck
    for sy in (-1, 1):
        for sx in (-1, 1):
            for i, px in enumerate(POST_X):
                x = sx * px
                if i == 0:
                    h = _deck_top(x) + rail_top_z + END_POST_RISE
                    p.box((END_POST, END_POST, h), at=(x, sy * END_POST_Y, 0), color="wood_dark")
                else:
                    z0 = _chord(_sole, x) + POST_FOOT
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

    obj = p.finish()
    obj["sakura_tris_max"] = TRIS_MAX
    return obj
