"""Build, validate, export and render the kit.

    python -m sakura_kit.build                 # everything in pieces/
    python -m sakura_kit.build floor_tatami    # one piece (module name without 'sakura_')
    python -m sakura_kit.build --no-render     # skip the previews

Each pieces/<name>.py exposes `build() -> bpy.types.Object` (built through
contract.Piece). Outputs go to build/:
    build/glb/<name>.glb        one file per piece, Y-up, palette embedded
    build/sakura_kit.glb        the whole kit in one file (for engine import as a library)
    build/sakura_kit.blend      the Blender source
    build/previews/<name>.png   one render per piece
    build/contact_sheet.png     all previews on one page
    build/report.json           validation report
"""
from __future__ import annotations

import importlib
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Vector

from . import contract as C
from .validate import format_report, validate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIECES_DIR = os.path.join(ROOT, "pieces")
BUILD = os.path.join(ROOT, "build")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def load_piece_modules(only: list[str] | None):
    if PIECES_DIR not in sys.path:
        sys.path.insert(0, ROOT)
    names = sorted(f[:-3] for f in os.listdir(PIECES_DIR) if f.endswith(".py") and not f.startswith("_"))
    if only:
        wanted = {o.removesuffix(".py").removeprefix("pieces/").removeprefix("sakura_") for o in only}
        names = [n for n in names if n in wanted]
    mods = []
    for n in names:
        mod = importlib.import_module(f"pieces.{n}")
        importlib.reload(mod)
        mods.append((n, mod))
    return mods


def build_all(only=None, render=True, samples=24, size=384):
    reset_scene()
    os.makedirs(os.path.join(BUILD, "glb"), exist_ok=True)
    os.makedirs(os.path.join(BUILD, "previews"), exist_ok=True)
    palette_path = os.path.join(BUILD, C.PALETTE_FILENAME)
    C.write_palette_image(palette_path)
    kit = bpy.data.collections.new("sakura_kit")
    bpy.context.scene.collection.children.link(kit)

    results, objects = [], []
    for n, mod in load_piece_modules(only):
        try:
            obj = mod.build()
            if obj.name not in kit.objects:
                for coll in obj.users_collection:
                    coll.objects.unlink(obj)
                kit.objects.link(obj)
            rep = validate(obj)
        except Exception:
            rep = {"name": f"sakura_{n}", "ok": False, "tris": 0, "checks": [{"check": "build_raises", "ok": False, "detail": traceback.format_exc()[-600:]}]}
            obj = None
        results.append(rep)
        print(format_report(rep))
        if obj is not None and rep["ok"]:
            objects.append(obj)      # only passing pieces are exported and rendered
        elif obj is not None:
            bpy.data.objects.remove(obj)

    # Lay pieces out on a line so the .blend is readable; export each at the origin.
    for i, obj in enumerate(objects):
        obj.location = (i * 3.0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BUILD, "sakura_kit.blend"))

    for obj in objects:
        obj.location = (0, 0, 0)
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=os.path.join(BUILD, "glb", f"{obj.name}.glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True, export_extras=True)
    if objects:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(BUILD, "sakura_kit.glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True, export_extras=True)

    with open(os.path.join(BUILD, "report.json"), "w") as f:
        json.dump(results, f, indent=1)

    if render and objects:
        from .render import render_previews, contact_sheet
        render_previews(objects, os.path.join(BUILD, "previews"), samples=samples, size=size)
        contact_sheet(objects, os.path.join(BUILD, "previews"), os.path.join(BUILD, "contact_sheet.png"))

    n_ok = sum(1 for r in results if r["ok"])
    print(f"\n{n_ok}/{len(results)} pieces pass. Report: build/report.json")
    return results


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build_all(only=args or None, render="--no-render" not in sys.argv)
