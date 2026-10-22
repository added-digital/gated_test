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
## away from that edge). The wonder fires once per visit. A grey box with
## the word "goat" from rooms.json.

const PULL := 6.0   # per s: the rider closes the gap to the goat's middle at this rate, never faster than the goat

@export var speed := 300.0
@export var loop := PackedVector2Array()

var follow: PathFollow2D = null
var _carry := Vector2.ZERO   # the goat's motion this frame, px/s
var _prev := Vector2.ZERO    # where the goat was before this frame's step


func _ready() -> void:
	role = "wonder"
	kind = "goat"
	super()
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
