extends StaticBody2D
## A scrap lying in the dream (toy 4b, PINCH, SPEC-2 day A): a half thought,
## small and crisp. A white SIZE (24 x 16) box with a black edge and a drop
## shadow, its shape drawn on it (round: a circle; square: a square; long:
## a bar) and its name (data/scraps.json) above on a backing with a leader,
## like an idea's (idea.gd). Solid only while pinched (layer CRISP), so a
## scrap set down is a small step. `position` is its middle. Groups "scrap"
## and "crisp". The dream spawns these (place_scrap) and takes them
## (grab_scrap); the dealer hangs them at hand height over the rooms'
## spots, so a walk is never blocked by one that nobody set down.

const SIZE := Vector2(24, 16)
const LAYER_CRISP := 2
const SHADOW := Color(0, 0, 0, 0.45)
const MARK := Color(0.2, 0.2, 0.26)
const LABEL_WIDTH := 140.0
const LABEL_ABOVE := 30.0     # px between the box's top and the label's bottom
const LEADER := Color(0.85, 0.85, 0.85, 0.7)
const LEADER_WIDTH := 2.0
const ROOM_WIDTH := 1152.0    # room.gd SIZE.x: the label stays inside it
const ROUND_POINTS := 16

var shape := ""        # round | square | long
var scrap_name := ""

var label: Label = null
var leader: ColorRect = null


## Called before add_child: which shape this is, and its name for the label.
func setup(shape_id: String, shown_name: String) -> void:
	shape = shape_id
	scrap_name = shown_name
	name = "Scrap_%s" % shape_id
	set_meta("shape", shape_id)


func _ready() -> void:
	collision_layer = LAYER_CRISP
	collision_mask = 0
	add_to_group("scrap")
	add_to_group("crisp")
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	collider.shape = rect
	add_child(collider)
	var half := SIZE / 2.0
	_rect(-half + Vector2(3, 3), SIZE, SHADOW)
	_rect(-half - Vector2(2, 2), SIZE + Vector2(4, 4), Color.BLACK)
	_rect(-half, SIZE, Color.WHITE)
	_draw_shape()
	var label_top := -half.y - LABEL_ABOVE - PinchLabel.LINE
	var label_x := clampf(-LABEL_WIDTH / 2.0, 4.0 - position.x, ROOM_WIDTH - 4.0 - LABEL_WIDTH - position.x)
	label = PinchLabel.make(scrap_name, Vector2(label_x, label_top), LABEL_WIDTH)
	label.name = "Name"
	add_child(label)
	leader = ColorRect.new()
	leader.name = "Leader"
	leader.color = LEADER
	leader.position = Vector2(-LEADER_WIDTH / 2.0, label_top + PinchLabel.LINE)
	leader.size = Vector2(LEADER_WIDTH, LABEL_ABOVE - 2.0)
	add_child(leader)


## The shape on the box: a circle, a square or a bar (the node named Mark).
func _draw_shape() -> void:
	match shape:
		"round":
			var circle := Polygon2D.new()
			circle.name = "Mark"
			circle.color = MARK
			var points := PackedVector2Array()
			for i in ROUND_POINTS:
				var a := TAU * i / ROUND_POINTS
				points.append(Vector2(cos(a), sin(a)) * 5.0)
			circle.polygon = points
			add_child(circle)
		"square":
			_rect(Vector2(-5, -5), Vector2(10, 10), MARK).name = "Mark"
		_:
			_rect(Vector2(-8, -2), Vector2(16, 4), MARK).name = "Mark"


## The box, in the room.
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


## The name's box, in the room.
func label_rect() -> Rect2:
	return Rect2(position + label.position, Vector2(LABEL_WIDTH, PinchLabel.LINE))


func _rect(at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = at
	box.size = size
	box.color = color
	add_child(box)
	return box
