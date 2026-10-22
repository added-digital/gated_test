extends Node2D
## The street of Yawn by day (toy 4, PINCH): a side view four screens wide on
## one ground line. Three buildings stand (the Long House with the bunk, the
## table and the tally wall; Jorun's hut; the stove shed) and three plots
## wait (Sixteen Stairs, Bo's loft, a lantern post). Two black rects mask
## the street beyond the lit tiles at each end; they recede one tile per
## building standing, read from the state. E at the bunk emits slept. The
## ideas kept (state.ideas_kept) lie on the Long House table as small
## labelled rects until breakfast takes them (day 4); the ideas lost at a
## sudden waking float over the bunk and fade over LOST_FADE seconds
## (fade_lost, called by the controller). Every word on screen comes from
## data/village.json, idea names from data/ideas.json; rewrite those, not
## this.

signal slept

const WORDS_FILE := "res://prototypes/pinch/data/village.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const LOST_FADE := 6.0           # s the lost stack takes to fade over the bunk
const PIECE := Vector2(32, 24)   # px: one idea as a rect, on the table or over the bunk
const STREET_WIDTH := 4608.0   # px: four screens of 1152
const STREET_HEIGHT := 648.0   # px: one screen; the camera never scrolls up or down
const GROUND_Y := 540.0        # px: the ground line
const BUNK_RANGE := 48.0       # px: this close to the bunk's middle, E sleeps
const WALL := Color(0.5, 0.5, 0.5)
const MARKER := Color(0.72, 0.72, 0.72)
const OUTLINE := Color(0.42, 0.42, 0.42)

# The street, left to right: [kind, id, x, width, height]; buildings stand, plots wait.
const LAYOUT := [
	["plot", "sixteen_stairs", 1560.0, 200.0, 160.0],
	["building", "jorun_hut", 1800.0, 240.0, 180.0],
	["building", "long_house", 2074.0, 460.0, 260.0],   # its middle is the street's middle, 2304
	["building", "stove_shed", 2580.0, 160.0, 140.0],
	["plot", "bos_loft", 2800.0, 200.0, 200.0],
	["plot", "lantern_post", 3030.0, 30.0, 220.0],
]
const TABLE := Rect2(2130, 490, 90, 50)   # inside the Long House, left
const BUNK := Rect2(2400, 500, 70, 40)    # inside the Long House, right

@onready var walker: CharacterBody2D = $Walker
@onready var prompt_label: Label = $Walker/Prompt
@onready var day_label: Label = $Hud/DayLabel
@onready var mask_left: ColorRect = $Mask/Left
@onready var mask_right: ColorRect = $Mask/Right
@onready var street: Node2D = $Street

var state: PinchState         # set by the controller before add_child; a fresh one when run alone
var words: Dictionary = {}    # village.json
var ideas: Array = []         # ideas.json, for the names
var tally_wall: Label = null  # the marks on the Long House wall, one per sudden waking
var table_ideas: Node2D = null   # the kept ideas on the table, one labelled rect each
var lost_stack: Node2D = null    # the ideas lost at waking, fading over the bunk; null when none
var _slept := false
var _lost_left := 0.0


func _ready() -> void:
	if state == null:
		state = PinchState.new()
	var loaded: Variant = PinchState.load_json(WORDS_FILE)
	words = loaded if loaded is Dictionary else {}
	loaded = PinchState.load_json(IDEAS_FILE)
	ideas = loaded if loaded is Array else []
	_build_street()
	prompt_label.text = words.get("sleep_prompt", "")
	prompt_label.visible = false
	refresh()


func _process(delta: float) -> void:
	prompt_label.visible = bunk_in_range() and not _slept
	if lost_stack != null:
		_lost_left -= delta
		if _lost_left <= 0.0:
			street.remove_child(lost_stack)
			lost_stack.queue_free()
			lost_stack = null
		else:
			lost_stack.modulate.a = _lost_left / LOST_FADE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and bunk_in_range():
		go_to_sleep()


## Re-reads the state: the day label, the tally wall, the ideas on the
## table, the dark at each end.
func refresh() -> void:
	day_label.text = str(words.get("day_label", "{day}")).format({"day": state.day})
	tally_wall.text = str(words.get("tally_mark", "|")).repeat(state.tally)
	for piece in table_ideas.get_children():
		table_ideas.remove_child(piece)
		piece.queue_free()
	for i in state.ideas_kept.size():
		_add_piece(table_ideas, state.ideas_kept[i], Vector2(TABLE.position.x + 8 + i * (PIECE.x + 6), TABLE.position.y - PIECE.y), i)
	var lit := lit_extent()
	mask_left.position = Vector2.ZERO
	mask_left.size = Vector2(STREET_WIDTH / 2.0 - lit, STREET_HEIGHT)
	mask_right.position = Vector2(STREET_WIDTH / 2.0 + lit, 0)
	mask_right.size = Vector2(STREET_WIDTH / 2.0 - lit, STREET_HEIGHT)


func lit_tiles() -> int:
	return state.lit_tiles()


## px lit on each side of the street's middle (the Long House).
func lit_extent() -> float:
	return lit_tiles() * PinchState.TILE


## px of street under the dark at each end.
func mask_extent() -> float:
	return STREET_WIDTH / 2.0 - lit_extent()


func bunk_in_range() -> bool:
	return absf(walker.position.x - BUNK.get_center().x) <= BUNK_RANGE


## The name of an idea, from ideas.json.
func idea_name(id: String) -> String:
	for idea in ideas:
		if str(idea.get("id", "")) == id:
			return str(idea.get("name", id))
	return id


## The ideas kept, as drawn on the table, in order.
func table_idea_ids() -> Array[String]:
	var ids: Array[String] = []
	for piece in table_ideas.get_children():
		ids.append(str(piece.get_meta("id")))
	return ids


## The ideas lost at a sudden waking: a stack over the bunk, one rect per
## idea, fading away over LOST_FADE seconds.
func fade_lost(ids: Array) -> void:
	if lost_stack != null:
		street.remove_child(lost_stack)
		lost_stack.queue_free()
	lost_stack = Node2D.new()
	lost_stack.name = "Lost"
	var x := BUNK.get_center().x - PIECE.x / 2.0
	for i in ids.size():
		_add_piece(lost_stack, str(ids[i]), Vector2(x, BUNK.position.y - 40.0 - (i + 1) * (PIECE.y + 2.0)), i)
	street.add_child(lost_stack)
	_lost_left = LOST_FADE


## How far the lost stack has faded: 1 just woken, 0 gone.
func lost_alpha() -> float:
	return lost_stack.modulate.a if lost_stack != null else 0.0


## Lie down: emits slept once; the controller takes it from there.
func go_to_sleep() -> void:
	if _slept:
		return
	_slept = true
	slept.emit()


func _build_street() -> void:
	var buildings: Dictionary = words.get("buildings", {})
	var plots: Dictionary = words.get("plots", {})
	var markers: Dictionary = words.get("markers", {})
	for entry in LAYOUT:
		var rect := Rect2(entry[2], GROUND_Y - entry[4], entry[3], entry[4])
		if entry[0] == "building":
			_add_box(rect, WALL)
			_add_label(str(buildings.get(entry[1], entry[1])), Vector2(rect.position.x, rect.position.y - 26), rect.size.x)
		else:
			_add_outline(rect, OUTLINE)
			_add_label(str(plots.get(entry[1], entry[1])), Vector2(rect.position.x - 60, rect.position.y - 26), rect.size.x + 120)
	_add_box(TABLE, MARKER)
	_add_label(str(markers.get("table", "")), Vector2(TABLE.position.x, TABLE.position.y - 22), TABLE.size.x)
	_add_box(BUNK, MARKER)
	_add_label(str(markers.get("bunk", "")), Vector2(BUNK.position.x, BUNK.position.y - 22), BUNK.size.x)
	_add_label(str(words.get("tally_title", "")), Vector2(TABLE.position.x, TABLE.position.y - 150), 200.0, HORIZONTAL_ALIGNMENT_LEFT)
	tally_wall = _add_label("", Vector2(TABLE.position.x, TABLE.position.y - 126), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	table_ideas = Node2D.new()
	table_ideas.name = "TableIdeas"
	street.add_child(table_ideas)


## One idea as a white rect with a black edge and its name above (the
## dream's look, small), under `holder`.
func _add_piece(holder: Node2D, id: String, at: Vector2, index: int) -> void:
	var piece := Node2D.new()
	piece.name = "Idea_%s" % id
	piece.position = at
	piece.set_meta("id", id)
	var edge := ColorRect.new()
	edge.position = Vector2(-2, -2)
	edge.size = PIECE + Vector2(4, 4)
	edge.color = Color.BLACK
	piece.add_child(edge)
	var face := ColorRect.new()
	face.size = PIECE
	face.color = Color.WHITE
	piece.add_child(face)
	var label := Label.new()
	label.text = idea_name(id)
	label.position = Vector2(PIECE.x / 2.0 - 100, -24 - (index % 2) * 18)
	label.size = Vector2(200, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piece.add_child(label)
	holder.add_child(piece)


func _add_box(rect: Rect2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	street.add_child(box)
	return box


## An empty plot: four thin rects around the outline.
func _add_outline(rect: Rect2, color: Color) -> void:
	var t := 3.0
	_add_box(Rect2(rect.position, Vector2(rect.size.x, t)), color)
	_add_box(Rect2(rect.position + Vector2(0, rect.size.y - t), Vector2(rect.size.x, t)), color)
	_add_box(Rect2(rect.position, Vector2(t, rect.size.y)), color)
	_add_box(Rect2(rect.position + Vector2(rect.size.x - t, 0), Vector2(t, rect.size.y)), color)


func _add_label(text: String, at: Vector2, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 22)
	label.horizontal_alignment = align
	street.add_child(label)
	return label
