extends StaticBody2D
## An idea lying in the dream (toy 4, PINCH), day 3: the only crisp thing
## worth having. A white 48 x 24 rect with a black outline and a drop
## shadow, its name (from data/ideas.json) above it, seen asleep and
## pinched, solid only while pinched (layer CRISP, like a ledge): so a
## set-down idea is a step. `position` is its middle. Groups "idea" and
## "crisp". The dream spawns these (place_idea) and takes them (grab).

const SIZE := Vector2(48, 24)
const LAYER_CRISP := 2
const SHADOW := Color(0, 0, 0, 0.45)

var id := ""
var idea_name := ""

var label: Label = null


## Called before add_child: which idea this is, and its name for the label.
func setup(idea_id: String, shown_name: String) -> void:
	id = idea_id
	idea_name = shown_name
	name = "Idea_%s" % idea_id
	set_meta("id", idea_id)


func _ready() -> void:
	collision_layer = LAYER_CRISP
	collision_mask = 0
	add_to_group("idea")
	add_to_group("crisp")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	var half := SIZE / 2.0
	_rect(-half + Vector2(5, 5), SIZE, SHADOW)
	_rect(-half - Vector2(2, 2), SIZE + Vector2(4, 4), Color.BLACK)
	_rect(-half, SIZE, Color.WHITE)
	label = Label.new()
	label.text = idea_name
	label.position = Vector2(-110, -half.y - 28)
	label.size = Vector2(220, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)


## The box, in the room.
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


func _rect(at: Vector2, size: Vector2, color: Color) -> void:
	var box := ColorRect.new()
	box.position = at
	box.size = size
	box.color = color
	add_child(box)
