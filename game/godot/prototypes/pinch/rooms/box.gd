extends StaticBody2D
## A grey box of room geometry (toy 4, PINCH). `position` is its top-left
## corner and `size` its extent. Crisp (the default) sits on layer CRISP
## (2) and is solid only while the dreamer is pinched. Soft sits on layer
## SOFT (4), is drawn dim, joins the "soft" group, and the dream hides it
## and disables its shape while pinched; the asleep body drifts through it
## too. `word` names a label from rooms.json drawn above the box.

const LAYER_CRISP := 2
const LAYER_SOFT := 4
const CRISP_COLOR := Color(0.5, 0.5, 0.56)
const SOFT_COLOR := Color(0.55, 0.55, 0.72, 0.35)

@export var size := Vector2(64, 64)
@export var soft := false
@export var word := ""

var label: Label = null


func _ready() -> void:
	collision_layer = LAYER_SOFT if soft else LAYER_CRISP
	collision_mask = 0
	add_to_group("soft" if soft else "crisp")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	var box := ColorRect.new()
	box.size = size
	box.color = SOFT_COLOR if soft else CRISP_COLOR
	add_child(box)
	if word != "":
		set_label(word)


func set_label(text: String) -> void:
	if label == null:
		label = Label.new()
		label.position = Vector2(size.x / 2.0 - 60, -26)
		label.size = Vector2(120, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	label.text = text
