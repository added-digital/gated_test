"""Assemble a test scene from the kit — the proof that pieces snap.

    python assemble.py            # builds all pieces, lays out the scene, renders build/scene_teahouse.png
    python assemble.py --no-render

The scene is a 3 x 2 m tea room with an engawa, opening onto a raked-gravel
garden with a pond, a bridge, a stone lantern, bamboo and two cherry trees.
Every object is a linked duplicate of a kit piece placed on the 1 m grid at a
90-degree rotation. If a piece is missing (not built yet) it is skipped and
listed, so the scene can be assembled while the kit is still growing.
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
    # --- tea room: tatami 3 x 2, origin of the room at (0, 0), x to the east, y to the north
    for i in range(3):
        for j in range(2):
            place("floor_tatami", i + 0.5, j + 0.5, 0, rot=(i + j) % 2)
    # engawa veranda along the south edge
    for i in range(3):
        place("floor_wood", i + 0.5, -0.5)
    # walls: north (plain), west (plain), east (plain + shoji), south (shoji x3 facing the garden)
    for i in range(3):
        place("wall_plain_1m", i + 0.5, 2.0, rot=0)
        # South wall onto the engawa: the middle bay is slid open, the way in from the garden.
        place("door_shoji_1m_open" if i == 1 else "door_shoji_1m", i + 0.5, 0.0, rot=0)
    for j in range(2):
        place("wall_plain_1m", 0.0, j + 0.5, rot=1)
    place("wall_plain_1m", 3.0, 1.5, rot=1)
    place("door_shoji_1m", 3.0, 0.5, rot=1)
    for (x, y) in [(0, 0), (3, 0), (0, 2), (3, 2)]:
        place("pillar_post", x, y)
    # roof: two slopes meeting over the middle of the room, overhanging the engawa
    for i in range(-1, 4):
        place("roof_eave_1m", i + 0.5, 1.0, C.WALL_H, rot=0)   # slopes toward +Y (north)
        place("roof_eave_1m", i + 0.5, 1.0, C.WALL_H, rot=2)   # slopes toward -Y (south, over the engawa)
    # inside
    place("prop_table_low", 1.5, 1.0)
    place("prop_tea_set", 1.5, 1.0, 0.33)
    for (x, y, r) in [(1.5, 0.35, 0), (1.5, 1.65, 2), (0.7, 1.0, 1), (2.3, 1.0, 3)]:
        place("prop_cushion", x, y, 0, r)
    place("prop_ikebana", 0.35, 1.7)
    place("prop_lantern_paper", 2.7, 1.7)

    # --- garden: 8 x 6 m south of the house, y from -1 down to -7, x from -2 to 6
    for i in range(-2, 6):
        for j in range(-7, -1):
            x, y = i + 0.5, j + 0.5
            if -2 <= i <= 0 and -5 <= j <= -3:
                place("floor_water", x, y)           # pond 3 x 3
            elif i == 2:
                place("floor_stone_path", x, y, rot=(j % 2))   # the path, garden edge to engawa
            elif (i == 1 and j in (-3, -2)) or (i == 3 and j == -2):
                place("floor_moss", x, y)
            else:
                place("floor_gravel_raked", x, y, rot=(0 if j > -5 else 1))
    place("garden_bridge_2m", -1.0, -4.5)            # spans the pond east-west
    place("garden_water_basin", 3.5, -1.5)
    place("garden_lantern_stone", 1.5, -4.5)
    place("garden_rock_a", 4.5, -4.5)
    place("garden_rock_b", 4.5, -3.5)
    place("garden_rock_b", 0.5, -6.5, rot=2)
    for i in range(-2, 6):
        place("garden_bamboo_fence_1m", i + 0.5, -7.0)
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
    target = Vector((2.0, -3.0, 0.4))
    cam.location = Vector((12.5, -15.0, 9.5))
    cam.rotation_euler = (cam.location - target).to_track_quat("Z", "Y").to_euler()
    # The sun is the contract's; _setup_render already set it. Only the camera is ours.
    # The ground plane sits under the floor slabs so sunken surfaces (the pond) show.
    bpy.data.objects["preview_ground"].location.z = -C.FLOOR_T - 0.02
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
