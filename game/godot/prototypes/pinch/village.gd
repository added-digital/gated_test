extends Node2D
## The street of Yawn by day (toy 4, PINCH): a side view four screens wide on
## one ground line. Three buildings stand (the Long House with the bunk, the
## table and the tally wall; Jorun's hut; the stove shed) and three plots
## wait (Sixteen Stairs, Bo's loft, a lantern post). Two black rects mask
## the street beyond the lit tiles at each end; they recede one tile per
## building standing, read from the state. E at the bunk emits slept. Every
## word on screen comes from data/village.json; rewrite that, not this.

signal slept

const WORDS_FILE := "res://prototypes/pinch/data/village.json"
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
var tally_wall: Label = null  # the marks on the Long House wall, one per sudden waking
var _slept := false


func _ready() -> void:
	if state == null:
		state = PinchState.new()
	var loaded: Variant = PinchState.load_json(WORDS_FILE)
	words = loaded if loaded is Dictionary else {}
	_build_street()
	prompt_label.text = words.get("sleep_prompt", "")
	prompt_label.visible = false
	refresh()


func _process(_delta: float) -> void:
	prompt_label.visible = bunk_in_range() and not _slept


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and bunk_in_range():
		go_to_sleep()


## Re-reads the state: the day label, the tally wall, the dark at each end.
func refresh() -> void:
	day_label.text = str(words.get("day_label", "{day}")).format({"day": state.day})
	tally_wall.text = str(words.get("tally_mark", "|")).repeat(state.tally)
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
