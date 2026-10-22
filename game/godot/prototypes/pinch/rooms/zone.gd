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
## `word` names a label from rooms.json drawn on the box (on a backing).
##
## The readability pass: each role has its own look, one helper each, so
## they are told apart without reading the word. A current is a faint fill
## with a row of small arrow triangles pointing along `velocity`, drifting
## that way at ARROW_SPEED px/s along the lane through the box's middle
## and wrapping (ARROW_MIN to ARROW_MAX of them, by the lane's length;
## _draw_current, _move_arrows). A wonder spot is a ring (a diamond of four
## thin rects) that pulses between 1 - PULSE and 1 + PULSE over
## PULSE_PERIOD seconds (_draw_ring), over a very faint fill marking the
## spot's extent. A soft wall is drawn like a soft box (box.gd's
## draw_soft: pale, dashed). A hazard is a dark fill hatched with thin
## diagonal rects (_draw_hazard). An exit keeps its plain fill. The goat
## draws itself (goat.gd).

const LAYER_DREAMER := 16
const BOX := preload("res://prototypes/pinch/rooms/box.gd")
const COLORS := {
	"current": Color(0.45, 0.55, 0.8, 0.18),
	"wonder": Color(0.55, 0.55, 0.72, 0.1),
	"exit": Color(0.75, 0.75, 0.6, 0.5),
	"hazard": Color(0.1, 0.1, 0.16, 0.9),
}
const ARROW_COLOR := Color(0.68, 0.78, 1.0, 0.7)
const ARROW_SPEED := 40.0     # px/s the arrows drift along the flow
const ARROW_MIN := 3
const ARROW_MAX := 5
const ARROW_EVERY := 150.0    # px of lane per arrow, between the min and the max
const ARROW_INSET := 10.0     # px the lane stays inside the box's edges
const ARROW_LENGTH := 7.0     # px from a triangle's middle to its point
const ARROW_BACK := 5.0       # px from its middle to its base
const ARROW_HALF := 5.0       # px: half its base
const RING_COLOR := Color(0.85, 0.85, 1.0, 0.9)
const RING_THICK := 2.0
const RING_INSET := 6.0       # px between the ring's corners and the box's nearer edge
const PULSE := 0.05           # the ring's scale swings 1 - PULSE .. 1 + PULSE
const PULSE_PERIOD := 2.0     # s per swing
const HATCH_COLOR := Color(0.38, 0.38, 0.5, 0.8)
const HATCH_EVERY := 14.0     # px between hatch lines, along the top edge
const HATCH_THICK := 2.0
const LABEL_WIDTH := 140.0
const ROOM_WIDTH := 1152.0    # room.gd SIZE.x: a word stays inside it

@export var size := Vector2(64, 64)
@export_enum("current", "wonder", "exit", "hazard") var role: String = "current"
@export var velocity := Vector2.ZERO   # current: px/s while the asleep body overlaps
@export var id := ""                   # wonder: consumed once per visit
@export_enum("soft_wall", "spot", "goat") var kind: String = "soft_wall"
@export var word := ""

var label: Label = null
var arrows: Node2D = null     # a current's arrow triangles
var ring: Node2D = null       # a spot's pulsing diamond
var _lane_dir := Vector2.RIGHT
var _lane_from := 0.0         # px along the lane from the middle where it enters the box
var _lane_to := 0.0           # ... and leaves it
var _arrow_at: Array[float] = []   # each arrow's px along the lane
var _time := 0.0


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
	_draw_role()
	if word != "":
		set_label(word)


func _process(delta: float) -> void:
	_time += delta
	if arrows != null:
		_move_arrows(delta)
	if ring != null:
		ring.scale = Vector2.ONE * ring_scale()


## What this zone adds to the velocity of the asleep body at `at`.
func carry(_at: Vector2) -> Vector2:
	return velocity


## The middle of the box, in the room.
func center() -> Vector2:
	return global_position + size / 2.0


## The word on the box, on a backing; made on the first call.
func set_label(text: String) -> void:
	if label == null:
		var at := _label_place()
		at.x = _label_x(at.x)
		label = PinchLabel.make(text, at, _label_width(), _label_align())
		label.name = "Word"
		add_child(label)
	PinchLabel.set_text(label, text)


func _label_width() -> float:
	return LABEL_WIDTH


## The word's x kept inside the room (a zone sits still, at room coordinates).
func _label_x(x: float) -> float:
	return clampf(x, 4.0 - position.x, ROOM_WIDTH - 4.0 - _label_width() - position.x)


## Where the word sits: a current's at its top-left corner (clear of the
## arrows' lane), a spot's along its bottom edge (under the ring), the rest
## in the middle.
func _label_place() -> Vector2:
	match role:
		"current":
			return Vector2(4, 4)
		"wonder":
			if kind == "spot":
				return Vector2(size.x / 2.0 - LABEL_WIDTH / 2.0, size.y - PinchLabel.LINE - 2.0)
	return Vector2(size.x / 2.0 - LABEL_WIDTH / 2.0, size.y / 2.0 - PinchLabel.LINE / 2.0)


func _label_align() -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_LEFT if role == "current" else HORIZONTAL_ALIGNMENT_CENTER


# --- the looks -----------------------------------------------------------------

func _draw_role() -> void:
	match role:
		"current":
			_fill(COLORS.current)
			_draw_current()
		"wonder":
			match kind:
				"spot":
					_fill(COLORS.wonder)
					_draw_ring()
				"soft_wall":
					BOX.draw_soft(self, size)
				_:
					pass   # the goat draws itself
		"hazard":
			_fill(COLORS.hazard)
			_draw_hazard()
		_:
			_fill(COLORS.get(role, Color.GRAY))


func _fill(color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.name = "Fill"
	box.size = size
	box.color = color
	add_child(box)
	return box


## A current's arrows: ARROW_MIN..ARROW_MAX triangles pointing along the
## velocity, spread evenly along the lane through the box's middle.
func _draw_current() -> void:
	_lane_dir = velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT
	var middle := size / 2.0
	var from := -INF
	var to := INF
	for axis in 2:
		if absf(_lane_dir[axis]) < 0.0001:
			continue
		var t1 := (0.0 - middle[axis]) / _lane_dir[axis]
		var t2 := (size[axis] - middle[axis]) / _lane_dir[axis]
		from = maxf(from, minf(t1, t2))
		to = minf(to, maxf(t1, t2))
	_lane_from = from + ARROW_INSET
	_lane_to = to - ARROW_INSET
	var span := lane_length()
	var n := clampi(int(span / ARROW_EVERY), ARROW_MIN, ARROW_MAX)
	arrows = Node2D.new()
	arrows.name = "Arrows"
	add_child(arrows)
	_arrow_at = []
	for i in n:
		var arrow := Polygon2D.new()
		arrow.name = "Arrow%d" % (i + 1)
		arrow.polygon = PackedVector2Array([Vector2(ARROW_LENGTH, 0), Vector2(-ARROW_BACK, -ARROW_HALF), Vector2(-ARROW_BACK, ARROW_HALF)])
		arrow.color = ARROW_COLOR
		arrow.rotation = _lane_dir.angle()
		arrows.add_child(arrow)
		_arrow_at.append(_lane_from + span * i / float(n))
	_place_arrows()


## The arrows drift along the flow at ARROW_SPEED and wrap at the lane's end.
func _move_arrows(delta: float) -> void:
	var span := lane_length()
	if span <= 0.0:
		return
	for i in _arrow_at.size():
		_arrow_at[i] += ARROW_SPEED * delta
		while _arrow_at[i] > _lane_to:
			_arrow_at[i] -= span
	_place_arrows()


func _place_arrows() -> void:
	var middle := size / 2.0
	for i in _arrow_at.size():
		arrows.get_child(i).position = middle + _lane_dir * _arrow_at[i]


## px of the arrows' lane inside the box.
func lane_length() -> float:
	return maxf(_lane_to - _lane_from, 0.0)


## The arrows' places in the box, in order (for the designer's eye and the tests).
func arrow_positions() -> Array[Vector2]:
	var at: Array[Vector2] = []
	if arrows != null:
		for arrow in arrows.get_children():
			at.append(arrow.position)
	return at


## A spot's ring: a diamond of four thin rects about the box's middle,
## pulsing (scale 1 - PULSE .. 1 + PULSE over PULSE_PERIOD seconds).
func _draw_ring() -> void:
	ring = Node2D.new()
	ring.name = "Ring"
	ring.position = size / 2.0
	var r := minf(size.x, size.y) / 2.0 - RING_INSET
	var side := r * sqrt(2.0)
	var corners := [Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]
	var turns := [45.0, 135.0, 225.0, 315.0]
	for i in 4:
		var edge := ColorRect.new()
		edge.name = "Edge%d" % (i + 1)
		edge.color = RING_COLOR
		edge.size = Vector2(side, RING_THICK)
		edge.position = corners[i]
		edge.rotation = deg_to_rad(turns[i])
		ring.add_child(edge)
	add_child(ring)


## The ring's scale now: 1 - PULSE .. 1 + PULSE, once round every PULSE_PERIOD seconds.
func ring_scale() -> float:
	return 1.0 + PULSE * sin(TAU * _time / PULSE_PERIOD)


## A hazard's hatching: thin rects at 45 degrees, HATCH_EVERY apart, each
## cut to the box (down-right from the top edge, then from the left edge).
func _draw_hazard() -> void:
	var hatch := Node2D.new()
	hatch.name = "Hatch"
	var lines := 0
	var x := 0.0
	while x < size.x:
		_hatch_line(hatch, Vector2(x, 0), minf(size.y, size.x - x))
		lines += 1
		x += HATCH_EVERY
	var y := HATCH_EVERY
	while y < size.y:
		_hatch_line(hatch, Vector2(0, y), minf(size.y - y, size.x))
		lines += 1
		y += HATCH_EVERY
	hatch.set_meta("lines", lines)
	add_child(hatch)


## One hatch line from `from` down-right, `reach` px across and down.
func _hatch_line(holder: Node, from: Vector2, reach: float) -> void:
	var line := ColorRect.new()
	line.color = HATCH_COLOR
	line.size = Vector2(HATCH_THICK, reach * sqrt(2.0))
	line.position = from
	line.rotation = deg_to_rad(-45.0)
	holder.add_child(line)
