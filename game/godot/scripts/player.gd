extends CharacterBody3D
## First-person walker. Contract numbers (scale pass, breaks.md 2026-10-21):
## capsule radius 0.30 m, height 1.80 m, eye height 1.60 m, camera 90 degrees
## HORIZONTAL field of view (Camera3D keep_aspect KEEP_WIDTH, fov 90; all in
## player.tscn), 3.5 m/s. Mouse looks (Esc frees or recaptures the mouse),
## WASD walks, gravity pulls. No jump, no step-up logic.
##
## The node's origin is at the feet, like the kit's pieces, so spawning the
## player at a floor tile's position stands it on that tile.

const SPEED := 3.5                   # walking speed, m/s
const LOOK := 0.002                  # radians per mouse pixel
const PITCH_LIMIT := deg_to_rad(80)  # how far the head tilts up or down

## Tests drive the body with this instead of the keyboard: a direction in the
## world's xz plane, set every physics frame. Zero means "read the keys".
var auto_move := Vector3.ZERO

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head    # carries the camera at 1.60 m


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK)            # mouse left/right turns the body
		head.rotate_x(-event.relative.y * LOOK)       # mouse up/down tilts the head
		head.rotation.x = clampf(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_cancel"):
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var dir := auto_move
	if dir == Vector3.ZERO:
		var keys := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = transform.basis * Vector3(keys.x, 0.0, keys.y)   # forward is where the body faces
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()   # the physics engine moves the capsule and stops it at walls
