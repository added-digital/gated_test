"""The Sakura kit style contract, as code.

Every piece in the kit is built through this module, so the rules below are
not a style guide someone has to remember: they are the only way to make a
piece. The human-readable version is CONTRACT.md next to this package.

Rules in one screen:
  * 1 Blender unit = 1 metre. Z is up while modelling; glTF export flips to Y-up.
  * Grid: floors are exactly 1 x 1 m. Walls and doors are 1 m wide, 2.5 m tall.
  * Origin: bottom-centre of the footprint for everything that stands on the
    ground. Floors are the exception: origin is the centre of the TOP face, so
    a prop placed at the same grid point stands on the floor.
  * One material for the whole kit (`sakura_palette`), a flat 8x4 palette
    texture. A face gets its colour by pointing its UVs at one palette cell.
  * No textures other than the palette, no vertex colours, no modifiers left
    unapplied, no n-gons.
  * Naming: sakura_<category>_<name>[_<variant>], lowercase, snake_case.
"""
from __future__ import annotations

import math
import os
import re
from collections import OrderedDict

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# --------------------------------------------------------------------------
# Dimensions (metres)
# --------------------------------------------------------------------------
GRID = 1.0            # floor tile and wall segment length
SUB_GRID = 0.25       # props may be modelled to this finer grid
WALL_H = 2.5          # wall, door and pillar height
DOOR_H = 2.0          # a shoji panel opening; the 0.5 m above is lintel
FLOOR_T = 0.1         # floor tiles hang this far below z = 0
FLOOR_T_MAX = 0.3     # the deepest a slab may hang: the pond tile (water 0.2 below the rim, 0.1 of stone under it)
TOL = 0.002           # dimensional tolerance when validating
CONTRACT_VERSION = "0.2"

# A wall must never poke past the post it meets, so the thickness cap is a
# relation to the post, not a free number. The pillar piece reads PILLAR_POST.
PILLAR_POST = 0.15
WALL_T_MAX = PILLAR_POST - 0.01

# The first-person body the kit is scaled for (breaks.md 2026-10-21, the human
# walk): the engine's capsule, eye and camera. CONTRACT.md "Player" is the same numbers.
PLAYER_RADIUS = 0.30  # capsule radius, m
PLAYER_HEIGHT = 1.80  # capsule height, m
PLAYER_EYE = 1.60     # camera height above the feet, m
PLAYER_FOV_H = 90     # degrees, HORIZONTAL (Godot: Camera3D keep_aspect KEEP_WIDTH, fov 90)
PLAYER_SPEED = 3.5    # walking speed, m/s
CLEARANCE = 0.8       # metres a layout keeps free around furniture: the body must pass

# One sun for previews, the assembled scene and the engine's directional light.
SUN_ELEVATION = 40    # degrees above the horizon
SUN_AZIMUTH = 35      # degrees, Blender Z rotation
SUN_ENERGY = 1.5
AMBIENT = (0.93, 0.92, 0.90)

KIT_PREFIX = "sakura"
NAME_RE = re.compile(r"^sakura_(floor|wall|door|pillar|roof|prop|garden|tree|fx)_[a-z0-9]+(_[a-z0-9]+)*$")

# Per-category rules: triangle budget and the footprint envelope the validator
# enforces. `exact` footprints must match to TOL; `max` footprints may be smaller.
CATEGORY_RULES = {
    # category: (tri budget, footprint rule, (x, y) size, (z min, z max))
    "floor":  dict(tris=64,   footprint="exact", size=(GRID, GRID),  z=(-FLOOR_T_MAX, 0.02)),
    "wall":   dict(tris=120,  footprint="wall",  size=(GRID, WALL_T_MAX), z=(0.0, WALL_H)),
    "door":   dict(tris=300,  footprint="wall",  size=(GRID, WALL_T_MAX), z=(0.0, WALL_H)),
    "pillar": dict(tris=60,   footprint="max",   size=(0.25, 0.25),  z=(0.0, WALL_H)),
    "roof":   dict(tris=160,  footprint="roof",  size=(GRID, 2.5),   z=(0.0, 1.5)),
    "prop":   dict(tris=450,  footprint="max",   size=(GRID, GRID),  z=(0.0, WALL_H)),
    "garden": dict(tris=600,  footprint="max",   size=(3.0, 2.0),    z=(0.0, 3.0)),
    "tree":   dict(tris=1400, footprint="max",   size=(3.0, 3.0),    z=(0.0, 5.0)),
    "fx":     dict(tris=12,   footprint="max",   size=(0.2, 0.2),    z=(0.0, 0.2)),
}

# --------------------------------------------------------------------------
# Palette: 32 named colours on an 8 x 4 texture. Order matters: it is the
# cell index. Add at the end, never reorder, or every piece recolours.
# --------------------------------------------------------------------------
PALETTE: "OrderedDict[str, str]" = OrderedDict([
    # blossoms
    ("sakura_light", "#F9DDE7"), ("sakura", "#F3B1C8"), ("sakura_deep", "#E58BAD"), ("sakura_bud", "#C9557F"),
    # wood (hinoki, cedar)
    ("wood_light", "#D2A977"), ("wood", "#B0865A"), ("wood_dark", "#7A5536"), ("bark", "#55402F"),
    # paper, lattice, plaster
    ("paper", "#F7F2E8"), ("paper_shadow", "#E9E2D3"), ("lattice", "#4A3A2E"), ("plaster", "#EDE6D6"),
    # tatami and textiles
    ("tatami", "#C2BC84"), ("tatami_edge", "#3F4D3F"), ("cushion", "#8E5A7A"), ("cushion_dark", "#6E4260"),
    # stone and gravel
    ("gravel", "#E4E0D5"), ("gravel_line", "#D2CDBF"), ("stone", "#A9A69D"), ("stone_dark", "#7E7B73"),
    # plants
    ("moss", "#6F924F"), ("moss_dark", "#55733C"), ("bamboo", "#8FB36F"), ("bamboo_node", "#637F4B"),
    # water and roof
    ("water", "#8FC0D6"), ("water_deep", "#6B9DB6"), ("roof_tile", "#4F535E"), ("roof_dark", "#33363E"),
    # accents
    ("vermilion", "#B8403B"), ("ink", "#2B2A2E"), ("gold", "#D9B45B"), ("white", "#FFFFFF"),
])
PALETTE_COLS, PALETTE_ROWS = 8, 4
PALETTE_CELL_PX = 16   # engines block-compress in 4x4 blocks; a 1 px swatch bleeds
assert len(PALETTE) == PALETTE_COLS * PALETTE_ROWS

# What each cell is FOR. A new theme swaps hexes by role and nothing else moves.
PALETTE_ROLES = {
    "accent":    ["sakura_light", "sakura", "sakura_deep", "sakura_bud", "vermilion", "gold"],
    "structure": ["wood_light", "wood", "wood_dark", "bark"],
    "panel":     ["paper", "paper_shadow", "plaster", "white"],
    "trim":      ["lattice", "ink", "tatami_edge"],
    "ground":    ["tatami", "gravel", "gravel_line", "stone", "stone_dark", "moss", "moss_dark"],
    "textile":   ["cushion", "cushion_dark"],
    "foliage":   ["bamboo", "bamboo_node"],
    "water":     ["water", "water_deep"],
    "roof":      ["roof_tile", "roof_dark"],
}
assert sorted(c for cells in PALETTE_ROLES.values() for c in cells) == sorted(PALETTE)

# Connector metadata for the structural categories: what each side of a piece
# expects to meet. Exported as glTF extras so an assembler can check adjacency.
SOCKET_DEFAULTS = {
    "floor":  dict(px="ground", nx="ground", py="ground", ny="ground"),
    "wall":   dict(px="wall", nx="wall", py="air", ny="air"),
    "door":   dict(px="wall", nx="wall", py="air", ny="air"),
    "pillar": dict(px="wall", nx="wall", py="wall", ny="wall"),
    "roof":   dict(px="roof", nx="roof", py="air", ny="air"),
}

MATERIAL_NAME = "sakura_palette"
PALETTE_FILENAME = "sakura_palette.png"


def palette_index(name: str) -> int:
    if name not in PALETTE:
        raise KeyError(f"'{name}' is not a palette colour. Use one of: {', '.join(PALETTE)}")
    return list(PALETTE).index(name)


def palette_uv(name: str) -> tuple[float, float]:
    """UV of the centre of a palette cell. Texture row 0 is the BOTTOM of the
    image in Blender's UV space, so row 0 of PALETTE is the bottom row."""
    i = palette_index(name)
    col, row = i % PALETTE_COLS, i // PALETTE_COLS
    return (col + 0.5) / PALETTE_COLS, (row + 0.5) / PALETTE_ROWS


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def write_palette_image(path: str) -> None:
    """Write the palette PNG: 8x4 cells of PALETTE_CELL_PX pixels each."""
    w, h = PALETTE_COLS * PALETTE_CELL_PX, PALETTE_ROWS * PALETTE_CELL_PX
    img = bpy.data.images.new("sakura_palette_tmp", w, h, alpha=False)
    px = [0.0] * (w * h * 4)
    colors = [hex_to_rgb(v) for v in PALETTE.values()]
    for y in range(h):
        for x in range(w):
            # An 8-bit image's `pixels` are written straight into its sRGB byte
            # buffer, so the hex values go in as they are (no linear conversion).
            r, g, b = colors[(y // PALETTE_CELL_PX) * PALETTE_COLS + x // PALETTE_CELL_PX]
            i = (y * w + x) * 4
            px[i:i + 4] = [r, g, b, 1.0]
    img.pixels[:] = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def get_material(palette_path: str) -> bpy.types.Material:
    """The one kit material: Principled BSDF fed by the palette, nearest filtering."""
    mat = bpy.data.materials.get(MATERIAL_NAME)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(MATERIAL_NAME)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    tex = nodes.new("ShaderNodeTexImage")
    if not os.path.exists(palette_path):
        write_palette_image(palette_path)
    img = bpy.data.images.load(palette_path)
    img.name = PALETTE_FILENAME
    tex.image = img
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# --------------------------------------------------------------------------
# Piece builder: a thin bmesh wrapper that makes every primitive carry a
# palette colour, so a piece is a handful of calls like
#     p = Piece("sakura_prop_table_low", "prop")
#     p.box((0.8, 0.8, 0.04), at=(0, 0, 0.28), color="wood")
#     obj = p.finish()
# --------------------------------------------------------------------------
class Piece:
    def __init__(self, name: str, category: str, footprint: tuple[float, float] | None = None,
                 walkable: bool = True, sockets: dict | None = None):
        if not NAME_RE.match(name):
            raise ValueError(f"'{name}' does not match the naming rule sakura_<category>_<name>")
        if name.split("_")[1] != category:
            raise ValueError(f"'{name}' is in category '{category}' but its name says '{name.split('_')[1]}'")
        self.name = name
        self.category = category
        self.footprint = footprint  # None = category default
        self.walkable = walkable    # floors only: can a character stand on it?
        self.sockets = sockets      # structural only: None = SOCKET_DEFAULTS[category]
        self.bm = bmesh.new()
        self.color_layer = self.bm.faces.layers.int.new("palette")

    # -- transforms ---------------------------------------------------------
    @staticmethod
    def _matrix(at, rot, scale=(1, 1, 1)) -> Matrix:
        return (Matrix.Translation(Vector(at))
                @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
                @ Matrix.Diagonal((*scale, 1.0)))

    def _paint(self, faces, color: str):
        idx = palette_index(color)
        for f in faces:
            f[self.color_layer] = idx
        return faces

    def _new_faces(self, before: set):
        return [f for f in self.bm.faces if f not in before]

    # -- primitives (all return the faces they created) --------------------
    def box(self, size, at=(0, 0, 0), rot=(0, 0, 0), color="wood", anchor="bottom"):
        """Cuboid of `size` (x, y, z). `anchor` 'bottom' puts `at` at the base
        centre (what you want for things that stand); 'center' at the middle."""
        sx, sy, sz = size
        offset = (0, 0, sz / 2) if anchor == "bottom" else (0, 0, 0)
        m = self._matrix(at, rot) @ Matrix.Translation(Vector(offset)) @ Matrix.Diagonal((sx, sy, sz, 1.0))
        before = set(self.bm.faces)
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        return self._paint(self._new_faces(before), color)

    def cylinder(self, radius, depth, at=(0, 0, 0), rot=(0, 0, 0), segments=8, color="wood",
                 radius_top=None, anchor="bottom", caps=True):
        """Cylinder (or truncated cone if `radius_top` differs) along local Z."""
        r2 = radius if radius_top is None else radius_top
        offset = (0, 0, depth / 2) if anchor == "bottom" else (0, 0, 0)
        m = self._matrix(at, rot) @ Matrix.Translation(Vector(offset))
        before = set(self.bm.faces)
        bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=segments,
                              radius1=radius, radius2=r2, depth=depth, matrix=m)
        return self._paint(self._new_faces(before), color)

    def cone(self, radius, depth, at=(0, 0, 0), rot=(0, 0, 0), segments=8, color="wood", anchor="bottom"):
        return self.cylinder(radius, depth, at, rot, segments, color, radius_top=0.0, anchor=anchor)

    def sphere(self, radius, at=(0, 0, 0), subdivisions=1, color="sakura", scale=(1, 1, 1)):
        """Icosphere; subdivisions=1 is the 20-tri icosahedron, 2 is 80 tris,
        3 is 320. Use 1 for hummocks and small blossoms, 2 for canopies."""
        m = self._matrix(at, (0, 0, 0), scale)
        before = set(self.bm.faces)
        bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius, matrix=m)
        return self._paint(self._new_faces(before), color)

    def plane(self, size, at=(0, 0, 0), rot=(0, 0, 0), color="paper"):
        """A single quad in local XY. Faces +Z before rotation."""
        sx, sy = size
        m = self._matrix(at, rot)
        before = set(self.bm.faces)
        bmesh.ops.create_grid(self.bm, x_segments=1, y_segments=1, size=0.5, matrix=m @ Matrix.Diagonal((sx, sy, 1, 1)))
        return self._paint(self._new_faces(before), color)

    def prism(self, points, height, at=(0, 0, 0), rot=(0, 0, 0), color="stone", color_top=None, color_bottom=None):
        """Extrude a convex-or-not polygon (list of (x, y)) straight up by `height`."""
        m = self._matrix(at, rot)
        before = set(self.bm.faces)
        verts_b = [self.bm.verts.new(m @ Vector((x, y, 0))) for x, y in points]
        verts_t = [self.bm.verts.new(m @ Vector((x, y, height))) for x, y in points]
        n = len(points)

        def cap(vs):
            # Quads and tris only: a cap with more than 4 corners becomes a fan
            # from its first vertex (fine for convex outlines, which rocks,
            # stones and basins are).
            if n <= 4:
                return [self.bm.faces.new(vs)]
            return [self.bm.faces.new([vs[0], vs[i], vs[i + 1]]) for i in range(1, n - 1)]

        bottom = cap(list(reversed(verts_b)))
        top = cap(verts_t)
        for i in range(n):
            self.bm.faces.new([verts_b[i], verts_b[(i + 1) % n], verts_t[(i + 1) % n], verts_t[i]])
        faces = self._new_faces(before)
        self._paint(faces, color)
        self._paint(top, color_top or color)
        self._paint(bottom, color_bottom or color)
        return faces

    def wedge(self, size, at=(0, 0, 0), rot=(0, 0, 0), color="roof_tile"):
        """A triangular prism: a box whose top edge is collapsed along +Y.
        Used for roof slopes and ridge caps. Footprint x by y, rises to z."""
        sx, sy, sz = size
        pts = [(-sy / 2, 0), (sy / 2, 0), (sy / 2, sz)]
        # Build in the YZ plane then extrude along X via prism on rotated axes.
        m = self._matrix(at, rot)
        before = set(self.bm.faces)
        vb = [self.bm.verts.new(m @ Vector((-sx / 2, y, z))) for y, z in pts]
        vt = [self.bm.verts.new(m @ Vector((sx / 2, y, z))) for y, z in pts]
        self.bm.faces.new(list(reversed(vb)))
        self.bm.faces.new(vt)
        for i in range(3):
            self.bm.faces.new([vb[i], vb[(i + 1) % 3], vt[(i + 1) % 3], vt[i]])
        return self._paint(self._new_faces(before), color)

    def paint(self, faces, color: str):
        """Recolour faces returned by a primitive, e.g. the top of a box."""
        return self._paint(faces, color)

    def faces_facing(self, faces, direction, min_dot=0.9):
        """Subset of `faces` whose normal points along `direction` (world axes)."""
        d = Vector(direction).normalized()
        self.bm.normal_update()
        return [f for f in faces if f.normal.dot(d) >= min_dot]

    def highest_faces(self, faces, n=1):
        """The n faces with the highest centroid; the top of a cylinder, say."""
        return sorted(faces, key=lambda f: -f.calc_center_median().z)[:n]

    def mirror_x(self, faces):
        """Duplicate `faces` mirrored across the YZ plane; returns the copies."""
        before = set(self.bm.faces)
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + list(faces)
        res = bmesh.ops.duplicate(self.bm, geom=geom)
        new_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.scale(self.bm, vec=(-1, 1, 1), verts=new_verts)
        new_faces = self._new_faces(before)
        bmesh.ops.reverse_faces(self.bm, faces=new_faces)
        return new_faces

    # -- finishing ----------------------------------------------------------
    def finish(self, collection: bpy.types.Collection | None = None, palette_path: str | None = None) -> bpy.types.Object:
        """Bake the bmesh into a mesh object: UVs from the palette layer, one
        material, normals recalculated, transforms identity. Validation of
        origin and size is the validator's job, not this function's."""
        bm = self.bm
        # No remove_doubles here: primitives are separate closed shells, and
        # merging coincident corners across shells fuses them and flips normals.
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uv_layer = bm.loops.layers.uv.new("UVMap")
        names = list(PALETTE)
        for f in bm.faces:
            u, v = palette_uv(names[f[self.color_layer]])
            for loop in f.loops:
                loop[uv_layer].uv = (u, v)
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        obj["sakura_category"] = self.category
        obj["sakura_contract_version"] = CONTRACT_VERSION
        if self.footprint:
            obj["sakura_footprint"] = list(self.footprint)
        if self.category == "floor":
            obj["sakura_walkable"] = self.walkable
        sockets = self.sockets or SOCKET_DEFAULTS.get(self.category)
        if sockets:
            for side, kind in sockets.items():
                obj[f"sakura_socket_{side}"] = kind
        if palette_path is None:
            palette_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", PALETTE_FILENAME)
            os.makedirs(os.path.dirname(palette_path), exist_ok=True)
        mesh.materials.append(get_material(palette_path))
        (collection or bpy.context.scene.collection).objects.link(obj)
        for poly in mesh.polygons:
            poly.use_smooth = False
        return obj


def tri_count(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
