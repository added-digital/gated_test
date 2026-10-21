extends Node3D
## The map of toy 3, Far sound: every wall is a segment between two points
## on the ground, built at _ready as a grey box THICK wide and HEIGHT tall.
## Godot axes: x east, z south; the player starts at (0, 0) facing -z, north.
## The numbers are the wall's centre line; a clear face is 0.15 m off it.
## Move the numbers, not the code.
##
##   north is up, not to scale
##
##                        [C]  the chime, (0, -18)
##
##         +-------------------------+   z -11.65  "block north"
##         |      |    | * |         |   * the dead end: the stub x 2.1..4.5, z -11.5..-9.5
##         |      |    +---+         |   the alley: north from the gap, east, north, stop
##         |      |        |         |
##         |      +---+    |         |
##         +--------+   +--+---------+   z -6.15  "north" wall; the obvious gap x -1.2..1.2
##         |                         |
##         |                      |  =   the slit: x 6.15, z -3.45..-2.55 (0.9 m)
##         |          P           |  |   the baffle: x 4.85, z -4.5..-1.0, hides the slit
##         |        (0, 0)           |
##         |                         |
##         |                         |   z 8: the courtyard is open to the south
##        x -6.15                  x 6.15
##
## Around the outside: out the open south end, round the east wall, north
## past the block, and the chime is in the open. The short way: behind the
## baffle, through the slit, then the same.

const HEIGHT := 2.5
const THICK := 0.3
const GREY := Color(0.55, 0.55, 0.55)

## The courtyard's clear inside, (x, z, width, depth): leaving it is a milestone.
const COURTYARD := Rect2(-6, -6, 12, 14)
## The obvious gap: the north wall's centre line and the x span of the opening.
const NORTH_WALL_Z := -6.15
const OBVIOUS_GAP_X := Vector2(-1.2, 1.2)
## The narrow gap: the east wall's centre line and the z span of the slit, 0.9 m.
const EAST_WALL_X := 6.15
const NARROW_GAP_Z := Vector2(-3.45, -2.55)
## The alley's last stub (x, z, width, depth): standing in it is the dead end.
const DEAD_END := Rect2(2.1, -11.5, 2.4, 1.5)

## name, from (x, z), to (x, z); every wall runs along x or along z.
const WALLS := [
	["west", Vector2(-6.15, 8), Vector2(-6.15, -11.8)],
	["east, south of the slit", Vector2(6.15, 8), Vector2(6.15, -2.55)],
	["east, north of the slit", Vector2(6.15, -3.45), Vector2(6.15, -11.8)],
	["baffle", Vector2(4.85, -1.0), Vector2(4.85, -4.5)],
	["north, west of the gap", Vector2(-6.3, -6.15), Vector2(-1.2, -6.15)],
	["north, east of the gap", Vector2(1.2, -6.15), Vector2(6.3, -6.15)],
	["block north", Vector2(-6.3, -11.65), Vector2(6.3, -11.65)],
	["alley west", Vector2(-1.35, -6.15), Vector2(-1.35, -9.65)],
	["alley bend", Vector2(-1.5, -9.65), Vector2(2.1, -9.65)],
	["alley east", Vector2(1.35, -6.15), Vector2(1.35, -6.95)],
	["alley south", Vector2(1.2, -6.95), Vector2(4.65, -6.95)],
	["alley end, east side", Vector2(4.65, -6.8), Vector2(4.65, -11.8)],
	["alley end, west side", Vector2(1.95, -9.65), Vector2(1.95, -11.8)],
]


func _ready() -> void:
	for w in WALLS:
		add_child(_wall(w[0], w[1], w[2]))
	print("[far_sound] %d walls built" % WALLS.size())


## A grey box with collision along the segment from a to b.
static func _wall(wall_name: String, a: Vector2, b: Vector2) -> StaticBody3D:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := a.distance_to(b)
	var size := Vector3(length if along_x else THICK, HEIGHT, THICK if along_x else length)
	var mid := (a + b) / 2.0
	var body := StaticBody3D.new()
	body.name = "Wall " + wall_name
	body.position = Vector3(mid.x, HEIGHT / 2.0, mid.y)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.mesh.material = StandardMaterial3D.new()
	mesh.mesh.material.albedo_color = GREY
	body.add_child(mesh)
	return body
