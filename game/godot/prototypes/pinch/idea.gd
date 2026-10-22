extends StaticBody2D
## An idea lying in the dream (toy 4b, PINCH): the thing a night is for.
## A white 48 x 24 rect with a black outline and a drop shadow, its name
## (from data/ideas.json) above it, seen asleep and pinched, solid only
## while pinched (layer CRISP, like a ledge). `position` is its middle.
## Groups "idea" and "crisp". The dream lays one in a goal room beside the
## sleeping villager (place_idea, marked `goal`) and the dreamer reaches
## it there (E, pinched: the night ends); it is never carried (SPEC-2).
## The readability pass: the name sits LABEL_ABOVE px over the box's top,
## higher than a body standing beside it, on a dark backing, with a thin
## leader down to the box; its box is kept inside the room's width
## (ROOM_WIDTH) so an idea by a wall is not clipped at the screen's edge.
## The feel (day C): at a reach the name slides up (set_rise: px above
## its place, the leader stretching with it; rise() reads it back).

const SIZE := Vector2(48, 24)
const LAYER_CRISP := 2
const SHADOW := Color(0, 0, 0, 0.45)
const LABEL_WIDTH := 220.0
const LABEL_ABOVE := 40.0     # px between the box's top and the label's bottom
const LEADER := Color(0.85, 0.85, 0.85, 0.7)
const LEADER_WIDTH := 2.0
const ROOM_WIDTH := 1152.0    # room.gd SIZE.x: the label stays inside it

var id := ""
var idea_name := ""

var label: Label = null
var leader: ColorRect = null
var _label_top := 0.0   # the name's y at rest


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
	var label_top := -half.y - LABEL_ABOVE - PinchLabel.LINE
	_label_top = label_top
	var label_x := clampf(-LABEL_WIDTH / 2.0, 4.0 - position.x, ROOM_WIDTH - 4.0 - LABEL_WIDTH - position.x)
	label = PinchLabel.make(idea_name, Vector2(label_x, label_top), LABEL_WIDTH)
	label.name = "Name"
	add_child(label)
	leader = ColorRect.new()
	leader.name = "Leader"
	leader.color = LEADER
	leader.position = Vector2(-LEADER_WIDTH / 2.0, label_top + PinchLabel.LINE)
	leader.size = Vector2(LEADER_WIDTH, LABEL_ABOVE - 2.0)
	add_child(leader)


## The name drawn `px` above its place (the reach), the leader stretched down to the box.
func set_rise(px: float) -> void:
	if label == null:
		return
	label.position.y = _label_top - px
	leader.position.y = _label_top + PinchLabel.LINE - px
	leader.size.y = LABEL_ABOVE - 2.0 + px


## px the name is drawn above its place now.
func rise() -> float:
	return _label_top - label.position.y if label != null else 0.0


## The box, in the room.
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


## The name's box, in the room.
func label_rect() -> Rect2:
	return Rect2(position + label.position, Vector2(LABEL_WIDTH, PinchLabel.LINE))


func _rect(at: Vector2, size: Vector2, color: Color) -> void:
	var box := ColorRect.new()
	box.position = at
	box.size = size
	box.color = color
	add_child(box)
