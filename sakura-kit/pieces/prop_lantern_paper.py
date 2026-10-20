"""A standing chochin: a 0.3 m paper lantern 0.45 m tall, ribbed with four dark bamboo hoops and capped in dark wood, sitting on a short turned post over a square dark base plate, 0.7 m in all."""
import math

import bmesh

from sakura_kit.contract import Piece

SEGMENTS = 10       # contract: round things use 6 to 10 segments

PLATE = 0.25        # square base plate on the ground
PLATE_T = 0.02
POST_R0 = 0.035     # turned post, a little wider at the foot
POST_R1 = 0.028
POST_TOP = 0.17     # top of the post; the bottom cap rests here
COLLAR = 0.09       # square collar between the post and the bottom cap
COLLAR_T = 0.02

CAP_R = 0.17        # dark wood caps, a little wider than the paper
CAP_T = 0.03
PAPER_R = 0.15      # the paper body, 0.3 m across
PAPER_H = 0.45
PAPER_Z0 = POST_TOP + CAP_T              # 0.20: paper starts above the bottom cap
PAPER_Z1 = PAPER_Z0 + PAPER_H            # 0.65: top cap starts here
SINK = 0.005        # tube ends sunk into the caps so no two faces are coplanar

RING_R = 0.162      # hoop rings, proud of the paper by about 1 cm
RING_T = 0.02
RINGS = 4

KNOB = 0.04         # small square knob on the top cap
KNOB_T = 0.02       # total height: 0.65 + 0.03 + 0.02 = 0.70

CREST_R = 0.03      # the one pink accent: a hexagonal mon on the front face
CREST_T = 0.012
CREST_ANGLE = -36   # side-face centre nearest the preview camera


def _disc(p, radius, depth, at, color, segments=SEGMENTS, rot=(0, 0, 0), radius_top=None):
    """A capped cylinder whose n-gon caps are triangulated (quads and tris only)."""
    faces = p.cylinder(radius, depth, at=at, rot=rot, segments=segments, color=color, radius_top=radius_top)
    caps = [f for f in faces if len(f.verts) > 4]
    sides = [f for f in faces if len(f.verts) <= 4]
    tris = bmesh.ops.triangulate(p.bm, faces=caps)["faces"]
    p.paint(tris, color)
    return sides + tris


def build():
    p = Piece("sakura_prop_lantern_paper", "prop")

    # Stand: dark base plate on the ground, a short turned post sunk into it,
    # and a square collar under the lantern so the post does not read as a stem.
    p.box((PLATE, PLATE, PLATE_T), at=(0, 0, 0), color="wood_dark")
    _disc(p, POST_R0, POST_TOP - PLATE_T + 2 * SINK, at=(0, 0, PLATE_T - SINK), color="wood",
          segments=8, radius_top=POST_R1)
    p.box((COLLAR, COLLAR, COLLAR_T + SINK), at=(0, 0, POST_TOP - COLLAR_T), color="wood_dark")

    # Bottom cap, paper tube, top cap. The tube is open-ended and its ends sit
    # inside the caps, so the closed caps hide the interior.
    _disc(p, CAP_R, CAP_T, at=(0, 0, POST_TOP), color="wood_dark")
    p.cylinder(PAPER_R, PAPER_H + 2 * SINK, at=(0, 0, PAPER_Z0 - SINK), segments=SEGMENTS,
               color="paper", caps=False)
    _disc(p, CAP_R, CAP_T, at=(0, 0, PAPER_Z1), color="wood_dark")
    p.box((KNOB, KNOB, KNOB_T + SINK), at=(0, 0, PAPER_Z1 + CAP_T - SINK), color="wood_dark")

    # Four dark hoops around the paper, evenly spaced along the body.
    for i in range(RINGS):
        z = PAPER_Z0 + PAPER_H * (i + 1) / (RINGS + 1) - RING_T / 2
        _disc(p, RING_R, RING_T, at=(0, 0, z), color="lattice")

    # Crest: a flat hexagonal mon on the side face between the middle hoops.
    # The disc's axis points out through that face (rot X 90 turns Z to -Y,
    # then Z 54 swings -Y round to the -36 degree face normal).
    apothem = PAPER_R * math.cos(math.pi / SEGMENTS)
    r0 = apothem - CREST_T / 3
    z_crest = PAPER_Z0 + PAPER_H / 2
    at = (r0 * math.cos(math.radians(CREST_ANGLE)), r0 * math.sin(math.radians(CREST_ANGLE)), z_crest)
    _disc(p, CREST_R, CREST_T, at=at, color="sakura_deep", segments=6, rot=(90, 0, CREST_ANGLE + 90))

    return p.finish()
