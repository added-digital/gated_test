"""Assemble a test scene from the kit — the proof that pieces snap.

    python assemble.py            # builds all pieces, lays out the scene, renders build/scene_teahouse.png
    python assemble.py --no-render

The scene is a 5 x 4 m tea room with an engawa, opening onto a raked-gravel
garden with a pond, a 3 m bridge, a stone lantern, bamboo and two cherry trees.
Every object is a linked duplicate of a kit piece placed on the 1 m grid at a
90-degree rotation. If a piece is missing (not built yet) it is skipped and
listed, so the scene can be assembled while the kit is still growing.

The layout numbers are the scale pass's (breaks.md 2026-10-21, from the first
human walk): the room 5 x 4 tiles with the table at its centre and 0.8 m clear
all round, the open shoji bay in the middle of the south wall at x 2.5, two
rows of five eaves on the ridge line y = 2.0, the bridge spanning the whole
3-cell pond with a bare gravel cell at each end. The walk test's straight line
x = 2.5 (path, engawa, bay, tatami) stays clear of every prop.
"""
from __future__ import annotations

import importlib
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
from sakura_kit import contract as C  # noqa: E402

BUILD = os.path.join(ROOT, "build")
PY_PIECES = os.path.join(ROOT, "pieces")

# The tea room: tiles x 0..ROOM_W, y 0..ROOM_D; the ridge runs along y = RIDGE_Y.
ROOM_W, ROOM_D = 5, 4
RIDGE_Y = ROOM_D / 2                 # 2.0: each 2.2 m eave reaches 0.2 m past its wall
BAY_X = ROOM_W // 2 + 0.5            # 2.5: the open shoji bay, the walk line into the room
# The garden: tiles x GARDEN_X0..GARDEN_X1, y GARDEN_Y0..GARDEN_Y1 (south of the engawa).
GARDEN_X0, GARDEN_X1 = -3, 6
GARDEN_Y0, GARDEN_Y1 = -7, -1
POND_I, POND_J = range(-2, 1), range(-5, -2)   # pond cells x -2..1, rows y -5..-2 (centres -4.5, -3.5, -2.5)
PATH_I = 2                           # the stone path column, x 2..3, from the fence to the engawa
BRIDGE_AT = (-0.5, -4.5)             # the 3 m bridge, centred on the pond's south row; ends at x -2 and x 1
TABLE_H = 0.33                       # prop_table_low's real-size height; built at TABLE_H * PROP_SCALE

library: dict[str, bpy.types.Object] = {}
missing: set[str] = set()
placements: list[dict] = []       # every place() call, for scenes/<name>.json
scene_coll: bpy.types.Collection


def load_library():
    lib = bpy.data.collections.new("sakura_library")
    bpy.context.scene.collection.children.link(lib)
    for f in sorted(os.listdir(PY_PIECES)):
        if not f.endswith(".py") or f.startswith("_"):
            continue
        name = f[:-3]
        try:
            mod = importlib.import_module(f"pieces.{name}")
            obj = mod.build()
            for coll in obj.users_collection:
                coll.objects.unlink(obj)
            lib.objects.link(obj)
            obj.hide_render = True
            obj.hide_viewport = True
            library[name] = obj
        except Exception as e:  # a half-written piece must not sink the scene
            print(f"skip {name}: {e!r}")
    bpy.context.view_layer.layer_collection.children["sakura_library"].exclude = True


def place(name: str, x: float, y: float, z: float = 0.0, rot: int = 0):
    """Linked duplicate of a piece at a grid point; rot in 90-degree steps."""
    entry = {"piece": f"sakura_{name}", "x": x, "y": y, "z": z, "rot": rot % 4, "category": name.split("_")[0]}
    src = library.get(name)
    if src is not None and "sakura_walkable" in src:
        entry["walkable"] = bool(src["sakura_walkable"])
    if src is not None and "sakura_footprint" in src:
        # [w, d] in metres along x and y at rot 0 (the piece's declared sakura_footprint).
        # A bridge's footprint tells mapcheck and the engine which pond cells it
        # decks over: no blocker there (breaks.md 2026-10-21).
        entry["footprint"] = [float(v) for v in src["sakura_footprint"]]
    placements.append(entry)
    if src is None:
        missing.add(name)
        return None
    inst = src.copy()
    inst.data = src.data
    inst.location = (x, y, z)
    inst.rotation_euler = (0, 0, math.radians(90 * rot))
    inst.hide_render = False
    inst.hide_viewport = False
    scene_coll.objects.link(inst)
    return inst


def layout():
    # --- tea room: tatami 5 x 4, origin of the room at (0, 0), x to the east, y to the north
    for i in range(ROOM_W):
        for j in range(ROOM_D):
            place("floor_tatami", i + 0.5, j + 0.5, 0, rot=(i + j) % 2)
    # engawa veranda along the south edge, as wide as the room
    for i in range(ROOM_W):
        place("floor_wood", i + 0.5, -0.5)
    # walls: south onto the engawa is shoji with the middle bay slid open (the way in
    # from the garden); north, west and east are plain, no other door.
    for i in range(ROOM_W):
        place("door_shoji_1m_open" if i + 0.5 == BAY_X else "door_shoji_1m", i + 0.5, 0.0, rot=0)
        place("wall_plain_1m", i + 0.5, ROOM_D, rot=0)
    for j in range(ROOM_D):
        place("wall_plain_1m", 0.0, j + 0.5, rot=1)
        place("wall_plain_1m", ROOM_W, j + 0.5, rot=1)
    for (x, y) in [(0, 0), (ROOM_W, 0), (0, ROOM_D), (ROOM_W, ROOM_D)]:
        place("pillar_post", x, y)
    # roof: two rows of eaves on the ridge line, one sloping north and one south; each
    # 2.2 m eave runs from the ridge at y = 2.0 to 0.2 m past its wall.
    for i in range(ROOM_W):
        place("roof_eave_1m", i + 0.5, RIDGE_Y, C.WALL_H, rot=0)   # slopes toward +Y (north)
        place("roof_eave_1m", i + 0.5, RIDGE_Y, C.WALL_H, rot=2)   # slopes toward -Y (south, over the bay)
    # inside: the table at the room's centre (1.6 m to the south wall, 2.1 m to the sides:
    # 0.8 m clear all round). The walk line x = 2.5 from the bay to the tatami at
    # (2.5, 1.0) stays bare: no south cushion; the four sit west, east and two north.
    place("prop_table_low", BAY_X, RIDGE_Y)
    # The tea set stands on the table top: the chabudai is 0.33 m at real size and
    # props build at PROP_SCALE (breaks.md 2026-10-21), so the top is at 0.396.
    place("prop_tea_set", BAY_X, RIDGE_Y, round(TABLE_H * C.PROP_SCALE, 3))
    for (x, y, r) in [(1.5, 2.0, 1), (3.5, 2.0, 3), (1.9, 2.9, 2), (3.1, 2.9, 2)]:
        place("prop_cushion", x, y, 0, r)
    place("prop_ikebana", 0.35, 3.65)          # north-west corner
    place("prop_lantern_paper", 4.65, 3.65)    # north-east corner

    # --- garden: 9 x 6 m south of the house, y from -1 down to -7, x from -3 to 6
    # (one gravel column west of the pond, so the bridge lands on gravel at both ends)
    for i in range(GARDEN_X0, GARDEN_X1):
        for j in range(GARDEN_Y0, GARDEN_Y1):
            x, y = i + 0.5, j + 0.5
            if i in POND_I and j in POND_J:
                place("floor_water", x, y)           # pond 3 x 3
            elif i == PATH_I:
                place("floor_stone_path", x, y, rot=(j % 2))   # the path, garden edge to engawa
            elif (i == 1 and j in (-3, -2)) or (i == 3 and j == -2):
                place("floor_moss", x, y)
            else:
                place("floor_gravel_raked", x, y, rot=(0 if j > -5 else 1))
    # The bridge spans the whole pond east-west on its south row (cells x -2..1, y -5..-4);
    # its approach cells (-2.5, -4.5) and (1.5, -4.5) are bare gravel: the walk test
    # crosses from one to the other.
    place("garden_bridge_3m", *BRIDGE_AT)
    place("garden_water_basin", 3.5, -1.5)
    place("garden_lantern_stone", 1.5, -5.5)    # by the bridge's east foot (was (1.5, -4.5), now the approach cell)
    place("garden_rock_a", 4.5, -4.5)
    place("garden_rock_b", 4.5, -3.5)
    place("garden_rock_b", 0.5, -6.5, rot=2)
    for i in range(GARDEN_X0, GARDEN_X1):
        place("garden_bamboo_fence_1m", i + 0.5, GARDEN_Y0)
    place("garden_bamboo_cluster", -1.5, -1.5)
    place("garden_bamboo_cluster", 5.5, -6.5, rot=1)
    place("tree_sakura_a", 4.5, -6.0)
    place("tree_sakura_b", -1.5, -6.5)
    place("garden_petals", 4.5, -5.0)
    place("garden_petals", 3.5, -6.0, rot=1)
    place("garden_petals", -1.5, -5.6, rot=2)


def render(path: str):
    from sakura_kit.render import _setup_render
    _setup_render(samples=48, size=1024)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 1280, 900
    cam = bpy.data.objects["preview_cam"]
    cam.data.type = "PERSP"
    cam.data.lens = 35
    # From the south-east, high enough to see the roof pairs on the ridge, the open
    # bay in the south wall, and the bridge across the pond with gravel at both ends.
    target = Vector((1.5, -1.5, 0.6))
    cam.location = Vector((12.0, -14.0, 9.5))
    cam.rotation_euler = (cam.location - target).to_track_quat("Z", "Y").to_euler()
    # The sun is the contract's; _setup_render already set it. Only the camera is ours.
    # The ground plane sits under the deepest floor slab (the pond, FLOOR_T_MAX) so
    # sunken surfaces show.
    bpy.data.objects["preview_ground"].location.z = -C.FLOOR_T_MAX - 0.02
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    global scene_coll
    bpy.ops.wm.read_factory_settings(use_empty=True)
    C.write_palette_image(os.path.join(BUILD, C.PALETTE_FILENAME))
    scene_coll = bpy.data.collections.new("teahouse_scene")
    bpy.context.scene.collection.children.link(scene_coll)
    load_library()
    layout()
    print(f"placed {len(scene_coll.objects)} objects from {len(library)} pieces; missing: {sorted(missing) or 'none'}")
    # The placement list is the scene's source of truth for engines and mapcheck:
    # Blender z-up metres, rot in 90-degree steps about Z. Godot: (x, z, -y).
    import json
    os.makedirs(os.path.join(ROOT, "scenes"), exist_ok=True)
    with open(os.path.join(ROOT, "scenes", "teahouse.json"), "w") as f:
        json.dump({"contract_version": C.CONTRACT_VERSION, "units": "metres, z up", "grid": C.GRID,
                   "placements": placements}, f, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BUILD, "scene_teahouse.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for o in scene_coll.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(BUILD, "scene_teahouse.glb"), export_format="GLB",
                              use_selection=True, export_apply=False, export_yup=True, export_extras=True)
    if "--no-render" not in sys.argv:
        render(os.path.join(BUILD, "scene_teahouse.png"))


if __name__ == "__main__":
    main()
