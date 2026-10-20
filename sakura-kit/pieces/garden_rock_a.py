"""Garden boulder A: a knee-high irregular granite rock about 0.8 x 0.6 x 0.5 m
with a smaller lump fused to one flank, flat-bottomed so it sits on the ground,
its shaded underside and lower flanks in darker stone."""
import math
import random

import bmesh
from mathutils import Matrix, Vector

from sakura_kit.contract import Piece

SEED = 41


def _verts_of(faces):
    """Vertices of `faces` in a stable order (sets of BMVerts are not)."""
    seen, out = set(), []
    for f in faces:
        for v in f.verts:
            if v not in seen:
                seen.add(v)
                out.append(v)
    return out


def _lump(p, rng, radius, scale, at, yaw, jitter):
    """One irregular rock shell: a sub-1 icosphere scaled unevenly, rotated
    about Z and with every vertex pushed in or out radially by a seeded amount."""
    # bmesh.ops.create_icosphere counts the bare icosahedron as subdivisions=1, so
    # the 80-tri "subdivision-1" sphere of the contract is subdivisions=2 here.
    faces = p.sphere(radius, at=(0, 0, 0), subdivisions=2, color="stone", scale=scale)
    verts = _verts_of(faces)
    for v in verts:
        v.co *= rng.uniform(1.0 - jitter, 1.0 + jitter)
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    bmesh.ops.transform(p.bm, matrix=m, verts=verts)
    return faces


def build():
    p = Piece("sakura_garden_rock_a", "garden")
    rng = random.Random(SEED)

    # Main boulder: ~0.8 wide, ~0.6 deep, its belly sunk below the ground line.
    _lump(p, rng, 1.0, (0.37, 0.29, 0.30), at=(-0.03, 0.02, 0.21), yaw=18, jitter=0.10)
    # Smaller lump fused into the front-right flank, lower and squatter.
    _lump(p, rng, 1.0, (0.22, 0.18, 0.15), at=(0.18, -0.15, 0.09), yaw=-35, jitter=0.08)

    bm = p.bm
    # Centre the footprint on the origin in XY.
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    bmesh.ops.translate(bm, vec=(-cx, -cy, 0.0), verts=bm.verts[:])
    # Flatten everything below the ground onto z = 0: the rock sits flat.
    for v in bm.verts:
        if v.co.z < 0.0:
            v.co.z = 0.0

    # Colour: stone overall, darker on the underside and the lower, inward-leaning flanks.
    faces = list(bm.faces)
    p.paint(faces, "stone")
    p.paint(p.faces_facing(faces, (0, 0, -1), min_dot=0.25), "stone_dark")
    return p.finish()
