"""A chabudai: a round 0.8 m hinoki tea table 0.33 m high, its wood top rimmed in dark wood over a square apron and four short tapered legs that splay outward to flat feet."""
import bmesh
from mathutils import Vector

from sakura_kit.contract import Piece

TOP_R = 0.40        # round top, 0.8 m across
TOP_T = 0.04        # top thickness
TOP_Z = 0.33        # height of the top surface
SEGMENTS = 10       # contract: round things use 6 to 10 segments

APRON_W = 0.03      # square apron frame under the top, where the legs attach
APRON_H = 0.05
LEG_AT = 0.24       # leg head centre (x and y), on the apron corners
FOOT_AT = 0.29      # foot centre: 0.05 m further out, so the legs splay
LEG_HEAD = 0.05     # leg section at the top
LEG_FOOT = 0.04     # slightly thinner at the foot


def _leg(p, foot, head, height, foot_w, head_w, color):
    """A tapered leg sheared between a flat square foot on the ground and a
    square head under the top. Side faces are trapezoids with parallel edges,
    so every quad stays planar and the foot sits flat at z = 0."""
    fx, fy = foot
    hx, hy = head
    a, b = foot_w / 2, head_w / 2
    v = lambda x, y, z: p.bm.verts.new(Vector((x, y, z)))
    b0, b1, b2, b3 = v(fx - a, fy - a, 0), v(fx + a, fy - a, 0), v(fx + a, fy + a, 0), v(fx - a, fy + a, 0)
    t0, t1, t2, t3 = (v(hx - b, hy - b, height), v(hx + b, hy - b, height),
                      v(hx + b, hy + b, height), v(hx - b, hy + b, height))
    faces = [
        p.bm.faces.new([b3, b2, b1, b0]),   # foot, faces -Z
        p.bm.faces.new([t0, t1, t2, t3]),   # head, faces +Z
        p.bm.faces.new([b0, b1, t1, t0]),   # -Y side
        p.bm.faces.new([b1, b2, t2, t1]),   # +X side
        p.bm.faces.new([b2, b3, t3, t2]),   # +Y side
        p.bm.faces.new([b3, b0, t0, t3]),   # -X side
    ]
    return p.paint(faces, color)


def build():
    p = Piece("sakura_prop_table_low", "prop")
    top_z0 = TOP_Z - TOP_T                      # underside of the top

    # Top: a 10-sided disc. The n-gon caps are triangulated so the mesh is
    # quads and tris only; the rim and underside are dark, the surface pale.
    disc = p.cylinder(TOP_R, TOP_T, at=(0, 0, top_z0), segments=SEGMENTS, color="wood_dark")
    caps = [f for f in disc if len(f.verts) > 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"]
    p.paint(tris, "wood_dark")
    p.paint(p.faces_facing(tris, (0, 0, 1)), "wood")

    # Apron: four dark rails in a square under the top, running leg to leg.
    apron_z = top_z0 - APRON_H
    span = 2 * LEG_AT
    for s in (-LEG_AT, LEG_AT):
        p.box((span, APRON_W, APRON_H), at=(0, s, apron_z), color="wood_dark")
        p.box((APRON_W, span, APRON_H), at=(s, 0, apron_z), color="wood_dark")

    # Legs: heads on the apron corners touching the top, feet splayed outward.
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(p, (sx * FOOT_AT, sy * FOOT_AT), (sx * LEG_AT, sy * LEG_AT),
                 top_z0, LEG_FOOT, LEG_HEAD, "wood_dark")

    return p.finish()
