"""A single fallen sakura petal for particle systems: a flat 0.05 x 0.035 m obovate outline (short blunt base claw, widest near the tip, a small notch in the rounded tip) built from coplanar quads and tris in sakura_light, lying on z = 0."""
from mathutils import Vector

from sakura_kit.contract import Piece

LENGTH, WIDTH = 0.05, 0.035     # bounding box of the petal (m)
BASE_HALF = 0.0022              # half-width of the blunt base edge (the claw)
MID = (-0.012, 0.011)           # a point on each side between base and shoulder
SHOULDER_X = 0.012              # widest point at ~74% of the length: obovate, not a kite
TIP_ROUND = (0.0205, 0.0115)    # a point on each side rounding the tip lobe
LOBE_HALF = 0.0037              # half-width of the tip across the two lobes
NOTCH_DEPTH = 0.0028            # how far the tip nick cuts back toward the base
COLOUR = "sakura_light"


def build():
    p = Piece("sakura_fx_petal", "fx")
    bm = p.bm
    hx, hy = LENGTH / 2, WIDTH / 2
    # One side of the outline from base to tip; the other side is its mirror.
    side = [(-hx, BASE_HALF), MID, (SHOULDER_X, hy), TIP_ROUND, (hx, LOBE_HALF)]
    left = [bm.verts.new(Vector((x, y, 0.0))) for x, y in side]
    right = [bm.verts.new(Vector((x, -y, 0.0))) for x, y in side]
    notch = bm.verts.new(Vector((hx - NOTCH_DEPTH, 0.0, 0.0)))
    base_l, mid_l, shoulder_l, round_l, tip_l = left
    base_r, mid_r, shoulder_r, round_r, tip_r = right
    # Faces wound counter-clockwise seen from above, so they point +Z. Three
    # convex trapezoids run up the body; the tip is three tris so the notch's
    # reflex corner never sits inside a quad.
    faces = [
        bm.faces.new([base_r, mid_r, mid_l, base_l]),
        bm.faces.new([mid_r, shoulder_r, shoulder_l, mid_l]),
        bm.faces.new([shoulder_r, round_r, round_l, shoulder_l]),
        bm.faces.new([round_r, tip_r, notch]),
        bm.faces.new([round_r, notch, round_l]),
        bm.faces.new([notch, tip_l, round_l]),
    ]
    p.paint(faces, COLOUR)
    return p.finish()
