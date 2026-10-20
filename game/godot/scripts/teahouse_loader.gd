extends Node3D
## Builds the tea house from the kit's scene JSON when the scene starts, and
## gives every piece collision.
##
## Mapping, kit CONTRACT.md: Blender (x, y, z) z-up  ->  Godot (x, z, -y) y-up.
## rot is 90-degree steps counter-clockwise about Blender +Z seen from above,
## which is rotation_degrees.y = rot * 90 in Godot (tests/load_test.gd proves
## the sign with the stone-path tile and a roof eave).
##
## Collision comes from the category in the JSON, never from mesh names:
## floor, wall, door, pillar, roof, garden -> trimesh; prop, tree -> convex;
## fx -> none. A floor with walkable:false (the pond) also gets a 1 x 0.5 x 1 m
## box on top so the player cannot step in.

const TRIMESH := ["floor", "wall", "door", "pillar", "roof", "garden"]
const CONVEX := ["prop", "tree"]

@export var scene_json := "res://kit/scenes/teahouse.json"
@export var glb_dir := "res://kit/glb/"

var placed := 0        ## pieces instanced
var skipped: Array[String] = []   ## piece names with no GLB


func _ready() -> void:
	var file := FileAccess.open(scene_json, FileAccess.READ)
	if file == null:
		push_error("Cannot open " + scene_json)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var packed_cache := {}   # piece name -> PackedScene
	var shape_cache := {}    # piece name -> Shape3D (shared by every copy)
	for p in data["placements"]:
		var piece: String = p["piece"]
		if not packed_cache.has(piece):
			packed_cache[piece] = load(glb_dir + piece + ".glb")
		var packed: PackedScene = packed_cache[piece]
		if packed == null:
			push_warning("No GLB for " + piece)
			skipped.append(piece)
			continue
		var inst := packed.instantiate() as Node3D
		inst.name = "%s_%d" % [piece, placed]
		inst.position = blender_to_godot(Vector3(p["x"], p["y"], p["z"]))
		inst.rotation_degrees.y = float(p["rot"]) * 90.0
		add_child(inst)
		_add_collision(inst, p, shape_cache)
		placed += 1


static func blender_to_godot(b: Vector3) -> Vector3:
	return Vector3(b.x, b.z, -b.y)


func _add_collision(inst: Node3D, p: Dictionary, shape_cache: Dictionary) -> void:
	var category: String = p.get("category", "prop")
	if not (category in TRIMESH or category in CONVEX):
		return  # fx: no collision
	for mesh_node in inst.find_children("*", "MeshInstance3D", true, false):
		var body := StaticBody3D.new()
		body.name = "Body"
		mesh_node.add_child(body)
		var shape := CollisionShape3D.new()
		var key: String = p["piece"]
		if not shape_cache.has(key):
			if category in TRIMESH:
				shape_cache[key] = mesh_node.mesh.create_trimesh_shape()
			else:
				shape_cache[key] = mesh_node.mesh.create_convex_shape()
		shape.shape = shape_cache[key]
		body.add_child(shape)
		# The pond: a box blocker standing on the (sunken) water tile.
		if category == "floor" and p.get("walkable", true) == false:
			var blocker := CollisionShape3D.new()
			blocker.name = "Blocker"
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, 0.5, 1.0)
			blocker.shape = box
			blocker.position = Vector3(0, 0.25, 0)
			body.add_child(blocker)
