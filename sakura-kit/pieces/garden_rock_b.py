"""Garden rock cluster B: three small flat-bottomed granite rocks (about 0.35, 0.28 and 0.21 m across; two pale, one dark) grouped in a loose triangle inside a 0.7 m footprint."""
import math
import random

import bmesh
from mathutils import Matrix, Vector

from sakura_kit.contract import Piece

SEED = 43
FOOTPRINT = 0.7


def _verts_of(faces):
    """Vertices of `faces` in a stable order (sets of BMVerts are not)."""
    seen, out = set(), []
    for f in faces:
        for v in f.verts:
            if v not in seen:
                seen.add(v)
                out.append(v)
    return out


def _rock(p, rng, scale, at, yaw, color, jitter=0.10):
    """One irregular rock shell: a sub-1 icosphere (bmesh subdivisions=2 is the
    80-tri sphere of the contract) scaled unevenly, every vertex pushed in or
    out radially by a seeded amount, then rotated about Z and moved into place."""
    faces = p.sphere(1.0, at=(0, 0, 0), subdivisions=2, color=color, scale=scale)
    verts = _verts_of(faces)
    for v in verts:
        v.co *= rng.uniform(1.0 - jitter, 1.0 + jitter)
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    bmesh.ops.transform(p.bm, matrix=m, verts=verts)
    return faces


def build():
    p = Piece("sakura_garden_rock_b", "garden", footprint=(FOOTPRINT, FOOTPRINT))
    rng = random.Random(SEED)

    # Each rock's centre sits below its vertical half-extent so the belly dips
    # under the ground line and is clipped flat below.
    rocks = [
        # (scale (x, y, z) half-extents, position, yaw, colour)
        ((0.190, 0.150, 0.125), (-0.12, 0.06, 0.095), 25, "stone"),       # largest, pale  (~0.35 m)
        ((0.150, 0.125, 0.105), (0.18, 0.10, 0.080), -40, "stone_dark"),  # medium, dark   (~0.28 m)
        ((0.115, 0.100, 0.080), (0.08, -0.18, 0.060), 60, "stone"),       # smallest, pale (~0.21 m)
    ]
    shells = []
    for scale, at, yaw, color in rocks:
        shells.append((_rock(p, rng, scale, at, yaw, color), color))

    bm = p.bm
    # Centre the cluster's footprint on the origin in XY.
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    bmesh.ops.translate(bm, vec=(-cx, -cy, 0.0), verts=bm.verts[:])
    # Flatten everything below the ground onto z = 0: every rock sits flat.
    for v in bm.verts:
        if v.co.z < 0.0:
            v.co.z = 0.0

    # Colour: the pale rocks go darker on the underside and the lower,
    # inward-leaning flanks; the dark rock stays dark all over.
    for faces, color in shells:
        if color == "stone":
            p.paint(p.faces_facing(faces, (0, 0, -1), min_dot=0.25), "stone_dark")
    return p.finish()
