"""A 1 x 1 m moss ground tile: a flat cushion of moss with three small darker hummocks swelling from its surface.
Declares sakura_tris_max = 57: the hummocks are modelled (detail is geometry, never texture) as subdivision-1
icospheres, 15 tris each once the buried bottom cap is removed, on top of the 12-tri slab."""
import math

import bmesh
from mathutils import Matrix

from sakura_kit.contract import Piece, FLOOR_T, GRID

# An icosahedron (subdivision-1 icosphere) has its lower vertex ring at z = -r / sqrt(5).
# Lifting each hummock by that amount seats the ring exactly on the walking surface, so the
# 5 faces below it are buried in the slab and can be dropped without opening a visible gap.
RING = 1.0 / math.sqrt(5.0)
RZ = 0.013          # vertical semi-axis: dome rises (1 + RING) * RZ = 0.0188 m (contract allows <= 0.02)
# The two rings of an icosahedron share one radius, so the band between them zigzags with an
# undercut. Spreading the rim ring outward turns that into a foot that slopes out to the floor.
SPREAD = 1.35

# Hummocks: (x, y, radius, x-stretch, y-stretch, spin degrees). Base ends up ~0.12 m across and
# at least 0.15 m from every edge so neighbouring tiles still meet flat; stretches and spins
# differ so no two read as copies.
HUMMOCKS = [
    (-0.24,  0.17, 0.050, 1.00, 1.00,  0.0),
    ( 0.27,  0.08, 0.046, 1.12, 0.92, 40.0),
    (-0.03, -0.26, 0.048, 0.94, 1.08, 75.0),
]


def build():
    p = Piece("sakura_floor_moss", "floor")
    # The slab: moss walking surface at z = 0, hanging FLOOR_T below; sides and bottom darker.
    slab = p.box((GRID, GRID, FLOOR_T), at=(0, 0, -FLOOR_T), color="moss_dark")
    p.paint(p.faces_facing(slab, (0, 0, 1)), "moss")
    # Hummocks: tiny flattened icospheres in moss_dark, lower ring flush with the surface.
    for x, y, r, sx, sy, spin in HUMMOCKS:
        faces = p.sphere(r, at=(x, y, RING * RZ), subdivisions=1, color="moss_dark",
                         scale=(sx, sy, RZ / r))
        buried = [f for f in faces if f.calc_center_median().z < -1e-6]
        bmesh.ops.delete(p.bm, geom=buried, context="FACES")
        verts = list({v for f in faces if f.is_valid for v in f.verts})
        for v in verts:
            if v.co.z < 1e-6:                       # rim vertex: spread it to make the foot
                v.co.x = x + (v.co.x - x) * SPREAD
                v.co.y = y + (v.co.y - y) * SPREAD
        bmesh.ops.rotate(p.bm, cent=(x, y, 0), matrix=Matrix.Rotation(math.radians(spin), 3, "Z"), verts=verts)
    obj = p.finish()
    obj["sakura_tris_max"] = 57
    return obj
