extends StaticBody2D
## A grey box of room geometry (toy 4, PINCH). `position` is its top-left
## corner and `size` its extent. Crisp (the default) sits on layer CRISP
## (2), is drawn as a filled rect, and is solid only while the dreamer is
## pinched. Soft sits on layer SOFT (4), joins the "soft" group, and the
## dream hides it and disables its shape while pinched; the asleep body
## drifts through it too. The readability pass: a soft thing is drawn pale
## (SOFT_FILL, 0.45 alpha) with a dashed outline (draw_soft: small rects
## along the four edges), so it is told from a crisp box, a wonder spot and
## a current at a glance; zone.gd draws its soft walls with the same helper.
## `word` names a label from rooms.json drawn ABOVE the box (LABEL_ABOVE
## px over its top, clear of a body standing beside it) on a dark backing.

const LAYER_CRISP := 2
const LAYER_SOFT := 4
const CRISP_COLOR := Color(0.5, 0.5, 0.56)
const SOFT_FILL := Color(0.78, 0.78, 0.92, 0.45)
const SOFT_DASH := Color(0.88, 0.88, 1.0, 0.85)
const DASH := 8.0            # px: one dash of the soft outline
const DASH_GAP := 6.0        # px between dashes
const DASH_THICK := 2.0      # px: the outline's thickness
const LABEL_ABOVE := 36.0    # px between the box's top and the label's bottom
const LABEL_WIDTH := 140.0
const ROOM_WIDTH := 1152.0   # room.gd SIZE.x: the word stays inside it

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
	if soft:
		draw_soft(self, size)
	else:
		var box := ColorRect.new()
		box.name = "Fill"
		box.size = size
		box.color = CRISP_COLOR
		add_child(box)
	if word != "":
		set_label(word)


## The soft look under `holder`: a pale fill and a dashed outline of small
## rects along the edges. Returns the node holding it (its metadata
## `dashes` counts the dash rects).
static func draw_soft(holder: Node, extent: Vector2) -> Node2D:
	var look := Node2D.new()
	look.name = "SoftLook"
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.size = extent
	fill.color = SOFT_FILL
	look.add_child(fill)
	var dashes := 0
	var x := 0.0
	while x < extent.x:
		var w := minf(DASH, extent.x - x)
		_dash(look, Rect2(x, 0, w, DASH_THICK))
		_dash(look, Rect2(x, extent.y - DASH_THICK, w, DASH_THICK))
		dashes += 2
		x += DASH + DASH_GAP
	var y := DASH + DASH_GAP
	while y < extent.y - DASH:
		var h := minf(DASH, extent.y - y)
		_dash(look, Rect2(0, y, DASH_THICK, h))
		_dash(look, Rect2(extent.x - DASH_THICK, y, DASH_THICK, h))
		dashes += 2
		y += DASH + DASH_GAP
	look.set_meta("dashes", dashes)
	holder.add_child(look)
	return look


static func _dash(holder: Node, rect: Rect2) -> void:
	var dash := ColorRect.new()
	dash.position = rect.position
	dash.size = rect.size
	dash.color = SOFT_DASH
	holder.add_child(dash)


## The word above the box, on a backing; made on the first call.
func set_label(text: String) -> void:
	if label == null:
		var x := clampf(size.x / 2.0 - LABEL_WIDTH / 2.0, 4.0 - position.x, ROOM_WIDTH - 4.0 - LABEL_WIDTH - position.x)
		label = PinchLabel.make(text, Vector2(x, -LABEL_ABOVE - PinchLabel.LINE), LABEL_WIDTH)
		label.name = "Word"
		add_child(label)
	PinchLabel.set_text(label, text)
