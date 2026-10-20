"""Previews: one three-quarter render per piece on a neutral ground, and a
contact sheet that puts the whole kit on one page so style drift is visible
at a glance. Cycles on CPU, few samples: these are low-poly flat-shaded
pieces, so 24 samples is plenty."""
from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector

from . import contract as C


def _setup_render(samples, size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = False
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.get("preview_world") or bpy.data.worlds.new("preview_world")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*C.AMBIENT, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world

    if "preview_sun" not in bpy.data.objects:
        sun_data = bpy.data.lights.new("preview_sun", "SUN")
        sun_data.energy = C.SUN_ENERGY
        sun_data.angle = math.radians(8)
        sun = bpy.data.objects.new("preview_sun", sun_data)
        scene.collection.objects.link(sun)
        # The one sun of the contract: elevation and azimuth as Blender euler angles.
        sun.rotation_euler = (math.radians(90 - C.SUN_ELEVATION), 0, math.radians(C.SUN_AZIMUTH))
    if "preview_cam" not in bpy.data.objects:
        cam_data = bpy.data.cameras.new("preview_cam")
        cam_data.type = "ORTHO"
        cam = bpy.data.objects.new("preview_cam", cam_data)
        scene.collection.objects.link(cam)
    scene.camera = bpy.data.objects["preview_cam"]
    if "preview_ground" not in bpy.data.objects:
        mesh = bpy.data.meshes.new("preview_ground")
        mesh.from_pydata([(-20, -20, 0), (20, -20, 0), (20, 20, 0), (-20, 20, 0)], [], [(0, 1, 2, 3)])
        ground = bpy.data.objects.new("preview_ground", mesh)
        mat = bpy.data.materials.new("preview_ground_mat")
        mat.diffuse_color = (0.86, 0.85, 0.82, 1)
        mesh.materials.append(mat)
        scene.collection.objects.link(ground)
        ground.location.z = -0.001


def _frame(obj):
    """Orthographic three-quarter view framed on the object's bounds."""
    cam = bpy.data.objects["preview_cam"]
    pts = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    extent = max(hi - lo) * 1.35 + 0.25
    cam.data.ortho_scale = extent
    direction = Vector((1, -1, 0.9)).normalized()
    cam.location = centre + direction * 20
    cam.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()


def render_previews(objects, out_dir, samples=24, size=384):
    _setup_render(samples, size)
    scene = bpy.context.scene
    for o in objects:
        o.hide_render = True
    ground = bpy.data.objects["preview_ground"]
    for obj in objects:
        obj.hide_render = False
        obj.location = (0, 0, 0)
        _frame(obj)
        # Ground just under the piece's lowest point, so a sunken floor (the
        # pond tile) or a slab below z = 0 is not swallowed by the ground plane.
        ground.location.z = min(v[2] for v in obj.bound_box) - 0.001
        scene.render.filepath = os.path.join(out_dir, f"{obj.name}.png")
        bpy.ops.render.render(write_still=True)
        obj.hide_render = True
    for o in objects:
        o.hide_render = False


def contact_sheet(objects, previews_dir, out_path, cols=6, cell=384):
    """Grid of previews with the piece name and tri count under each."""
    from PIL import Image, ImageDraw
    from . import contract as C

    objs = sorted(objects, key=lambda o: o.name)
    rows = math.ceil(len(objs) / cols)
    label_h = 36
    sheet = Image.new("RGB", (cols * cell, rows * (cell + label_h)), (237, 234, 229))
    draw = ImageDraw.Draw(sheet)
    for i, obj in enumerate(objs):
        x, y = (i % cols) * cell, (i // cols) * (cell + label_h)
        p = os.path.join(previews_dir, f"{obj.name}.png")
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((cell, cell)), (x, y))
        draw.text((x + 10, y + cell + 8), f"{obj.name.removeprefix('sakura_')}   {C.tri_count(obj)} tris", fill=(40, 38, 36))
    sheet.save(out_path)
    return out_path
