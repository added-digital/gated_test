extends Node3D
## The map of toy 3, Far sound: every wall is a segment between two points
## on the ground, built at _ready as a grey box THICK wide and HEIGHT tall.
## Godot axes: x east, z south; the player starts at (0, 0) facing -z, north.
## The numbers are the wall's centre line; a clear face is 0.15 m off it.
## Move the numbers, not the code.
##
## Three blocks, three searches, north is up, not to scale:
##
##                              [1]  chime 1, (0, -18): search 1
##
##                          +-----------+          z -11.65  "block north"
##                          |    |  |*| |          * the dead end: the stub x 2.1..4.5, z -11.5..-9.5
##                          |    |  +-+ |          the alley: north from the gap, east, north, stop
##                          |    +-+    |
##                          +----+ +----+          z -6.15  "north" wall; the obvious gap x -1.2..1.2
##                          |          |          +---------------+   z -8
##                          |          |=         |               |   = the slit: x 6.15, z -3.45..-2.55 (0.9 m),
##                          |    P     ||         G   [3]         =     behind the baffle (x 4.85, z -4.5..-1.0)
##          +----------+    |  (0, 0)  |          |   the pen     |   G the gate: x 10, z -1.6..1.6; the slab
##          |          |    |          |          |               |     slides north when you step in behind it
##          =  [2]     |    |          |          +---------------+   z 8; = the pen's opening: x 24, z -1.5..1.5
##          | the yard |     open, z 8           x 10            x 24   [3] chime 3, (13, 0): search 3, the longest
##          +----------+                                              [2] chime 2, (-12, 6): search 2
##        x -22      x -10 x -6.15   x 6.15                           = the yard's opening: x -22, z 4.5..7.5
##          z 0..12
##
## Search 1, the courtyard: out the open south end and round the outside
## works; behind the baffle, through the slit, then the same, is the short
## way; the obvious gap is a dead end. Search 2, the yard: the chime is just
## behind its east wall; the one way in faces west, so it is round the
## outside, either side. Search 3, the pen: the chime is just behind the
## gate; the gate will not move from the corridor side; the way is round
## the pen to its east opening, and stepping into the pen's west half
## slides the gate away for good: the short way back.

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
## The yard's one opening: its west wall's centre line and the z span, 3 m.
const YARD_WEST_X := -22.0
const YARD_OPENING_Z := Vector2(4.5, 7.5)
## The gate: the pen's west wall's centre line, the z span the slab fills
## (the Gate node in the scene sits 0.35 m inside it), and how far the slab
## slides when the GateTrigger node is stepped into: the pen's west half,
## x 11..16, a metre clear of the slab so a push from the corridor side
## (the capsule reaches x 10.3) cannot touch it.
const GATE_WALL_X := 10.0
const GATE_Z := Vector2(-1.6, 1.6)
const GATE_SLIDE := Vector3(0, 0, -3.5)
## Standing here, on the corridor side of the closed gate, is the gate_found milestone.
const GATE_FRONT := Rect2(9.2, -1.6, 0.8, 3.2)
## The pen's far opening: its east wall's centre line and the z span, 3 m.
const PEN_EAST_X := 24.0
const PEN_OPENING_Z := Vector2(-1.5, 1.5)

## name, from (x, z), to (x, z); every wall runs along x or along z.
const WALLS := [
	# search 1: the courtyard and its alley
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
	# search 2: the yard, open on the west only
	["yard north", Vector2(-22.15, 0), Vector2(-9.85, 0)],
	["yard east", Vector2(-10, 0), Vector2(-10, 12)],
	["yard south", Vector2(-22.15, 12), Vector2(-9.85, 12)],
	["yard west, north of the opening", Vector2(-22, 0), Vector2(-22, 4.5)],
	["yard west, south of the opening", Vector2(-22, 7.5), Vector2(-22, 12)],
	# search 3: the pen, the gate in its west wall, open on the east
	["pen north", Vector2(9.85, -8), Vector2(24.15, -8)],
	["pen south", Vector2(9.85, 8), Vector2(24.15, 8)],
	["pen west, north of the gate", Vector2(10, -8), Vector2(10, -1.6)],
	["pen west, south of the gate", Vector2(10, 1.6), Vector2(10, 8)],
	["pen east, north of the opening", Vector2(24, -8), Vector2(24, -1.5)],
	["pen east, south of the opening", Vector2(24, 1.5), Vector2(24, 8)],
]

## Lines the toy counts the player crossing, for the log: the action's kind,
## its name, the axis the line is fixed on ("x" or "z"), its coordinate, the
## span along the other axis, and the detail word for crossing toward the
## smaller coordinate, then toward the larger. gap_used: an opening in a
## wall. route: which way round a block they went.
const CROSSINGS := [
	["gap_used", "obvious", "z", NORTH_WALL_Z, OBVIOUS_GAP_X, "out", "back"],
	["gap_used", "narrow", "x", EAST_WALL_X, NARROW_GAP_Z, "back", "out"],
	["gap_used", "yard", "x", YARD_WEST_X, YARD_OPENING_Z, "out", "in"],
	["gap_used", "pen", "x", PEN_EAST_X, PEN_OPENING_Z, "in", "out"],
	["gap_used", "gate", "x", GATE_WALL_X, GATE_Z, "out", "in"],
	["route", "west corridor", "z", 4.0, Vector2(-9.85, -6.3), "going north", "going south"],
	["route", "east corridor", "z", 4.0, Vector2(6.3, 9.85), "going north", "going south"],
	["route", "north of the yard", "x", -16.0, Vector2(-27, -0.15), "going west", "going east"],
	["route", "south of the yard", "x", -16.0, Vector2(12.15, 21), "going west", "going east"],
	["route", "north of the pen", "x", 17.0, Vector2(-27, -8.15), "going west", "going east"],
	["route", "south of the pen", "x", 17.0, Vector2(8.15, 21), "going west", "going east"],
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
