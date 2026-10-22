extends Node2D
## The Desk (toy 4b, PINCH, SPEC-2 "The Desk, exactly"; day B, day C): the
## Long House table by day, a timed hands-on burst. The village builds one
## each morning there is something to work on (an outline waiting on the
## desk, or at least MIN_CARDS scraps) and draws it at the table
## (`position` is the table's top-left corner); the village reads the keys
## and the clock and ends it. Here: the OUTLINE, the idea's slots
## (branches.json "slots", three to five shapes: round, square, long; or
## scraps.json's blank outline of "any" slots when no idea waits) drawn as
## a row of shaped holes, the ones filled on an earlier morning already
## filled (setup's `filled_before`: day C, an outline stays on the desk
## until it is complete); the CARDS, the scraps brought home, as a row of
## shaped cards beside it, numbered; the HAND, a bracket under the slot it
## is on; the LIGHT, the Long House window to the left of the table whose
## fill drains with the clock (BLUE_HOUR seconds; light_height()).
## pick_card picks a card (1 2 3, 4 5 6), move moves the hand along the
## slots, fit fits the picked card into the slot under the hand: a
## matching shape (or an "any" slot) fills the slot and uses the card up;
## a wrong shape costs FUMBLE seconds (the clock jumps, the walker shakes
## for SHAKE_FRAMES: shaking()) and the card stays. tick(delta) runs the
## clock; light_gone(), complete() and filled_count() say how far it got.
##
## THE FEEL (day C), drawn only, every number a constant below: a fitted
## card SLIDES from its place into its slot over SLIDE seconds (sliding(),
## slide_share(), slide_position(); the slot is drawn empty until it
## lands) and the slot FLASHES once as it lands (slot_flash_alpha(i), over
## SLOT_FLASH seconds); the window's light drains SMOOTHLY: the drawn
## height (shown_light_height()) eases to the clock's over LIGHT_EASE
## seconds when the clock jumps at a fumble; when the last slot fills
## (show_developed, called by the village) the outline flashes
## DEVELOPED_FLASHES times over DEVELOPED_SHOWS seconds with the developed
## thing's name over it (developed_name()), and the village takes the desk
## away after (developing()). Grey boxes and backed labels; every word
## from data/village.json "desk", the idea's name from data/ideas.json,
## handed in by the village.

const BLUE_HOUR := 75.0        # s the light lasts
const FUMBLE := 5.0            # s a wrong shape costs
const MIN_CARDS := 3           # scraps alone that are worth a Desk (the blank outline's three)
const SHAKE_FRAMES := 10       # frames the walker shakes after a fumble
const SHAKE_PX := 4.0          # px either way
const SLIDE := 0.25            # s a fitted card takes to slide into its slot
const SLOT_FLASH := 0.3        # s a slot's flash lasts as the card lands
const LIGHT_EASE := 0.5        # s the drawn light takes to settle after the clock jumps (a fumble)
const DEVELOPED_SHOWS := 1.5   # s the outline flashes and the developed thing's name shows once the last slot fills
const DEVELOPED_FLASHES := 3   # flashes in that time
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
const DEVELOPED_Y := -140.0    # px above the table's top: the developed thing's name, over the outline
const DEVELOPED_FONT := 14
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
const FLASH := Color(1.0, 0.96, 0.7)   # a slot, or the whole outline, flashes this
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
var feel_node: Node2D = null         # the sliding card lives here, over the rows
var hand_node: ColorRect = null
var name_label: Label = null
var developed_label: Label = null
var window_node: ColorRect = null
var light_node: ColorRect = null
var light_label: Label = null
var _shake_left := 0
var _slide := {}                     # the card sliding now: slot, from, to, t, node; {} when none
var _slot_flash := {}                # slot index -> s of its flash left
var _light_from := 0.0               # px the light was drawn at when the clock last jumped
var _light_t := LIGHT_EASE           # s since that jump; LIGHT_EASE and past: the clock's own height
var _developed_left := 0.0           # s the developed show has left; 0 when not showing
var _developed_pending := ""         # the name to show once the last card has landed


## Before add_child: what lies on the desk and the words it is drawn with;
## `filled_before` is the outline as an earlier morning left it (day C).
func setup(idea_id: String, shown_name: String, slot_shapes: Array, card_shapes: Array, desk_words: Dictionary, names: Dictionary, filled_before: Array = []) -> void:
	idea = idea_id
	outline_name = shown_name
	slots.assign(slot_shapes)
	filled.assign([])
	for i in slots.size():
		filled.append(str(filled_before[i]) if i < filled_before.size() else "")
	cards.assign(card_shapes)
	words = desk_words
	shape_names = names
	hand = first_empty_slot()
	card = -1
	time = 0.0
	_light_from = WINDOW.y
	_light_t = LIGHT_EASE


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
	feel_node = Node2D.new()
	feel_node.name = "Feel"
	add_child(feel_node)
	hand_node = _rect(self, Rect2(Vector2(0, HAND_Y), Vector2(SLOT.x, HAND_THICK)), HAND)
	hand_node.name = "Hand"
	name_label = PinchLabel.make(outline_name, Vector2(0, NAME_Y), NAME_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
	name_label.name = "Name"
	add_child(name_label)
	developed_label = PinchLabel.make("", Vector2(outline_width() / 2.0 - NAME_WIDTH / 2.0, DEVELOPED_Y), NAME_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, DEVELOPED_FONT)
	developed_label.name = "Developed"
	developed_label.visible = false
	add_child(developed_label)
	_redraw()
	_draw_light()


func _process(delta: float) -> void:
	if _shake_left > 0:
		_shake_left -= 1
	if not _slide.is_empty():
		_slide.t = minf(float(_slide.t) + delta, SLIDE)
		(_slide.node as Node2D).position = (_slide.from as Vector2).lerp(_slide.to, slide_share())
		if float(_slide.t) >= SLIDE:
			_land_slide()
	for i in _slot_flash.keys():
		_slot_flash[i] = float(_slot_flash[i]) - delta
		if float(_slot_flash[i]) <= 0.0:
			_slot_flash.erase(i)
		_draw_flash(i)
	if _developed_left > 0.0:
		_developed_left = maxf(_developed_left - delta, 0.0)
		for i in slots.size():
			_draw_flash(i)
		if _developed_left <= 0.0:
			developed_label.visible = false


## A word from village.json "desk"; the key itself when the file lacks it.
func word(key: String) -> String:
	return str(words.get(key, key))


## The clock runs; the light drains with it.
func tick(delta: float) -> void:
	time += delta
	_light_t += delta
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
## filled, the card used up and sliding into it), "fumble" (a wrong
## shape: FUMBLE seconds gone, the card stays), or "" (no card picked, or
## the slot is full).
func fit() -> String:
	if card < 0 or card >= cards.size() or hand < 0 or hand >= slots.size() or filled[hand] != "":
		return ""
	var shape: String = cards[card]
	if slots[hand] == "any" or slots[hand] == shape:
		var from := cards_node.position + Vector2(card * (CARD.x + CARD_GAP), ROW_Y - PICKED_RAISE)
		filled[hand] = shape
		cards.remove_at(card)
		card = -1
		fits += 1
		_start_slide(hand, shape, from)
		_redraw()
		return "fit"
	_light_from = shown_light_height()   # the drawn light eases down from here to the clock's new height
	_light_t = 0.0
	time += FUMBLE
	fumbles += 1
	_shake_left = SHAKE_FRAMES
	_draw_light()
	return "fumble"


## The last slot is filled (the village says so): the outline flashes and
## the developed thing's name shows over it for DEVELOPED_SHOWS seconds,
## once the last card has landed.
func show_developed(shown_name: String) -> void:
	_developed_pending = shown_name
	if _slide.is_empty():
		_begin_developed()


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


## The first empty slot's index (0 when every slot is filled).
func first_empty_slot() -> int:
	for i in filled.size():
		if filled[i] == "":
			return i
	return 0


## The light has drained: the blue hour is over.
func light_gone() -> bool:
	return time >= BLUE_HOUR


func time_left() -> float:
	return maxf(BLUE_HOUR - time, 0.0)


## px of the window lit by the clock: WINDOW.y at the start, 0 when the light is gone.
func light_height() -> float:
	return WINDOW.y * clampf(1.0 - time / BLUE_HOUR, 0.0, 1.0)


## px of the window drawn lit: the clock's height, reached smoothly over
## LIGHT_EASE seconds after the clock jumps (a fumble), so the light never leaps.
func shown_light_height() -> float:
	if _light_t >= LIGHT_EASE:
		return light_height()
	return lerpf(_light_from, light_height(), _light_t / LIGHT_EASE)


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


## True while a fitted card is sliding into its slot.
func sliding() -> bool:
	return not _slide.is_empty()


## How far the sliding card has gone, 0 at its place to 1 in the slot; 1 when none slides.
func slide_share() -> float:
	return clampf(float(_slide.t) / SLIDE, 0.0, 1.0) if not _slide.is_empty() else 1.0


## Where the sliding card is drawn now (desk coordinates); the slot's place when none slides.
func slide_position() -> Vector2:
	return (_slide.node as Node2D).position if not _slide.is_empty() else Vector2.ZERO


## The slot the sliding card is bound for, -1 when none slides.
func slide_slot() -> int:
	return int(_slide.slot) if not _slide.is_empty() else -1


## How bright a slot's flash is now: 1 as the card lands, 0 after SLOT_FLASH seconds (and with no flash).
func slot_flash_alpha(index: int) -> float:
	if _developed_left > 0.0:
		return developed_flash_alpha()
	return clampf(float(_slot_flash.get(index, 0.0)) / SLOT_FLASH, 0.0, 1.0)


## True from the last slot's fill until the developed show is over.
func developing() -> bool:
	return _developed_left > 0.0 or _developed_pending != ""


## The outline's flash while the developed thing's name shows: DEVELOPED_FLASHES swells over DEVELOPED_SHOWS seconds.
func developed_flash_alpha() -> float:
	if _developed_left <= 0.0:
		return 0.0
	var elapsed := DEVELOPED_SHOWS - _developed_left
	return maxf(sin(PI * DEVELOPED_FLASHES * elapsed / DEVELOPED_SHOWS), 0.0)


## The developed thing's name as shown over the outline; "" when not showing.
func developed_name() -> String:
	return developed_label.text if developed_label != null and developed_label.visible else ""


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


# --- the feel ------------------------------------------------------------------

## A fitted card starts sliding from its place in the row to its slot.
func _start_slide(slot: int, shape: String, from: Vector2) -> void:
	if not _slide.is_empty():
		_land_slide()   # a second fit before the first landed: the first lands now
	var node := Node2D.new()
	node.name = "Sliding"
	node.position = from
	_card_look(node, shape, CARD_EDGE)
	feel_node.add_child(node)
	_slide = {"slot": slot, "from": from, "to": Vector2(slot * (SLOT.x + SLOT_GAP), ROW_Y), "t": 0.0, "node": node}


## The sliding card is in its slot: the slot is drawn filled and flashes once.
func _land_slide() -> void:
	if _slide.is_empty():
		return
	var slot: int = _slide.slot
	var node: Node2D = _slide.node
	feel_node.remove_child(node)
	node.queue_free()
	_slide = {}
	_slot_flash[slot] = SLOT_FLASH
	_redraw()
	if _developed_pending != "":
		_begin_developed()


func _begin_developed() -> void:
	_developed_left = DEVELOPED_SHOWS
	PinchLabel.set_text(developed_label, word("developed").format({"name": _developed_pending}))
	developed_label.visible = true
	_developed_pending = ""
	for i in slots.size():
		_draw_flash(i)


## The flash rect over the `index`-th slot at its alpha now (made when first needed).
func _draw_flash(index: int) -> void:
	if outline_node == null or index < 0 or index >= outline_node.get_child_count():
		return
	var slot: Node2D = outline_node.get_child(index)
	var flash: ColorRect = slot.get_node_or_null("Flash")
	var alpha := slot_flash_alpha(index)
	if flash == null:
		if alpha <= 0.0:
			return
		flash = _rect(slot, Rect2(Vector2.ZERO, SLOT), FLASH)
		flash.name = "Flash"
	flash.modulate.a = alpha
	flash.visible = alpha > 0.0


# --- drawing -------------------------------------------------------------------

func _redraw() -> void:
	for child in outline_node.get_children():
		outline_node.remove_child(child)
		child.queue_free()
	for child in cards_node.get_children():
		cards_node.remove_child(child)
		child.queue_free()
	var landing := slide_slot()
	for i in slots.size():
		var slot := Node2D.new()
		slot.name = "Slot%d" % (i + 1)
		slot.position = Vector2(i * (SLOT.x + SLOT_GAP), ROW_Y)
		slot.set_meta("shape", slots[i])
		slot.set_meta("filled", filled[i])
		if filled[i] == "" or i == landing:   # a slot whose card is still sliding is drawn empty until it lands
			_rect(slot, Rect2(Vector2.ZERO, SLOT), HOLE_BACK)
			_mark(slot, slots[i], SLOT / 2.0, HOLE)
		else:
			_rect(slot, Rect2(Vector2(-2, -2), SLOT + Vector2(4, 4)), CARD_EDGE)
			_rect(slot, Rect2(Vector2.ZERO, SLOT), CARD_FACE)
			_mark(slot, filled[i], SLOT / 2.0, MARK)
		outline_node.add_child(slot)
		_draw_flash(i)
	for i in cards.size():
		var node := Node2D.new()
		node.name = "Card%d" % (i + 1)
		node.position = Vector2(i * (CARD.x + CARD_GAP), ROW_Y - (PICKED_RAISE if i == card else 0.0))
		node.set_meta("shape", cards[i])
		node.set_meta("index", i)
		_card_look(node, cards[i], HAND if i == card else CARD_EDGE)
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
		cards_node.add_child(node)
	if hand_node != null:
		hand_node.position.x = hand * (SLOT.x + SLOT_GAP)
		hand_node.visible = not slots.is_empty()


## A card's look under `holder`: the edge, the white face, the shape's mark.
func _card_look(holder: Node, shape: String, edge: Color) -> void:
	_rect(holder, Rect2(Vector2(-2, -2), CARD + Vector2(4, 4)), edge)
	_rect(holder, Rect2(Vector2.ZERO, CARD), CARD_FACE)
	_mark(holder, shape, Vector2(CARD.x / 2.0, CARD.y * 0.62), MARK)


func _draw_light() -> void:
	if light_node == null:
		return
	var h := shown_light_height()
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
