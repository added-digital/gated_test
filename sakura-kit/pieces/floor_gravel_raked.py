"""Karesansui tile: a 1 x 1 m gravel slab raked into five low parallel ridges with a triangular crest, running edge to edge along X."""
import bmesh

from sakura_kit.contract import Piece, FLOOR_T, GRID

RIDGES = 5        # pitch GRID / RIDGES, centred, so the raking continues across Y seams too
RIDGE_W = 0.05    # ridge base width (Y) at z = 0
RIDGE_H = 0.01    # crest height above the walking surface (contract allows <= 0.02)


def build():
    p = Piece("sakura_floor_gravel_raked", "floor")
    # The slab: walking surface (gravel) at z = 0, hanging FLOOR_T below.
    slab = p.box((GRID, GRID, FLOOR_T), at=(0, 0, -FLOOR_T), color="gravel")
    p.paint(p.faces_facing(slab, (0, 0, -1)), "stone_dark")
    # Ridges: triangular prisms the full tile length, 1 cm tall, sitting on the slab.
    # Each is a closed wedge with only its base removed (the base lies flat on the
    # slab and is never visible): 2 sloped quads + 2 triangular end caps = 6 tris, so
    # 5 ridges + slab = 42 tris. The end caps stay so a ridge is closed wherever its
    # end is exposed (a moss, path or tatami neighbour, a rotated gravel tile, or the
    # edge of a gravel patch); against another gravel tile the caps meet back to back.
    #
    # prism() extrudes a local-XY polygon along local +Z; rot (0, 90, 0) maps local Z
    # to world +X and local X to world -Z, so the triangle below is the ridge's YZ
    # profile (points listed counter-clockwise, which prism needs for outward normals)
    # and the extrusion runs from x = -GRID/2 to x = +GRID/2.
    pitch = GRID / RIDGES
    profile = [(0, -RIDGE_W / 2), (0, RIDGE_W / 2), (-RIDGE_H, 0)]   # (local x = -z, local y = y)
    for i in range(RIDGES):
        y = -GRID / 2 + pitch * (i + 0.5)
        ridge = p.prism(profile, GRID, at=(-GRID / 2, y, 0), rot=(0, 90, 0), color="gravel_line")
        bmesh.ops.delete(p.bm, geom=p.faces_facing(ridge, (0, 0, -1)), context="FACES")
    return p.finish()
