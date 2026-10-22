extends CharacterBody2D
## The player on the street (toy 4, PINCH): walks left and right at one
## speed on the flat ground, no jump. E is read by the village, not here.
## `frozen` (the village sets it while something is made at the stove shed,
## day 4) holds the body still: the walker stands where it is.

const SPEED := 220.0      # px/s
const GRAVITY := 1200.0   # px/s², to keep the feet on the ground line

var frozen := false


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += GRAVITY * delta
	velocity.x = 0.0 if frozen else Input.get_axis("move_left", "move_right") * SPEED
	move_and_slide()
