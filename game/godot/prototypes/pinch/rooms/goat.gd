extends "res://prototypes/pinch/rooms/zone.gd"
## The goat (toy 4, PINCH): a current that walks. An Area2D under a
## PathFollow2D under a Path2D; `loop` lists the corners of its round (the
## first is repeated at the end so the round closes) and `speed` is px/s
## along it. It is in the groups "current" and "wonder" (kind goat): while
## the asleep dreamer overlaps it, the dreamer moves as the goat moved this
## frame and settles onto its back (a pull toward the goat's middle, so the
## rider sits on the goat rather than hanging off its edge: a kinematic
## body's position reaches the physics server one step late, and a rider
## hanging by a few px would be dropped the first time the goat turned
## away from that edge). The wonder fires once per visit. The look (the
## readability pass, _draw_goat): a filled rect with two horn triangles on
## its top corners, and the word "goat" from rooms.json ABOVE the body and
## to its left (LABEL_LEFT px short of the rider, who sits over the goat's
## middle), so the rider never covers it.

const PULL := 6.0   # per s: the rider closes the gap to the goat's middle at this rate, never faster than the goat
const BODY_COLOR := Color(0.62, 0.6, 0.55)
const HORN_COLOR := Color(0.8, 0.78, 0.7)
const HORN := Vector2(10, 12)       # px: a horn's base and height
const HORN_IN := 4.0                # px a horn sits in from the top corner
const LABEL_LEFT := 8.0             # px between the label's right end and the rider's clearance
const RIDER_HALF := 16.0            # px either side of the goat's middle kept clear for the rider (the body is 28 wide, plus the hip stack)
const LABEL_WIDTH_GOAT := 100.0

@export var speed := 300.0
@export var loop := PackedVector2Array()

var follow: PathFollow2D = null
var horns: Node2D = null
var _carry := Vector2.ZERO   # the goat's motion this frame, px/s
var _prev := Vector2.ZERO    # where the goat was before this frame's step


func _ready() -> void:
	role = "wonder"
	kind = "goat"
	super()
	_draw_goat()
	add_to_group("current")
	follow = get_parent() as PathFollow2D
	var path := follow.get_parent() as Path2D
	var curve := Curve2D.new()
	for point in loop:
		curve.add_point(point)
	if loop.size() > 1:
		curve.add_point(loop[0])
	path.curve = curve
	follow.loop = true
	follow.rotates = false
	follow.cubic_interp = false
	follow.progress = 0.0
	_prev = global_position


func _physics_process(delta: float) -> void:
	_prev = global_position
	follow.progress += speed * delta
	_carry = (global_position - _prev) / delta


## The goat's own motion this frame, plus the pull onto its back: toward
## where the goat's middle was before this step, since `at` is the rider
## before its own step; so a rider on the back stays exactly on it.
func carry(at: Vector2) -> Vector2:
	var pull := (_prev + size / 2.0 - at) * PULL
	return _carry + pull.limit_length(speed)


func motion() -> Vector2:
	return _carry


## The body: a filled rect and two horns on its top corners.
func _draw_goat() -> void:
	var body := ColorRect.new()
	body.name = "Fill"
	body.size = size
	body.color = BODY_COLOR
	add_child(body)
	horns = Node2D.new()
	horns.name = "Horns"
	for i in 2:
		var x := HORN_IN if i == 0 else size.x - HORN_IN - HORN.x
		var horn := Polygon2D.new()
		horn.name = "HornL" if i == 0 else "HornR"
		horn.color = HORN_COLOR
		horn.polygon = PackedVector2Array([Vector2(x, 0), Vector2(x + HORN.x, 0), Vector2(x + HORN.x / 2.0, -HORN.y)])
		horns.add_child(horn)
	add_child(horns)


## The word above the body and to the left of the rider: its right end
## LABEL_LEFT px short of the rider's clearance, above the horns.
func _label_place() -> Vector2:
	return Vector2(size.x / 2.0 - RIDER_HALF - LABEL_LEFT - LABEL_WIDTH_GOAT, -HORN.y - 4.0 - PinchLabel.LINE)


func _label_align() -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_RIGHT


func _label_width() -> float:
	return LABEL_WIDTH_GOAT


## The goat moves (its position is along its path), so its word is not clamped to the room.
func _label_x(x: float) -> float:
	return x


## The word's box, relative to the goat's top-left corner.
func label_rect() -> Rect2:
	return Rect2(label.position, Vector2(LABEL_WIDTH_GOAT, PinchLabel.LINE)) if label != null else Rect2()


## Where a rider (a body `body_size` big) sits on the goat, relative to the
## goat's top-left corner: on the middle, RIDER_HALF either side of it.
func rider_rect(body_size: Vector2) -> Rect2:
	var top := size.y / 2.0 - body_size.y / 2.0
	return Rect2(size.x / 2.0 - RIDER_HALF, top, RIDER_HALF * 2.0, body_size.y)
