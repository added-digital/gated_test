extends Node3D
## Headless check of the project phase: teahouse.tscn builds every placement
## from the JSON, every non-fx placement has a StaticBody3D, the pond floors
## carry their blockers except under the bridge's footprint, the rotation
## sign matches Blender, the palette is nearest + no mipmaps, and main.tscn's
## sun points where the contract says. Prints PASS/FAIL per check and quits
## with 0 only if all pass. The counts come from the JSON itself (141
## placements after the scale pass, kit breaks.md 2026-10-21).

const TEAHOUSE := preload("res://scenes/teahouse.tscn")
const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var teahouse := TEAHOUSE.instantiate()
	add_child(teahouse)
	var build_ms := Time.get_ticks_msec() - t0
	await get_tree().process_frame

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(teahouse.scene_json))
	var placements: Array = data["placements"]
	var expect_bodies := 0
	var expect_blockers := 0
	var expect_water := 0
	var expect_convex := 0
	var decked: Array[Vector2] = []   # water cells under the bridge: no blocker there
	for p in placements:
		if p["category"] != "fx":
			expect_bodies += 1
		if p["category"] in ["prop", "tree"]:
			expect_convex += 1
		if p["category"] == "floor" and p.get("walkable", true) == false:
			expect_water += 1
			if teahouse.under_bridge(p["x"], p["y"]):
				decked.append(Vector2(p["x"], p["y"]))
			else:
				expect_blockers += 1
	var expect_trimesh := expect_bodies - expect_convex

	print("teahouse built in %d ms; JSON placements=%d, loader placed=%d, skipped=%s" % [build_ms, placements.size(), teahouse.placed, teahouse.skipped])
	check(placements.size() == 141, "JSON has 141 placements (got %d)" % placements.size())
	check(teahouse.placed == 141 and teahouse.get_child_count() == 141, "141 pieces instanced as children (placed=%d, children=%d)" % [teahouse.placed, teahouse.get_child_count()])
	check(teahouse.skipped.is_empty(), "no placement skipped for a missing GLB")
	print("bridge footprints: %s; water cells=%d, decked by a bridge=%s" % [teahouse.bridges, expect_water, decked])
	check(teahouse.bridges.size() == 1 and decked.size() == 3, "one bridge decks 3 of the %d water cells (got %d bridge(s), %d decked)" % [expect_water, teahouse.bridges.size(), decked.size()])

	var meshes := teahouse.find_children("*", "MeshInstance3D", true, false)
	var bodies := teahouse.find_children("*", "StaticBody3D", true, false)
	var shapes := teahouse.find_children("*", "CollisionShape3D", true, false)
	var blockers := teahouse.find_children("Blocker", "CollisionShape3D", true, false)
	var trimesh := 0
	var convex := 0
	for s in shapes:
		if s.shape is ConcavePolygonShape3D:
			trimesh += 1
		elif s.shape is ConvexPolygonShape3D:
			convex += 1
	print("mesh instances=%d, static bodies=%d, collision shapes=%d (trimesh=%d, convex=%d, box blockers=%d)" % [meshes.size(), bodies.size(), shapes.size(), trimesh, convex, blockers.size()])
	check(bodies.size() == expect_bodies, "StaticBody3D count %d == non-fx placements %d" % [bodies.size(), expect_bodies])
	check(blockers.size() == expect_blockers, "pond blockers %d == walkable:false floors not under the bridge %d (%d water cells, 3 decked)" % [blockers.size(), expect_blockers, expect_water])
	check(convex == expect_convex and trimesh == expect_trimesh, "%d convex (prop+tree) and %d trimesh shapes (got %d, %d)" % [expect_convex, expect_trimesh, convex, trimesh])

	_check_rotation_sign(teahouse, placements)
	_check_palette(meshes[0])
	_check_sun()

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## Blender rot 1 is +90 deg about +Z (counter-clockwise seen from above). For a
## point in Godot coordinates that is (x, y, z) -> (z, y, -x). Apply that by
## hand to the rot 0 stone-path tile's vertices and compare with where the
## loader actually put the rot 1 tile's vertices.
func _check_rotation_sign(teahouse: Node3D, placements: Array) -> void:
	var tile0: Node3D = null
	var tile1: Node3D = null
	for i in placements.size():
		var p: Dictionary = placements[i]
		if p["piece"] == "sakura_floor_stone_path":
			if p["rot"] == 0 and tile0 == null:
				tile0 = teahouse.get_child(i)
			if p["rot"] == 1 and tile1 == null:
				tile1 = teahouse.get_child(i)
	var mesh0: MeshInstance3D = tile0.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh1: MeshInstance3D = tile1.find_children("*", "MeshInstance3D", true, false)[0]
	var verts: PackedVector3Array = mesh0.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var err_ccw := 0.0   # expected: Blender counter-clockwise
	var err_cw := 0.0    # the wrong sign, to show the check can tell them apart
	for v in verts:
		var actual: Vector3 = mesh1.global_transform * v
		err_ccw = maxf(err_ccw, actual.distance_to(tile1.global_position + Vector3(v.z, v.y, -v.x)))
		err_cw = maxf(err_cw, actual.distance_to(tile1.global_position + Vector3(-v.z, v.y, v.x)))
	print("stone path rot 0 at %s, rot 1 at %s: max vertex error vs counter-clockwise %.4f m, vs clockwise %.4f m" % [tile0.position, tile1.position, err_ccw, err_cw])
	check(err_ccw < 0.001 and err_cw > 0.1, "rotation_degrees.y = rot * 90 matches Blender's counter-clockwise rot")
	# Human-readable: which quadrants (Blender x, y) the stones occupy.
	print("  stone quadrants rot 0: %s   rot 1: %s   (Blender layout: rot 0 SW+NE, rot 1 SE+NW)" % [_stone_quadrants(mesh0, verts), _stone_quadrants(mesh1, verts)])
	# A roof eave is asymmetric: at rot 0 it extends toward Blender +Y (north, Godot -z);
	# at rot 1 it must extend toward Blender -X (west).
	var eave: Node3D = load("res://kit/glb/sakura_roof_eave_1m.glb").instantiate()
	eave.rotation_degrees.y = 90.0
	add_child(eave)
	var em: MeshInstance3D = eave.find_children("*", "MeshInstance3D", true, false)[0]
	var aabb := em.global_transform * em.mesh.get_aabb()
	print("  roof eave at rot 1 spans x [%.2f, %.2f], z [%.2f, %.2f]" % [aabb.position.x, aabb.end.x, aabb.position.z, aabb.end.z])
	check(aabb.position.x < -0.9 and aabb.end.x < 0.6, "roof eave at rot 1 extends west (Blender -X), as a counter-clockwise quarter turn must")
	eave.queue_free()


func _stone_quadrants(mesh: MeshInstance3D, verts: PackedVector3Array) -> String:
	var q := {"SW": 0, "NE": 0, "SE": 0, "NW": 0}
	for v in verts:
		if v.y <= 0.005:
			continue  # slab, not a stone
		var w: Vector3 = mesh.global_transform * v - mesh.get_parent().global_position
		var bx := w.x
		var by := -w.z
		if absf(bx) < 0.1 or absf(by) < 0.1:
			continue  # the centre stone
		q[("N" if by > 0 else "S") + ("E" if bx > 0 else "W")] += 1
	return str(q)


func _check_palette(mesh: MeshInstance3D) -> void:
	var mat := mesh.mesh.surface_get_material(0) as BaseMaterial3D
	var tex := mat.albedo_texture
	var img := tex.get_image()
	print("palette: %s %s filter=%d (0 nearest, 2 nearest+mipmaps) mipmaps=%s" % [tex.resource_path, tex.get_size(), mat.texture_filter, img.has_mipmaps()])
	check(tex.get_size() == Vector2(128, 64), "palette is 128 x 64")
	check(not img.has_mipmaps(), "palette has no mipmaps")
	check(mat.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS], "palette sampled nearest")
	check(img.get_format() in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8], "palette uncompressed (format %d)" % img.get_format())


func _check_sun() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	var sun: DirectionalLight3D = main.get_node("Sun")
	var dir := -sun.global_transform.basis.z
	var expected := Vector3(-0.4394, -0.6428, -0.6275)  # Blender (-0.4394, 0.6275, -0.6428) as (x, z, -y)
	var elevation := rad_to_deg(asin(-dir.y))
	print("sun direction %s, elevation %.1f deg; expected %s (elevation 40, azimuth 35)" % [dir, elevation, expected])
	check(dir.distance_to(expected) < 0.002, "sun matches the contract sun")
	check(main.get_node("Teahouse").get_child_count() == 141, "main.tscn's Teahouse also built 141 pieces")
	var env: Environment = main.get_node("WorldEnvironment").environment
	print("ambient source=%d (2 = colour) colour=%s energy=%.2f; sun energy=%.2f shadows=%s" % [env.ambient_light_source, env.ambient_light_color, env.ambient_light_energy, sun.light_energy, sun.shadow_enabled])
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_energy > 0.0, "warm ambient light is on (contract AMBIENT colour)")
	main.queue_free()
