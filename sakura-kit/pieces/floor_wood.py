"""A 1 x 1 m engawa veranda floor tile: five pale hinoki planks along X with 4 mm shadow gaps (half a gap at each Y edge so tiles repeat), tops at z = 0 on a dark wood joist slab, end grain banding the X ends."""
from mathutils import Vector

from sakura_kit.contract import Piece, FLOOR_T, GRID

PLANKS = 5
GAP = 0.004          # shadow gap between planks
PLANK_T = 0.03       # plank thickness; the slab fills the rest of FLOOR_T
TOPS = ("wood_light", "wood", "wood_light", "wood_light", "wood")  # per-plank tone, deterministic


def build():
    p = Piece("sakura_floor_wood", "floor")
    half = GRID / 2
    z_top, z_bed = 0.0, -PLANK_T

    def quad(pts, color):
        """One face from four (x, y, z) corners, wound as given."""
        verts = [p.bm.verts.new(Vector(c)) for c in pts]
        return p.paint([p.bm.faces.new(verts)], color)

    # Joist slab under the planks: a closed box, top at the plank bed.
    p.box((GRID, GRID, FLOOR_T - PLANK_T), at=(0, 0, -FLOOR_T), color="wood_dark")

    # Planks: each an open shell (top + two long sides) sitting on the slab,
    # so the gap between neighbours shows the dark slab at the bottom. The
    # three faces share vertices, so finish() orients the shell as one piece.
    width = (GRID - PLANKS * GAP) / PLANKS
    for i in range(PLANKS):
        y0 = -half + GAP / 2 + i * (width + GAP)
        y1 = y0 + width
        v = lambda x, y, z: p.bm.verts.new(Vector((x, y, z)))
        bl0, bl1, br0, br1 = v(-half, y0, z_bed), v(-half, y1, z_bed), v(half, y0, z_bed), v(half, y1, z_bed)
        tl0, tl1, tr0, tr1 = v(-half, y0, z_top), v(-half, y1, z_top), v(half, y0, z_top), v(half, y1, z_top)
        p.paint([p.bm.faces.new([tl0, tr0, tr1, tl1])], TOPS[i])   # top, faces +Z
        p.paint([p.bm.faces.new([bl0, br0, tr0, tl0])], "wood")    # near side, faces -Y
        p.paint([p.bm.faces.new([br1, bl1, tl1, tr1])], "wood")    # far side, faces +Y

    # End-grain band closing the plank ends at the X edges (one quad each side).
    quad([(half, -half, z_bed), (half, half, z_bed), (half, half, z_top), (half, -half, z_top)], "wood")
    quad([(-half, half, z_bed), (-half, -half, z_bed), (-half, -half, z_top), (-half, half, z_top)], "wood")

    return p.finish()
