extends Area2D
## A rectangle of the dream the dreamer can be inside (toy 4, PINCH).
## `position` is its top-left corner and `size` its extent; it watches the
## DREAMER layer only. Its role puts it in one group the dream polls:
##   current  carries the asleep body at `velocity` px/s (summed with other currents)
##   wonder   lowers lucidity once per visit (`id`); `kind` says how it is earned:
##            soft_wall  drift through it asleep (also in group "soft": gone while pinched)
##            spot       stay still inside it for 3 s
##            goat       be carried by it (see goat.gd)
##   exit     stand in it pinched to go to the next room
##   hazard   touch it pinched and the screen fails
## `word` names a label from rooms.json drawn inside the box.

const LAYER_DREAMER := 16
const COLORS := {
	"current": Color(0.45, 0.55, 0.8, 0.18),
	"wonder": Color(0.55, 0.55, 0.72, 0.35),
	"exit": Color(0.75, 0.75, 0.6, 0.5),
	"hazard": Color(0.1, 0.1, 0.16, 0.9),
}

@export var size := Vector2(64, 64)
@export_enum("current", "wonder", "exit", "hazard") var role: String = "current"
@export var velocity := Vector2.ZERO   # current: px/s while the asleep body overlaps
@export var id := ""                   # wonder: consumed once per visit
@export_enum("soft_wall", "spot", "goat") var kind: String = "soft_wall"
@export var word := ""

var label: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_DREAMER
	add_to_group(role)
	if role == "wonder" and kind == "soft_wall":
		add_to_group("soft")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	var box := ColorRect.new()
	box.size = size
	box.color = COLORS.get(role, Color.GRAY)
	add_child(box)
	if word != "":
		set_label(word)


## What this zone adds to the velocity of the asleep body at `at`.
func carry(_at: Vector2) -> Vector2:
	return velocity


## The middle of the box, in the room.
func center() -> Vector2:
	return global_position + size / 2.0


func set_label(text: String) -> void:
	if label == null:
		label = Label.new()
		label.position = Vector2(size.x / 2.0 - 60, size.y / 2.0 - 11)
		label.size = Vector2(120, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	label.text = text
