extends CharacterBody2D
## The player in the dream (toy 4, PINCH), day 2: two states.
##
## ASLEEP (PINCH not held): no gravity. The body hangs where it is, nudged
## left and right at DRIFT_SPEED and carried by the sum of the currents it
## overlaps; it collides with nothing but the room's bounds, so it drifts
## through soft and crisp things alike; it cannot jump, grab or push.
## PINCHED (PINCH held): gravity, walking at street speed, a jump; crisp
## geometry is solid and soft geometry is gone (the dream disables it);
## currents do nothing. Releasing mid-air stops the fall where the body is.
##
## A landing while pinched more than one body (BODY_HEIGHT) below where the
## fall began is a hard landing, reported to the dream as an act. The fall
## begins where the feet last left a floor (a jump, a step off a ledge) or,
## for a pinch in mid-air, at the pinch; so a jump on flat ground is free
## and a drop off a ledge taller than the body is not. Dropping below the
## room is reported as fell_out; the dream blinks and puts the body back
## at the door. E is read by the dream, not here.
##
## Collision layers (bits); the whole dream uses these:
##   1  BOUNDS  (1)   the room's left, right and top: solid asleep and pinched
##   2  CRISP   (2)   floors, ledges, blocks: solid only while pinched
##   3  SOFT    (4)   soft walls and pillars: never solid for the body; the
##                    dream hides them and disables their shapes while pinched
##   4  NET     (8)   the room's bottom while asleep; the pinched body falls through it
##   5  DREAMER (16)  this body; currents, wonders, exits and hazards (Area2Ds) mask it

signal hard_landing
signal fell_out
signal pinch_changed(pinched: bool)

const LAYER_BOUNDS := 1
const LAYER_CRISP := 2
const LAYER_SOFT := 4
const LAYER_NET := 8
const LAYER_DREAMER := 16
const MASK_ASLEEP := LAYER_BOUNDS | LAYER_NET
const MASK_PINCHED := LAYER_BOUNDS | LAYER_CRISP

const WALK_SPEED := 220.0   # px/s pinched
const DRIFT_SPEED := 60.0   # px/s asleep, the nudge
const JUMP_SPEED := 520.0   # px/s; the apex is about 100 px at 60 Hz
const GRAVITY := 1400.0     # px/s² pinched
const BODY_HEIGHT := 56.0   # px: a drop taller than this lands hard
const ROOM_HEIGHT := 648.0  # px: below this the body has fallen out of the room
const BOB := 4.0            # px: the asleep sway, drawn only; the body itself does not move
const HAT_PIECE := Vector2(22, 8)
const SOFT := Color(0.6, 0.6, 0.66)
const CRISP := Color(0.88, 0.88, 0.88)

@onready var body: ColorRect = $Body
@onready var hat: Node2D = $Hat

var pinched := false
var frozen := false          # during the dream's blink: no physics, not drawn
var carried_by: Array = []   # the currents overlapping this frame (asleep only)
var _drop_from := 0.0        # y where the current fall began
var _settling := 0           # frames after a respawn during which no current is read (see respawn)
var _jump_held := false
var _time := 0.0


func _ready() -> void:
	collision_layer = LAYER_DREAMER
	collision_mask = MASK_ASLEEP
	_drop_from = position.y


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var now_pinched := Input.is_action_pressed("pinch")
	if now_pinched != pinched:
		pinched = now_pinched
		collision_mask = MASK_PINCHED if pinched else MASK_ASLEEP
		body.color = CRISP if pinched else SOFT
		if pinched and not is_on_floor():
			_drop_from = position.y   # a pinch in mid-air: the fall starts here
		pinch_changed.emit(pinched)
	var axis := Input.get_axis("move_left", "move_right")
	var jump_now := pinched and Input.is_action_pressed("jump")
	var jump_pressed := jump_now and not _jump_held
	_jump_held = jump_now
	if pinched:
		body.position.y = -28.0
		velocity.x = axis * WALK_SPEED
		if is_on_floor():
			velocity.y = 0.0
			if jump_pressed:
				velocity.y = -JUMP_SPEED
		else:
			velocity.y += GRAVITY * delta
		carried_by = []   # pinched: no current holds the body; never keep a stale (freed) area
	else:
		_time += delta
		body.position.y = -28.0 + sin(_time * 2.0) * BOB
		carried_by = []
		var carry := Vector2.ZERO
		if _settling > 0:
			_settling -= 1
		else:
			for area in get_tree().get_nodes_in_group("current"):
				if area.overlaps_body(self):
					carried_by.append(area)
					carry += area.carry(position)
		velocity = Vector2(axis * DRIFT_SPEED, 0.0) + carry
	var was_on_floor := is_on_floor()
	var y_before := position.y
	move_and_slide()
	if not pinched:
		return
	var on_floor := is_on_floor()
	if was_on_floor and not on_floor:
		_drop_from = y_before   # the feet left a floor: a jump, or a step off an edge
	elif on_floor and not was_on_floor and position.y - _drop_from > BODY_HEIGHT:
		hard_landing.emit()
	if position.y > ROOM_HEIGHT:
		fell_out.emit()


## True while the body is not moving (hovering, or standing with no input).
func is_still() -> bool:
	return velocity.length_squared() < 1.0


## The dream's blink: stop and vanish until respawn().
func freeze() -> void:
	frozen = true
	visible = false
	velocity = Vector2.ZERO
	carried_by = []


## Back in the room at a door, as if nothing had fallen. A kinematic body's
## new place reaches the physics server one step late, so the overlaps it
## reports are stale for two frames; no current is read until then.
func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	_drop_from = at.y
	_settling = 2
	frozen = false
	visible = true


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
