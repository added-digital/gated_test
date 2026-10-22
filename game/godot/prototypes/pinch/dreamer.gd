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
## at the door. E and Q are read by the dream, not here.
##
## The hat (day 3): one white rect per idea carried, HAT_PIECE tall each,
## piled above the head; the pile's height is the carry readout. Asleep
## the pieces wobble, pinched they sit still; while the top one is "in
## hand" (the two seconds after a grab, counted double by the dream) it
## is offset to the side. `facing` is the last way the body was pushed,
## for the dream's set-down. The hip stack (SPEC-2, day A): one small
## white rect per scrap carried, HIP_PIECE each, piled beside the hip (not
## on the hat; scraps are small); set_hip(count) draws it, hip_count()
## reads it. Drawn only: nothing of the physics changes.
##
## The feel (day 5), drawn only, every number a constant below: the body
## rect squashes (SQUASH) for SQUASH_FRAMES after a pinched landing and
## stretches (STRETCH) as long at a jump, scaled about the feet; the hat
## stack dips HAT_BOUNCE px and settles when an idea joins it; at a
## respawn (a new room, or the door after a blink) the body drops in from
## DROP_IN px above over DROP_IN_FRAMES, so the reappearance reads.
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
const HAT_PIECE := Vector2(32, 24)   # px: one carried idea on the hat; the pile is count * 24 tall
const HAT_GAP := 2.0                 # px between pieces
const HAND_OFFSET := 20.0            # px the in-hand piece sits to the side
const WOBBLE := 3.0                  # px the pieces sway asleep
const BODY_SIZE := Vector2(28, 56)
const HIP_PIECE := Vector2(12, 8)    # px: one scrap at the hip
const HIP_GAP := 2.0
const HIP_SIDE := 6.0                # px between the body's side and the hip stack
const SQUASH := Vector2(1.2, 0.8)    # the body's scale for SQUASH_FRAMES after a pinched landing
const STRETCH := Vector2(0.8, 1.2)   # ... and for as long at the start of a jump
const SQUASH_FRAMES := 6
const HAT_BOUNCE := 6.0              # px the hat stack dips when an idea joins it, then settles
const HAT_BOUNCE_FRAMES := 8
const DROP_IN := 8.0                 # px above its place the body appears at a respawn, drawn only
const DROP_IN_FRAMES := 8
const SOFT := Color(0.6, 0.6, 0.66)
const CRISP := Color(0.88, 0.88, 0.88)

@onready var body: ColorRect = $Body
@onready var hat: Node2D = $Hat

var hip: Node2D = null       # the scraps carried, one small rect each, beside the hip

var pinched := false
var frozen := false          # during the dream's blink: no physics, not drawn
var facing := 1              # 1 right, -1 left: the last way the body was pushed
var in_hand := false         # the top hat piece is in the hand (set_hat)
var carried_by: Array = []   # the currents overlapping this frame (asleep only)
var _drop_from := 0.0        # y where the current fall began
var _settling := 0           # frames after a respawn during which no current is read (see respawn)
var _jump_held := false
var _time := 0.0
var _squash := Vector2.ONE   # the body's scale while _squash_left > 0
var _squash_left := 0        # frames of squash or stretch left
var _bounce_left := 0        # frames of the hat's settle bounce left
var _drop_in_left := 0       # frames of the respawn drop-in left


func _ready() -> void:
	collision_layer = LAYER_DREAMER
	collision_mask = MASK_ASLEEP
	body.pivot_offset = Vector2(BODY_SIZE.x / 2.0, BODY_SIZE.y)   # scaled about the feet
	_drop_from = position.y
	hip = Node2D.new()
	hip.name = "Hip"
	add_child(hip)


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
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	var jump_now := pinched and Input.is_action_pressed("jump")
	var jump_pressed := jump_now and not _jump_held
	_jump_held = jump_now
	if pinched:
		body.position.y = -BODY_SIZE.y / 2.0 - drop_in()
		velocity.x = axis * WALK_SPEED
		if is_on_floor():
			velocity.y = 0.0
			if jump_pressed:
				velocity.y = -JUMP_SPEED
				_squash = STRETCH
				_squash_left = SQUASH_FRAMES
		else:
			velocity.y += GRAVITY * delta
		carried_by = []   # pinched: no current holds the body; never keep a stale (freed) area
	else:
		_time += delta
		body.position.y = -BODY_SIZE.y / 2.0 + sin(_time * 2.0) * BOB - drop_in()
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
	_place_hat()
	_place_hip()
	var was_on_floor := is_on_floor()
	var y_before := position.y
	move_and_slide()
	if pinched:
		var on_floor := is_on_floor()
		if was_on_floor and not on_floor:
			_drop_from = y_before   # the feet left a floor: a jump, or a step off an edge
		elif on_floor and not was_on_floor:
			_squash = SQUASH
			_squash_left = SQUASH_FRAMES
			if position.y - _drop_from > BODY_HEIGHT:
				hard_landing.emit()
	_draw_feel()
	if pinched and position.y > ROOM_HEIGHT:
		fell_out.emit()


## The frame counters of the feel, after the step: the body's squash or
## stretch, then the counters tick down.
func _draw_feel() -> void:
	body.scale = _squash if _squash_left > 0 else Vector2.ONE
	if _squash_left > 0:
		_squash_left -= 1
	if _bounce_left > 0:
		_bounce_left -= 1
	if _drop_in_left > 0:
		_drop_in_left -= 1


## px the body is drawn above its place, settling from DROP_IN to 0 after a respawn.
func drop_in() -> float:
	return DROP_IN * _drop_in_left / float(DROP_IN_FRAMES)


## px the hat stack is dipped by the settle bounce now; 0 when settled.
func hat_bounce() -> float:
	if _bounce_left <= 0:
		return 0.0
	return HAT_BOUNCE * sin(PI * (HAT_BOUNCE_FRAMES - _bounce_left + 1) / float(HAT_BOUNCE_FRAMES + 1))


## The body's scale now: SQUASH, STRETCH or one.
func body_scale() -> Vector2:
	return body.scale


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
	_drop_in_left = DROP_IN_FRAMES
	frozen = false
	visible = true


## The body's box, in the room.
func rect() -> Rect2:
	return Rect2(position - BODY_SIZE / 2.0, BODY_SIZE)


## The hat stack: one rect per idea carried, piled above the head; the top
## one to the side while it is in the hand.
func set_hat(count: int, top_in_hand := false) -> void:
	in_hand = top_in_hand and count > 0
	if count > hat.get_child_count():
		_bounce_left = HAT_BOUNCE_FRAMES   # an idea joined the pile: it settles with a bounce
	for piece in hat.get_children():
		hat.remove_child(piece)
		piece.queue_free()
	for i in count:
		var piece := ColorRect.new()
		piece.color = Color.WHITE
		piece.size = HAT_PIECE
		piece.position = Vector2(-HAT_PIECE.x / 2.0, -(i + 1) * HAT_PIECE.y - i * HAT_GAP)
		hat.add_child(piece)
	_place_hat()


func hat_count() -> int:
	return hat.get_child_count()


## The hip stack: one small rect per scrap carried, piled up the body's
## side opposite to where it faces (the hand is on the facing side).
func set_hip(count: int) -> void:
	for piece in hip.get_children():
		hip.remove_child(piece)
		piece.queue_free()
	for i in count:
		var piece := ColorRect.new()
		piece.color = Color.WHITE
		piece.size = HIP_PIECE
		piece.position = Vector2(0.0, 8.0 - (i + 1) * (HIP_PIECE.y + HIP_GAP))   # the first just above the hip, the rest up the side
		hip.add_child(piece)
	_place_hip()


func hip_count() -> int:
	return hip.get_child_count()


## px from the head to the top of the pile: 24 per idea carried.
func hat_height() -> float:
	return hat_count() * HAT_PIECE.y


## The top piece's sideways offset: HAND_OFFSET in hand, the wobble asleep, 0 pinched.
func hat_top_offset() -> float:
	var count := hat_count()
	return 0.0 if count == 0 else hat.get_child(count - 1).position.x + HAT_PIECE.x / 2.0


## The hip stack sits on the side the body does not face, following the bob.
func _place_hip() -> void:
	var side := -facing
	hip.position = Vector2(side * (BODY_SIZE.x / 2.0 + HIP_SIDE) - (HIP_PIECE.x if side < 0 else 0.0), body.position.y + BODY_SIZE.y / 2.0)


## The pile follows the head (the body bobs asleep); each piece sways asleep
## and sits still pinched; the in-hand piece sits to the side the body faces.
func _place_hat() -> void:
	hat.position = Vector2(0.0, body.position.y + hat_bounce())
	var count := hat.get_child_count()
	for i in count:
		var piece: ColorRect = hat.get_child(i)
		var x := -HAT_PIECE.x / 2.0
		if not pinched:
			x += sin(_time * 3.0 + i * 0.9) * WOBBLE
		if in_hand and i == count - 1:
			x += HAND_OFFSET * facing
		piece.position.x = x
