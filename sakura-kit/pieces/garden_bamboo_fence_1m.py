"""Yotsume-gaki, a 1 m chainable segment of open bamboo lattice fence 1 m tall: two horizontal bamboo rails running flush from x = -0.5 to 0.5, six 3.5 cm vertical culms (with node rings) standing on the ground and alternating in front of and behind the rails, each crossing bound with a dark palm-rope knot."""
import bmesh

from sakura_kit.contract import Piece

LENGTH = 1.0            # along X; rail ends flush with x = +-0.5 so segments chain
HEIGHT = 1.0
SEGMENTS = 6            # contract: round things use 6 to 10 segments

CULM_R = 0.0175         # 3.5 cm across
CULM_N = 6
CULM_FLAT = CULM_R * 0.8660254   # a 6-gon's flat-to-centre distance (cos 30 deg)
RAIL_R = 0.015
RAIL_Z = (0.30, 0.76)   # rail centre heights
SINK = 0.004            # a culm is pressed this far into its rail so the two shells overlap
CULM_Y = RAIL_R + CULM_FLAT - SINK     # 0.0262: culm axis offset in front of / behind the rail

# Rope knot at each crossing: a dark band wrapping the culm and reaching back
# just past the rail's far face, so it reads from both sides of the fence.
KNOT_PAD = 0.004
KNOT_W = 2 * CULM_R + 2 * KNOT_PAD                 # 0.043 along X
KNOT_H = 2 * RAIL_R * 0.8660254 + 2 * KNOT_PAD     # 0.034: rail is 0.026 tall (flats top and bottom)
KNOT_Y0 = -(RAIL_R + 0.002)                        # far side of the rail, +2 mm
KNOT_Y1 = CULM_Y + CULM_FLAT + 0.003               # outer face of the culm, +3 mm

# Node rings: a slightly swollen darker band every 0.38 m, staggered per culm
# so the fence does not look stamped; none within a rail's knot band.
NODE_H = 0.02
NODE_FLARE = 0.003
NODE_Z = (0.14, 0.52, 0.90)
NODE_OFFSET = (0.00, 0.05, 0.08, 0.03, 0.07, 0.01)


def _capped(p, radius, depth, at, rot, color, cap_color, anchor="bottom"):
    """A capped 6-sided cylinder whose hexagonal caps are triangulated (quads and tris only)."""
    faces = p.cylinder(radius, depth, at=at, rot=rot, segments=SEGMENTS, color=color, anchor=anchor)
    caps = [f for f in faces if len(f.verts) > 4]
    sides = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"]
    p.paint(tris, cap_color)
    return sides + tris


def build():
    p = Piece("sakura_garden_bamboo_fence_1m", "garden")

    # Two rails along X, a flat face up and down, cut ends showing the darker node colour.
    for z in RAIL_Z:
        _capped(p, RAIL_R, LENGTH, at=(0, 0, z), rot=(0, 90, 0), color="bamboo", cap_color="bamboo_node", anchor="center")

    # Six culms standing on the ground, alternating in front of (+Y) and behind (-Y) the rails.
    for i in range(CULM_N):
        x = -LENGTH / 2 + (i + 0.5) * LENGTH / CULM_N
        side = 1 if i % 2 == 0 else -1
        y = side * CULM_Y
        # Spun 30 degrees so a flat face looks out of the fence (vertices on +-X).
        _capped(p, CULM_R, HEIGHT, at=(x, y, 0), rot=(0, 0, 30), color="bamboo", cap_color="bamboo_node")
        for z in NODE_Z:
            p.cylinder(CULM_R + NODE_FLARE, NODE_H, at=(x, y, z + NODE_OFFSET[i]), rot=(0, 0, 30),
                       segments=SEGMENTS, color="bamboo_node", caps=False)
        # A rope knot at each rail crossing.
        for z in RAIL_Z:
            yc = side * (KNOT_Y0 + KNOT_Y1) / 2
            p.box((KNOT_W, KNOT_Y1 - KNOT_Y0, KNOT_H), at=(x, yc, z), color="lattice", anchor="center")

    return p.finish()
