extends Node3D
## The someone in a rush (toy 2, Help). Hurries back and forth between two
## points at SPEED, turning at each end; the posts in help.tscn stand at
## those points. stop_for(node) parks it facing that node (the toy calls it
## when a request opens); go() sends it on again. passed_an_end is true once
## it has reached an end since the last go(), so the toy offers the next
## request only after the runner has run off, turned and come back past.
## The small box on its front shows which way it faces.

@export var from := Vector3(-15, 0, 0)   # one end of the path
@export var to := Vector3(15, 0, 0)      # the other end
@export var speed := 5.0                 # m/s: faster than the player's 3.5

var stopped := false
var facing: Node3D = null     # who it faces while stopped
var passed_an_end := true     # reached an end since the last go(): may stop again
var _goal := Vector3.ZERO


func _ready() -> void:
	global_position = from
	_goal = to


func _physics_process(delta: float) -> void:
	if stopped:
		if facing != null:
			_face(facing.global_position)
		return
	var step := speed * delta
	var toward := _goal - global_position
	toward.y = 0.0
	if toward.length() <= step:
		global_position = _goal
		_goal = from if _goal == to else to   # turn around
		passed_an_end = true
	else:
		global_position += toward.normalized() * step
	_face(_goal)


## Stop and keep facing node (the player) until go().
func stop_for(node: Node3D) -> void:
	stopped = true
	facing = node
	_face(node.global_position)


## Hurry on; no stopping again before the next end of the path.
func go() -> void:
	stopped = false
	facing = null
	passed_an_end = false


func _face(point: Vector3) -> void:
	var level := Vector3(point.x, global_position.y, point.z)
	if level.distance_to(global_position) > 0.01:
		look_at(level, Vector3.UP)   # -z (the nose) points at it
