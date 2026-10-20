"""Check ONE piece in isolation: build it in a fresh scene, validate, export
its own .glb and render its own preview. Writes nothing shared, so several
checks can run at once.

    python -m sakura_kit.check prop_table_low            # validate + export + preview
    python -m sakura_kit.check prop_table_low --no-render

Prints the validation report and exits 1 on failure.
"""
from __future__ import annotations

import importlib
import os
import sys
import traceback

import bpy

from . import contract as C
from .validate import format_report, validate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")


def check(name: str, render: bool = True) -> dict:
    name = name.removesuffix(".py").replace("/", ".").removeprefix("pieces.").removeprefix("sakura_")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(os.path.join(BUILD, "glb"), exist_ok=True)
    os.makedirs(os.path.join(BUILD, "previews"), exist_ok=True)
    palette_path = os.path.join(BUILD, C.PALETTE_FILENAME)
    C.write_palette_image(palette_path)   # always: the palette is derived from the contract, never stale
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    try:
        # A dotted name is a module path (tests.broken.wall_short); a bare one is a piece.
        mod = importlib.import_module(name if "." in name else f"pieces.{name}")
        importlib.reload(mod)
        obj = mod.build()
        rep = validate(obj)
    except Exception:
        rep = {"name": f"sakura_{name}", "ok": False, "tris": 0, "size": None,
               "checks": [{"check": "build_raises", "ok": False, "detail": traceback.format_exc()[-1200:]}]}
        obj = None
    print(format_report(rep))
    if obj is None:
        return rep
    glb = os.path.join(BUILD, "glb", f"{obj.name}.glb")
    if rep["ok"]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_extras=True)
    elif os.path.exists(glb):
        os.remove(glb)   # a failing piece leaves no GLB behind: the build is the gate
    if render:
        from .render import render_previews
        render_previews([obj], os.path.join(BUILD, "previews"), samples=24, size=384)
        print(f"preview: build/previews/{obj.name}.png")
    return rep


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(2)
    rep = check(args[0], render="--no-render" not in sys.argv)
    sys.exit(0 if rep["ok"] else 1)
