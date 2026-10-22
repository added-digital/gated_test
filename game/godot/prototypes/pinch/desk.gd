extends Node2D
## The Desk (toy 4b, PINCH, SPEC-2 day B, "The Desk, exactly"): the Long
## House table by day, a timed hands-on burst. The village builds one each
## morning there is something to work on (an idea reached last night, or
## at least MIN_CARDS scraps) and draws it at the table (`position` is the
## table's top-left corner); the village reads the keys and the clock and
## ends it. Here: the OUTLINE, the idea's slots (branches.json "slots",
## three to five shapes: round, square, long; or scraps.json's blank
## outline of "any" slots when no idea came up) drawn as a row of empty
## shaped holes; the CARDS, the scraps brought home, as a row of shaped
## cards beside it, numbered; the HAND, a bracket under the slot it is
## on; the LIGHT, the Long House window to the left of the table whose
## fill drains with the clock (BLUE_HOUR seconds; light_height()). pick_card
## picks a card (1 2 3, 4 5 6), move moves the hand along the slots, fit
## fits the picked card into the slot under the hand: a matching shape
## (or an "any" slot) fills the slot and uses the card up; a wrong shape
## costs FUMBLE seconds (the clock jumps, the walker shakes for
## SHAKE_FRAMES: shaking()) and the card stays. tick(delta) runs the
## clock; light_gone(), complete() and filled_count() say how far it got.
## Grey boxes and backed labels; every word from data/village.json "desk",
## the idea's name from data/ideas.json, handed in by the village.

const BLUE_HOUR := 75.0        # s the light lasts
const FUMBLE := 5.0            # s a wrong shape costs
const MIN_CARDS := 3           # scraps alone that are worth a Desk (the blank outline's three)
const SHAKE_FRAMES := 10       # frames the walker shakes after a fumble
const SHAKE_PX := 4.0          # px either way
const ROW_Y := -104.0          # px above the table's top: the slots' and cards' top
const SLOT := Vector2(32, 40)  # px: one slot of the outline
const SLOT_GAP := 6.0
const CARD := Vector2(26, 40)  # px: one card
const CARD_GAP := 6.0
const CARDS_AFTER := 16.0      # px between the outline's end and the first card
const PICKED_RAISE := 6.0      # px a picked card is raised
const HAND_Y := -62.0          # px above the table's top: the hand's bracket
const HAND_THICK := 3.0
const NAME_Y := -56.0          # px above the table's top: the outline's name (the idea's)
const NAME_WIDTH := 220.0
const WINDOW_AT := Vector2(-44, -150)   # the Long House window, left of the table
const WINDOW := Vector2(28, 70)
const WINDOW_LABEL_WIDTH := 64.0
const FONT := 11
const NUMBER_FONT := 10
const HOLE_BACK := Color(0.3, 0.3, 0.34)
const HOLE := Color(0.12, 0.12, 0.15)
const CARD_FACE := Color.WHITE
const CARD_EDGE := Color.BLACK
const MARK := Color(0.2, 0.2, 0.26)
const HAND := Color(1.0, 0.9, 0.45)
const WINDOW_FRAME := Color(0.22, 0.22, 0.26)
const LIGHT := Color(1.0, 0.92, 0.6)
const ROUND_POINTS := 16

var idea := ""                       # the idea on the desk; "" for scraps alone (the blank outline)
var outline_name := ""               # the idea's name, or the blank outline's
var slots: Array[String] = []        # the outline's shapes, in order ("any" takes every shape)
var filled: Array[String] = []       # per slot: the shape fitted, or ""
var cards: Array[String] = []        # the scraps on the desk, in order (used-up ones are gone)
var hand := 0                        # the slot the hand is on
var card := -1                       # the card picked; -1 none
var time := 0.0                      # s since the Desk began, the fumbles counted
var fits := 0
var fumbles := 0
var words: Dictionary = {}           # village.json "desk"
var shape_names := {}                # shape id -> name (scraps.json)
var outline_node: Node2D = null
var cards_node: Node2D = null
var hand_node: ColorRect = null
var name_label: Label = null
var window_node: ColorRect = null
var light_node: ColorRect = null
var light_label: Label = null
var _shake_left := 0


## Before add_child: what lies on the desk and the words it is drawn with.
func setup(idea_id: String, shown_name: String, slot_shapes: Array, card_shapes: Array, desk_words: Dictionary, names: Dictionary) -> void:
	idea = idea_id
	outline_name = shown_name
	slots.assign(slot_shapes)
	filled.assign([])
	for i in slots.size():
		filled.append("")
	cards.assign(card_shapes)
	words = desk_words
	shape_names = names
	hand = 0
	card = -1
	time = 0.0


func _ready() -> void:
	window_node = _rect(self, Rect2(WINDOW_AT, WINDOW), WINDOW_FRAME)
	window_node.name = "Window"
	light_node = _rect(self, Rect2(WINDOW_AT, WINDOW), LIGHT)
	light_node.name = "Light"
	light_label = PinchLabel.make(word("light"), Vector2(WINDOW_AT.x + WINDOW.x / 2.0 - WINDOW_LABEL_WIDTH / 2.0, WINDOW_AT.y + WINDOW.y + 2.0), WINDOW_LABEL_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, NUMBER_FONT)
	light_label.name = "LightLabel"
	add_child(light_label)
	outline_node = Node2D.new()
	outline_node.name = "Outline"
	add_child(outline_node)
	cards_node = Node2D.new()
	cards_node.name = "Cards"
	cards_node.position = Vector2(outline_width() + CARDS_AFTER, 0.0)
	add_child(cards_node)
	hand_node = _rect(self, Rect2(Vector2(0, HAND_Y), Vector2(SLOT.x, HAND_THICK)), HAND)
	hand_node.name = "Hand"
	name_label = PinchLabel.make(outline_name, Vector2(0, NAME_Y), NAME_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
	name_label.name = "Name"
	add_child(name_label)
	_redraw()
	_draw_light()


func _process(_delta: float) -> void:
	if _shake_left > 0:
		_shake_left -= 1


## A word from village.json "desk"; the key itself when the file lacks it.
func word(key: String) -> String:
	return str(words.get(key, key))


## The clock runs; the light drains with it.
func tick(delta: float) -> void:
	time += delta
	_draw_light()


# --- the acts ------------------------------------------------------------------

## 1 2 3 (4 5 6): the `index`-th card is in the hand; false past the cards there are.
func pick_card(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	card = index
	_redraw()
	return true


## A D: the hand one slot along; false at the outline's ends.
func move(direction: int) -> bool:
	var to := clampi(hand + signi(direction), 0, slots.size() - 1)
	if to == hand:
		return false
	hand = to
	_redraw()
	return true


## E: the picked card into the slot under the hand. "fit" (the slot is
## filled, the card used up), "fumble" (a wrong shape: FUMBLE seconds
## gone, the card stays), or "" (no card picked, or the slot is full).
func fit() -> String:
	if card < 0 or card >= cards.size() or hand < 0 or hand >= slots.size() or filled[hand] != "":
		return ""
	var shape: String = cards[card]
	if slots[hand] == "any" or slots[hand] == shape:
		filled[hand] = shape
		cards.remove_at(card)
		card = -1
		fits += 1
		_redraw()
		return "fit"
	time += FUMBLE
	fumbles += 1
	_shake_left = SHAKE_FRAMES
	_draw_light()
	return "fumble"


# --- readers ---------------------------------------------------------------------

func filled_count() -> int:
	var n := 0
	for shape in filled:
		if shape != "":
			n += 1
	return n


## Every slot filled.
func complete() -> bool:
	return filled_count() == slots.size()


## The light has drained: the blue hour is over.
func light_gone() -> bool:
	return time >= BLUE_HOUR


func time_left() -> float:
	return maxf(BLUE_HOUR - time, 0.0)


## px of the window still lit: WINDOW.y at the start, 0 when the light is gone.
func light_height() -> float:
	return WINDOW.y * clampf(1.0 - time / BLUE_HOUR, 0.0, 1.0)


## The cards still on the desk (the leftovers), in order.
func cards_left() -> Array[String]:
	return cards.duplicate()


## The shape of the picked card, "" with none.
func picked_shape() -> String:
	return cards[card] if card >= 0 and card < cards.size() else ""


## The picked card's name, from scraps.json; "" with none.
func picked_name() -> String:
	var shape := picked_shape()
	return str(shape_names.get(shape, shape)) if shape != "" else ""


## True for SHAKE_FRAMES frames after a fumble.
func shaking() -> bool:
	return _shake_left > 0


## px the walker is drawn aside by the shake now: left and right by turns, 0 when still.
func shake_offset() -> float:
	if _shake_left <= 0:
		return 0.0
	return SHAKE_PX * (1.0 if _shake_left % 2 == 0 else -1.0)


## px wide the outline's row is.
func outline_width() -> float:
	return slots.size() * SLOT.x + maxi(slots.size() - 1, 0) * SLOT_GAP


## The slot nodes, in order (each with the metadata `shape` and `filled`).
func slot_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for child in outline_node.get_children():
		nodes.append(child)
	return nodes


## The card nodes, in order (each with the metadata `shape` and `index`).
func card_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for child in cards_node.get_children():
		nodes.append(child)
	return nodes


## The Desk's extent on the street, from the window's left to the last card's right.
func rect() -> Rect2:
	var right := outline_width() + CARDS_AFTER + cards.size() * (CARD.x + CARD_GAP)
	return Rect2(position + Vector2(WINDOW_AT.x, WINDOW_AT.y), Vector2(right - WINDOW_AT.x, -WINDOW_AT.y))


# --- drawing -------------------------------------------------------------------

func _redraw() -> void:
	for child in outline_node.get_children():
		outline_node.remove_child(child)
		child.queue_free()
	for child in cards_node.get_children():
		cards_node.remove_child(child)
		child.queue_free()
	for i in slots.size():
		var slot := Node2D.new()
		slot.name = "Slot%d" % (i + 1)
		slot.position = Vector2(i * (SLOT.x + SLOT_GAP), ROW_Y)
		slot.set_meta("shape", slots[i])
		slot.set_meta("filled", filled[i])
		if filled[i] == "":
			_rect(slot, Rect2(Vector2.ZERO, SLOT), HOLE_BACK)
			_mark(slot, slots[i], SLOT / 2.0, HOLE)
		else:
			_rect(slot, Rect2(Vector2(-2, -2), SLOT + Vector2(4, 4)), CARD_EDGE)
			_rect(slot, Rect2(Vector2.ZERO, SLOT), CARD_FACE)
			_mark(slot, filled[i], SLOT / 2.0, MARK)
		outline_node.add_child(slot)
	for i in cards.size():
		var node := Node2D.new()
		node.name = "Card%d" % (i + 1)
		node.position = Vector2(i * (CARD.x + CARD_GAP), ROW_Y - (PICKED_RAISE if i == card else 0.0))
		node.set_meta("shape", cards[i])
		node.set_meta("index", i)
		_rect(node, Rect2(Vector2(-2, -2), CARD + Vector2(4, 4)), HAND if i == card else CARD_EDGE)
		_rect(node, Rect2(Vector2.ZERO, CARD), CARD_FACE)
		var number := Label.new()
		number.name = "Number"
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", NUMBER_FONT)
		number.add_theme_color_override("font_color", MARK)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.position = Vector2(0, 1)
		number.size = Vector2(CARD.x, 12)
		number.set_meta("max_width", CARD.x)
		node.add_child(number)
		_mark(node, cards[i], Vector2(CARD.x / 2.0, CARD.y * 0.62), MARK)
		cards_node.add_child(node)
	if hand_node != null:
		hand_node.position.x = hand * (SLOT.x + SLOT_GAP)
		hand_node.visible = not slots.is_empty()


func _draw_light() -> void:
	if light_node == null:
		return
	var h := light_height()
	light_node.position = Vector2(WINDOW_AT.x, WINDOW_AT.y + WINDOW.y - h)
	light_node.size = Vector2(WINDOW.x, h)
	light_node.visible = h > 0.0


## A shape (round, square, long; nothing for "any") drawn about `middle` under `holder`, named Mark.
func _mark(holder: Node, shape: String, middle: Vector2, color: Color) -> void:
	match shape:
		"round":
			var circle := Polygon2D.new()
			circle.name = "Mark"
			circle.color = color
			var points := PackedVector2Array()
			for i in ROUND_POINTS:
				var a := TAU * i / ROUND_POINTS
				points.append(middle + Vector2(cos(a), sin(a)) * 8.0)
			circle.polygon = points
			holder.add_child(circle)
		"square":
			_rect(holder, Rect2(middle - Vector2(8, 8), Vector2(16, 16)), color).name = "Mark"
		"long":
			_rect(holder, Rect2(middle - Vector2(11, 3), Vector2(22, 6)), color).name = "Mark"
		_:
			pass


func _rect(holder: Node, rect: Rect2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	holder.add_child(box)
	return box
