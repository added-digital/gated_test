@tool
extends EditorScript
## Imports scenes/teahouse.json into the open Godot 4.3+ scene.
##
## UNTESTED SCAFFOLD: written without a Godot install at hand. Expect to fix
## small things on first run; the shape is right, the details may not be.
##
## Setup: copy build/glb/ into res://kit/glb/ and scenes/teahouse.json into
## res://kit/scenes/. Set the palette's import to Lossless, filter Nearest,
## mipmaps off (Import dock, select sakura_palette inside any .glb). Then
## File > Run (Ctrl+Shift+X) with a 3D scene open.
##
## Mapping: Blender (x, y, z) z-up  ->  Godot (x, z, -y) y-up; rot steps about Z
## become rotation_degrees.y = rot * 90 (sign checked by the stone-path tile:
## place it at rot 0 and rot 1 and compare with the Blender render).
## Collision comes from the category in the JSON, never from mesh names.

const SCENE_JSON := "res://kit/scenes/teahouse.json"
const GLB_DIR := "res://kit/glb/"
const TRIMESH := ["floor", "wall", "door", "pillar", "roof", "garden"]
const CONVEX := ["prop", "tree"]

func _run() -> void:
	var root := get_scene()
	if root == null:
		push_error("Open a 3D scene first.")
		return
	var file := FileAccess.open(SCENE_JSON, FileAccess.READ)
	if file == null:
		push_error("Missing " + SCENE_JSON)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var holder := Node3D.new()
	holder.name = "Teahouse"
	root.add_child(holder)
	holder.owner = root
	var cache := {}
	for p in data["placements"]:
		var piece: String = p["piece"]
		if not cache.has(piece):
			cache[piece] = load(GLB_DIR + piece + ".glb")
		var packed: PackedScene = cache[piece]
		if packed == null:
			push_warning("No GLB for " + piece)
			continue
		var inst := packed.instantiate() as Node3D
		inst.name = piece
		inst.position = Vector3(p["x"], p["z"], -p["y"])
		inst.rotation_degrees.y = float(p["rot"]) * 90.0
		holder.add_child(inst)
		inst.owner = root
		_add_collision(inst, p, root)

func _add_collision(inst: Node3D, p: Dictionary, root: Node) -> void:
	var category: String = p.get("category", "prop")
	var mesh_node := _find_mesh(inst)
	if mesh_node == null:
		return
	var body := StaticBody3D.new()
	body.name = "Body"
	mesh_node.add_child(body)
	body.owner = root
	var shape := CollisionShape3D.new()
	if category in TRIMESH:
		shape.shape = mesh_node.mesh.create_trimesh_shape()
	elif category in CONVEX:
		shape.shape = mesh_node.mesh.create_convex_shape()
	else:
		return  # fx: no collision
	body.add_child(shape)
	shape.owner = root
	# A non-walkable floor (the pond) gets a box blocker so the capsule cannot step in.
	var extras: Dictionary = mesh_node.get_meta("extras", {}) if mesh_node.has_meta("extras") else {}
	if category == "floor" and extras.get("sakura_walkable", true) == false:
		var blocker := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 0.5, 1.0)
		blocker.shape = box
		blocker.position = Vector3(0, 0.25, 0)
		body.add_child(blocker)
		blocker.owner = root

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
