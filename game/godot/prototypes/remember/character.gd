extends Node3D
## The one character of the Remember toy: a grey capsule with a name over
## it. It stands still until told to walk_to a spot, then glides there at
## SPEED and emits arrived. The name comes from dialogue.json, via the toy.

signal arrived

const SPEED := 1.6   # m/s: a slow glide the player can follow at a walk

var walking := false
var target := Vector3.ZERO

@onready var name_label: Label3D = $Name


func set_display_name(display_name: String) -> void:
	name_label.text = display_name


func walk_to(spot: Vector3) -> void:
	target = Vector3(spot.x, global_position.y, spot.z)
	walking = true


func _physics_process(delta: float) -> void:
	if not walking:
		return
	var to := target - global_position
	if to.length() <= SPEED * delta:
		global_position = target
		walking = false
		arrived.emit()
	else:
		global_position += to.normalized() * SPEED * delta
