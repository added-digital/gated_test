"""A 1 x 1 m tatami floor tile: woven straw with the dark cloth border (heri)
along two opposite edges, as on a real mat laid in a half-mat grid."""
from sakura_kit.contract import Piece, FLOOR_T, GRID


def build():
    p = Piece("sakura_floor_tatami", "floor")
    # The slab: top face at z = 0, hanging FLOOR_T below.
    slab = p.box((GRID, GRID, FLOOR_T), at=(0, 0, -FLOOR_T), color="tatami")
    p.paint(p.faces_facing(slab, (0, 0, -1)), "tatami_edge")
    # Cloth borders: two thin strips sitting on the surface, along the X edges.
    edge = 0.045
    for y in (-GRID / 2 + edge / 2, GRID / 2 - edge / 2):
        p.box((GRID, edge, 0.004), at=(0, y, 0), color="tatami_edge")
    return p.finish()
