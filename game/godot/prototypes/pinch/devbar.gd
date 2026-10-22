extends CanvasLayer
## The dev bar of toy 4, PINCH (the readability pass; the designer asked
## for "a dev bar with what I can do"): a thin strip along the bottom of
## the screen on its own layer above the frame, so it can be read however
## far the frame has shut. Its left half lists ONLY the actions that are
## available right now; the owner (the dream or the village) computes that
## text every frame (devbar_text()) from its state and hands it to
## set_actions(). Its right half shows the room's one-line hint for
## HINT_STAYS seconds after a room is entered (show_hint()), then fades it
## over HINT_FADE; the far right names the key that hides the bar. Every
## word comes from data/devbar.json (the owner reads it and hands the
## toggle word in) and data/rooms.json (the hints); nothing here holds
## words. Tab toggles the bar (the owner: state.devbar_visible, kept for
## the session). Headless, the labels exist and are read by the tests.

const LAYER := 7                 # above the frame (5) and the gauge (6), below the text panel (10)
const HEIGHT := 40.0             # px: the strip, along the bottom edge
const FONT := 12
const GUTTER := 12.0             # px from the screen's edges
const SPLIT := 0.5               # the actions take this share of the width; the hint the rest
const TOGGLE_WIDTH := 96.0       # px, far right, for the toggle word
const HINT_STAYS := 4.0          # s the room's hint stays fully shown after entering
const HINT_FADE := 1.0           # s it then takes to fade out
const BACK := Color(0, 0, 0, 0.78)
const TEXT := Color(0.93, 0.93, 0.93)
const HINT_TEXT := Color(0.8, 0.82, 0.9)
const TOGGLE_TEXT := Color(0.55, 0.55, 0.6)

var strip: ColorRect = null
var actions_label: Label = null
var hint_label: Label = null
var toggle_label: Label = null
var _hint_left := 0.0            # s of the hint's full show and fade left; 0: hidden


func _ready() -> void:
	layer = LAYER
	var screen := Vector2(1152, 648)
	if is_inside_tree():
		screen = get_viewport().get_visible_rect().size
	strip = ColorRect.new()
	strip.name = "Strip"
	strip.color = BACK
	strip.position = Vector2(0, screen.y - HEIGHT)
	strip.size = Vector2(screen.x, HEIGHT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var actions_width := screen.x * SPLIT - GUTTER
	actions_label = _label("Actions", Vector2(GUTTER, 0), actions_width, TEXT)
	var hint_width := screen.x - actions_width - GUTTER * 2.0 - TOGGLE_WIDTH - GUTTER
	hint_label = _label("Hint", Vector2(GUTTER + actions_width + GUTTER, 0), hint_width, HINT_TEXT)
	hint_label.visible = false
	toggle_label = _label("Toggle", Vector2(screen.x - GUTTER - TOGGLE_WIDTH, 0), TOGGLE_WIDTH, TOGGLE_TEXT)
	toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _process(delta: float) -> void:
	if _hint_left <= 0.0:
		return
	_hint_left = maxf(_hint_left - delta, 0.0)
	hint_label.modulate.a = hint_alpha()
	hint_label.visible = _hint_left > 0.0


## The actions available now, as one line (the owner's devbar_text()).
func set_actions(text: String) -> void:
	actions_label.text = text


## The room's hint: shown in full for HINT_STAYS seconds, then faded out.
func show_hint(text: String) -> void:
	hint_label.text = text
	_hint_left = (HINT_STAYS + HINT_FADE) if text != "" else 0.0
	hint_label.modulate.a = 1.0
	hint_label.visible = text != ""


## The word for the key that hides the bar (from devbar.json).
func set_toggle_word(text: String) -> void:
	toggle_label.text = text


## 1 while the hint is fully shown, falling to 0 over HINT_FADE, 0 when gone.
func hint_alpha() -> float:
	if _hint_left <= 0.0:
		return 0.0
	return clampf(_hint_left / HINT_FADE, 0.0, 1.0)


## Seconds the hint has left, full show and fade together.
func hint_left() -> float:
	return _hint_left


func actions_text() -> String:
	return actions_label.text


func hint_text() -> String:
	return hint_label.text


## A wrapped label inside the strip, vertically centred, at most two lines.
func _label(label_name: String, at: Vector2, width: float, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, HEIGHT)
	label.position = at
	label.size = Vector2(width, HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.set_meta("max_width", width)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(label)
	return label
