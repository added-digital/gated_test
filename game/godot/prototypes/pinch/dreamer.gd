extends CharacterBody2D
## The player in the dream (toy 4, PINCH). Asleep (PINCH not held) there is
## no gravity: the body hovers where it is with a slow drift and moves
## slowly. Pinched, the world is solid: gravity, walking at street speed, a
## jump. Landing from higher than one body while pinched is a hard landing
## (the dream counts it as an act). The hat stack above the head shows how
## many ideas are carried. E is read by the dream, not here.

signal hard_landing

const WALK_SPEED := 220.0   # px/s pinched
const DRIFT_SPEED := 60.0   # px/s asleep
const JUMP_SPEED := 520.0   # px/s
const GRAVITY := 1400.0     # px/s² pinched
const BOB := 10.0           # px/s: the asleep drift, a slow sway of about BOB px up and down
const BODY_HEIGHT := 56.0   # px: a drop taller than this lands hard
const HAT_PIECE := Vector2(22, 8)
const SOFT := Color(0.6, 0.6, 0.66)
const CRISP := Color(0.88, 0.88, 0.88)

@onready var body: ColorRect = $Body
@onready var hat: Node2D = $Hat

var pinched := false
var _time := 0.0
var _apex := 0.0        # the highest point (lowest y) since the feet left the floor
var _airborne := false


func _physics_process(delta: float) -> void:
	pinched = Input.is_action_pressed("pinch")
	body.color = CRISP if pinched else SOFT
	var axis := Input.get_axis("move_left", "move_right")
	if pinched:
		velocity.x = axis * WALK_SPEED
		if is_on_floor():
			velocity.y = 0.0
			if Input.is_action_just_pressed("jump"):
				velocity.y = -JUMP_SPEED
		else:
			velocity.y += GRAVITY * delta
	else:
		_time += delta
		velocity.x = axis * DRIFT_SPEED
		velocity.y = cos(_time) * BOB
	var was_airborne := _airborne
	move_and_slide()
	_airborne = not is_on_floor()
	if _airborne:
		_apex = position.y if not was_airborne else minf(_apex, position.y)
	elif was_airborne and pinched and position.y - _apex > BODY_HEIGHT:
		hard_landing.emit()


## The hat stack: one small rect per idea carried, piled above the head.
func set_hat(count: int) -> void:
	for piece in hat.get_children():
		hat.remove_child(piece)
		piece.queue_free()
	for i in count:
		var piece := ColorRect.new()
		piece.color = Color.WHITE
		piece.size = HAT_PIECE
		piece.position = Vector2(-HAT_PIECE.x / 2.0, -(i + 1) * (HAT_PIECE.y + 2.0))
		hat.add_child(piece)


func hat_count() -> int:
	return hat.get_child_count()
