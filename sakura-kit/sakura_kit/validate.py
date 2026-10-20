"""Validator: the contract's teeth. Every check is mechanical and reads only
the mesh, so a piece either passes or the report says exactly why not.

    from sakura_kit.validate import validate
    report = validate(obj)          # {"name", "ok", "tris", "checks": [...]}
"""
from __future__ import annotations

from mathutils import Vector

from . import contract as C


def _bbox(obj):
    # matrix_basis reflects location/rotation/scale as set right now;
    # matrix_world lags until the depsgraph evaluates.
    pts = [obj.matrix_basis @ Vector(v) for v in obj.bound_box]
    xs, ys, zs = (sorted(p[i] for p in pts) for i in range(3))
    return (xs[0], ys[0], zs[0]), (xs[-1], ys[-1], zs[-1])


def _islands(mesh):
    """Connected components of the mesh as lists of vertex indices (union-find over edges)."""
    parent = list(range(len(mesh.vertices)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in mesh.edges:
        a, b = (find(v) for v in e.vertices)
        if a != b:
            parent[a] = b
    groups: dict[int, list[int]] = {}
    for i in range(len(mesh.vertices)):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


def _aabb_touch(a, b, pad):
    return all(a[0][i] - pad <= b[1][i] and b[0][i] - pad <= a[1][i] for i in range(3))


def validate(obj, strict_tris: bool = True) -> dict:
    checks: list[dict] = []

    def check(name, ok, detail="", level="error"):
        # level "warn" is reported but never fails a piece; a check is
        # introduced as a warning and promoted once every piece passes it.
        checks.append({"check": name, "ok": bool(ok), "detail": detail, "level": level})

    name = obj.name
    check("name_matches_rule", C.NAME_RE.match(name), f"{name!r} must be sakura_<category>_<name>[_<variant>]")
    category = name.split("_")[1] if "_" in name else ""
    rules = C.CATEGORY_RULES.get(category)
    check("category_known", rules is not None, f"category {category!r}")
    if rules is None or obj.type != "MESH":
        check("is_mesh", obj.type == "MESH")
        return {"name": name, "ok": False, "tris": 0, "checks": checks}

    mesh = obj.data
    # Transforms must be identity: pieces are placed by the engine, not by Blender.
    loc, rot, sca = obj.matrix_basis.decompose()
    check("transforms_applied",
          obj.parent is None and loc.length < C.TOL and abs(rot.angle) < 1e-4 and all(abs(s - 1) < 1e-4 for s in sca),
          f"loc={tuple(round(v, 3) for v in loc)} rot={round(rot.angle, 4)} scale={tuple(round(v, 3) for v in sca)} parent={obj.parent}")

    tris = C.tri_count(obj)
    budget = obj.get("sakura_tris_max", rules["tris"])
    check("tri_budget", tris <= budget if strict_tris else True, f"{tris} tris, budget {budget}")
    check("has_geometry", len(mesh.polygons) > 0, f"{len(mesh.polygons)} faces")
    ngons = sum(1 for p in mesh.polygons if len(p.vertices) > 4)
    check("no_ngons", ngons == 0, f"{ngons} faces with more than 4 verts")
    used = {i for p in mesh.polygons for i in p.vertices}
    loose = len(mesh.vertices) - len(used)
    check("no_loose_verts", loose == 0, f"{loose} loose vertices")

    # Single kit material, nothing else.
    mats = [m.name for m in mesh.materials if m]
    check("single_palette_material", mats == [C.MATERIAL_NAME], f"materials: {mats}")
    check("no_modifiers", len(obj.modifiers) == 0, f"{len(obj.modifiers)} modifiers")

    # Every face's UVs sit inside one palette cell, all loops of the face in the same cell.
    uv = mesh.uv_layers.active
    bad_uv = 0
    if uv is None:
        check("uv_on_palette", False, "no UV map")
    else:
        for p in mesh.polygons:
            cells = set()
            for li in p.loop_indices:
                u, v = uv.data[li].uv
                if not (0 <= u <= 1 and 0 <= v <= 1):
                    cells.add(None)
                else:
                    cells.add((int(u * C.PALETTE_COLS), int(v * C.PALETTE_ROWS)))
            if len(cells) != 1 or None in cells:
                bad_uv += 1
        check("uv_on_palette", bad_uv == 0, f"{bad_uv} faces with UVs off a single palette cell")

    # Origin and envelope.
    (x0, y0, z0), (x1, y1, z1) = _bbox(obj)
    w, d, h = x1 - x0, y1 - y0, z1 - z0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    fp = obj.get("sakura_footprint", None)
    size_x, size_y = (fp[0], fp[1]) if fp else rules["size"]
    zmin, zmax = rules["z"]
    tol = C.TOL

    if category == "roof":
        # The one pivot exception: a roof's origin is on its ridge edge, so the
        # mesh runs from y = 0 (ridge) to y = depth (eave) and two eaves placed on
        # the same ridge line at rot 0 and rot 2 form a gable instead of crossing.
        check("roof_origin_on_ridge", abs(cx) < tol and abs(y0) < tol, f"bbox centre x={cx:.4f}, ridge edge y={y0:.4f} (must be 0)")
    else:
        check("origin_centred_xy", abs(cx) < tol and abs(cy) < tol, f"bbox centre x={cx:.4f} y={cy:.4f}")
    if category == "floor":
        check("floor_top_at_zero", -tol <= z1 <= zmax + tol, f"top z={z1:.4f} (walking surface at 0, detail may rise to {zmax})")
        check("floor_thickness", z0 >= zmin - tol, f"bottom z={z0:.4f} (min {zmin})")
        check("footprint_exact", abs(w - size_x) < tol and abs(d - size_y) < tol, f"{w:.3f} x {d:.3f}, must be {size_x} x {size_y}")
    else:
        check("origin_at_base", abs(z0) < tol, f"bottom z={z0:.4f} (must be 0)")
        check("height_within", z1 <= zmax + tol, f"height {h:.3f}, max {zmax}")
        if rules["footprint"] == "wall":
            check("wall_width_exact", abs(w - size_x) < tol, f"width {w:.3f}, must be {size_x}")
            check("wall_height_exact", abs(h - C.WALL_H) < tol, f"height {h:.3f}, must be {C.WALL_H}")
            check("wall_thickness_max", d <= size_y + tol, f"thickness {d:.3f}, max {size_y}")
        elif rules["footprint"] == "roof":
            check("roof_width_exact", abs(w - size_x) < tol, f"width {w:.3f}, must be {size_x}")
            check("roof_depth_max", d <= size_y + tol, f"depth {d:.3f}, max {size_y}")
        else:
            check("footprint_max", w <= size_x + tol and d <= size_y + tol, f"{w:.3f} x {d:.3f}, max {size_x} x {size_y}")
    if category == "pillar":
        check("pillar_height_exact", abs(h - C.WALL_H) < tol, f"height {h:.3f}, must be {C.WALL_H}")

    # Scale sanity: nothing microscopic, nothing giant.
    check("not_degenerate", max(w, d, h) > 0.02, f"largest dimension {max(w, d, h):.3f}")

    # ---- warnings: reported, not yet enforced -------------------------------
    verts = [v.co for v in mesh.vertices]
    if category in ("floor", "wall", "door"):
        on = lambda axis, val: any(abs(v[axis] - val) < tol for v in verts)  # noqa: E731
        edges_ok = on(0, -size_x / 2) and on(0, size_x / 2)
        if category == "floor":
            edges_ok = edges_ok and on(1, -size_y / 2) and on(1, size_y / 2)
        check("flush_edges", edges_ok, "a face stops short of the footprint edge: it will leak at the join", level="warn")
    if category != "floor":
        islands = _islands(mesh)
        boxes = []
        for isl in islands:
            pts = [verts[i] for i in isl]
            boxes.append(((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)),
                          (max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))
        floating = 0
        for i, bb in enumerate(boxes):
            if bb[0][2] <= tol:
                continue
            if not any(_aabb_touch(bb, other, tol) for j, other in enumerate(boxes) if j != i):
                floating += 1
        check("nothing_floats", floating == 0, f"{floating} of {len(islands)} shells touch neither the ground nor another shell", level="warn")
    check("flat_shading", all(not p.use_smooth for p in mesh.polygons), "smooth-shaded faces", level="warn")
    # Normals: recalculate on a scratch copy and count faces that flipped. Lone
    # faces are left as wound by recalc, so this only catches closed shells
    # that were built inside out, which is exactly the case that renders dark.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    before_n = [f.normal.copy() for f in bm.faces]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    flipped = sum(1 for f, n0 in zip(bm.faces, before_n) if f.normal.dot(n0) < 0)
    bm.free()
    check("normals_outward", flipped == 0, f"{flipped} faces point into their shell", level="warn")
    need = ["sakura_category", "sakura_contract_version"] + (["sakura_walkable"] if category == "floor" else [])
    missing = [k for k in need if k not in obj]
    check("extras_present", not missing, f"missing custom properties: {missing}", level="warn")

    ok = all(c["ok"] for c in checks if c.get("level", "error") == "error")
    return {"name": name, "category": category, "ok": ok, "tris": tris, "budget": budget,
            "size": [round(w, 3), round(d, 3), round(h, 3)], "checks": checks}


def format_report(report: dict) -> str:
    head = f"{'PASS' if report['ok'] else 'FAIL'} {report['name']}  {report.get('tris', '?')} tris  size {report.get('size')}"
    lines = [head]
    for c in report["checks"]:
        if not c["ok"]:
            mark = "!" if c.get("level") == "warn" else "x"
            lines.append(f"   {mark} {c['check']}: {c['detail']}")
    return "\n".join(lines)
