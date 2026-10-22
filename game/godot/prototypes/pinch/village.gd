extends Node2D
## The street of Yawn by day (toy 4, PINCH): a side view four screens wide on
## one ground line. Three buildings stand (the Long House with the bunk, the
## table, the stove and the tally wall; Jorun's hut; the stove shed) and
## three plots wait (Sixteen Stairs, Bo's loft, a lantern post). Two black
## rects mask the street beyond the lit tiles at each end; they recede one
## tile per building standing, read from the state. E at the bunk emits
## slept.
##
## Day 4. THE PEOPLE (data/characters.json): Tove by the stove, Jorun by the
## Long House door, Bo by his plot; grey capsules with a name over the head.
## E within TALK_RANGE talks: the first unspoken memory line whose "if"
## flags hold (and no "unless" flag does; "repeat": true lines may be said
## again), else the greeting; the want line shows above the head for
## WANT_STAYS seconds. A character whose plot stands moves out and stands in
## front of it. THE REQUESTS: on a morning where a character's request
## "when" holds and it has not been asked, its line is said after the wake
## line and the flag asked:<id> is set; "pills" opens the stove shed (hold
## E there MAKING seconds, the walker standing still: has_pills; then the
## bunk's prompt offers 1 for a pill, which raises the night's limit), "hat"
## raises the carry limit to three. BREAKFAST (SPEC "Breakfast, exactly"):
## every morning with ideas on the table the walker is put at the table and
## the three faces sit behind it with their want lines; the top kept idea
## is in the hand (1, 2, 3 change it); E at a face offers it: the owner
## (idea.whose) says its claims line and the idea is claimed (a scaffold on
## its plot today, a building tomorrow) or, if it becomes a small thing, is
## one; a wrong face says its not_mine line, closes its eyes for the rest
## of breakfast and sets told_wrong. A head drops every HEAD_DROP seconds
## (the capsule tilts, its want line fades; a dropped or shut face cannot
## claim); when the last head drops, every kept idea is placed, no face is
## left awake or the walker leaves the table (TABLE_RANGE), breakfast ends
## and what is left becomes a small thing. BUILDINGS: a claimed plot shows
## a scaffold (an outline with crossbars), a built one a filled rect with a
## lit window and the idea's name; small things are a bench, a sign or the
## lantern on its post, labelled. The lost ideas of a sudden waking float
## over the bunk and fade (fade_lost). Lines are said through the shared
## text panel (the controller's, or one of its own when run alone): say_for
## shows one for some seconds, queued behind the one showing unless `now`.
## THE FEEL (day 5, drawn only, every number a constant below): the lit
## window of a building that stands this morning (lit_today, set by the
## controller) fades in over WINDOW_FADE seconds; a scaffold's crossbars
## appear one every CROSSBAR_EVERY seconds after the claim; at a claim the
## face nods (its Face dips NOD_PX over NOD_FRAMES) and the idea's rect
## slides from the hand to the face over SLIDE seconds before it goes.
## Every word on screen comes from data/village.json and
## data/characters.json, idea names from data/ideas.json; rewrite those.

signal slept
signal acted(kind: String, detail: String)

const WORDS_FILE := "res://prototypes/pinch/data/village.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const PANEL := preload("res://prototypes/_shared/text_panel.tscn")
const LOST_FADE := 6.0           # s the lost stack takes to fade over the bunk
const PIECE := Vector2(32, 24)   # px: one idea as a rect, on the table or over the bunk
const STREET_WIDTH := 4608.0   # px: four screens of 1152
const STREET_HEIGHT := 648.0   # px: one screen; the camera never scrolls up or down
const GROUND_Y := 540.0        # px: the ground line
const BUNK_RANGE := 48.0       # px: this close to the bunk's middle, E sleeps
const TALK_RANGE := 40.0       # px: this close to a character's feet, E talks
const SEAT_RANGE := 30.0       # px: this close to a seat at breakfast, E offers
const TABLE_RANGE := 140.0     # px from the table's middle: further, and breakfast is walked away from
const STOVE_RANGE := 48.0      # px: this close to the stove shed's middle, E (held) makes the pills
const BREAKFAST := 90.0        # s: three heads, one every HEAD_DROP
const HEAD_DROP := 30.0        # s between heads dropping
const MAKING := 3.0            # s E is held at the stove shed to make the pills
const LINE_STAYS := 3.0        # s a line stays on screen
const REQUEST_STAYS := 6.0     # s a request line stays
const WANT_STAYS := 4.0        # s the want line shows over a head after a talk
const SEAT_GAP := 56.0         # px between the three seats at the table
const DROPPED_TILT := 0.45     # rad a dropped head's capsule leans
const DROPPED_WANT_ALPHA := 0.25
const WINDOW_FADE := 1.5       # s a new building's lit window takes to fade in, the morning it stands
const CROSSBAR_EVERY := 1.0    # s between a scaffold's crossbars appearing after the claim
const NOD_PX := 6.0            # px a claiming face dips
const NOD_FRAMES := 10         # frames the nod takes, down and back
const SLIDE := 0.4             # s the claimed idea's rect takes to slide from the hand to the face
const SLIDE_ABOVE := 30.0      # px above the claiming face where the slide ends
const CAPSULE := Vector2(26, 52)
const WINDOW := Vector2(18, 22)
const WALL := Color(0.5, 0.5, 0.5)
const MARKER := Color(0.72, 0.72, 0.72)
const OUTLINE := Color(0.42, 0.42, 0.42)
const SCAFFOLD := Color(0.6, 0.6, 0.6)
const PERSON := Color(0.66, 0.66, 0.68)
const EYE := Color(0.12, 0.12, 0.14)
const WINDOW_LIT := Color(1.0, 0.9, 0.45)
const SMALL := Color(0.58, 0.58, 0.6)

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
const STOVE := Rect2(2290, 504, 40, 36)   # inside the Long House, the middle
const BUNK := Rect2(2400, 500, 70, 40)    # inside the Long House, right
const DOOR_X := 2056.0                    # outside the Long House's left wall: where Jorun stands
const SMALL_SLOTS := [2748.0, 2542.0, 1766.0, 2046.0]   # x of the gaps between buildings where small things go

@onready var walker: CharacterBody2D = $Walker
@onready var prompt_label: Label = $Walker/Prompt
@onready var day_label: Label = $Hud/DayLabel
@onready var mask_left: ColorRect = $Mask/Left
@onready var mask_right: ColorRect = $Mask/Right
@onready var street: Node2D = $Street

var state: PinchState         # set by the controller before add_child; a fresh one when run alone
var panel: CanvasLayer = null # the shared text panel; the controller's, or one of its own
var wake_line := ""           # set by the controller before add_child: said first thing in the morning
var lit_today: Array[String] = []   # set by the controller before add_child: the plots that stand since this morning (their windows fade in)
var words: Dictionary = {}    # village.json
var ideas: Array = []         # ideas.json
var characters: Array = []    # characters.json "characters", in order
var want_line := "{name}: {want}"
var tally_wall: Label = null  # the marks on the Long House wall, one per sudden waking
var table_ideas: Node2D = null   # the kept ideas on the table, one labelled rect each
var lost_stack: Node2D = null    # the ideas lost at waking, fading over the bunk; null when none
var plots: Node2D = null         # the plots as they stand today: outline, scaffold or building
var small_things: Node2D = null  # the small things on the street
var people_node: Node2D = null   # the characters on the street
var seats_node: Node2D = null    # the faces at the table while breakfast is on
var hand: Node2D = null          # the idea in the hand at breakfast, over the walker's head
var people := {}                 # who -> Node2D (a capsule on the street)
var seats := {}                  # who -> Node2D (a capsule at the table), while breakfast is on
var seat_state := {}             # who -> "awake" | "closed" | "dropped"
var plot_nodes := {}             # plot id -> Node2D drawn for it
var breakfast_on := false
var breakfast_time := 0.0        # s since breakfast began
var heads_dropped := 0
var hand_index := 0              # which kept idea is in the hand
var making := 0.0                # s E has been held at the stove shed
var _slept := false
var _lost_left := 0.0
var _lines: Array = []           # [text, seconds] waiting behind the line showing
var _line_left := 0.0            # s the line showing has left; 0: nothing showing
var _want_left := {}             # who -> s the want line over a street head has left
var _day_time := 0.0             # s since this morning began
var _claimed_at := {}            # plot id -> _day_time of its claim at breakfast (the crossbars count from it)
var _nods := {}                  # who -> [the seat's Face, frames of the nod left]
var _slides: Array = []          # [piece, from, to, seconds left] of idea rects sliding to a face
var slides_node: Node2D = null   # the sliding rects
var _seats_retiring := false     # breakfast ended on a claim: the faces stay until the nod and the slide are done


func _ready() -> void:
	if state == null:
		state = PinchState.new()
	var loaded: Variant = PinchState.load_json(WORDS_FILE)
	words = loaded if loaded is Dictionary else {}
	loaded = PinchState.load_json(IDEAS_FILE)
	ideas = loaded if loaded is Array else []
	loaded = PinchState.load_json(CHARACTERS_FILE)
	var people_json: Dictionary = loaded if loaded is Dictionary else {}
	characters = people_json.get("characters", [])
	want_line = str(people_json.get("want_line", want_line))
	if panel == null:
		panel = PANEL.instantiate()
		add_child(panel)
	_build_street()
	_build_people()
	prompt_label.visible = false
	refresh()
	if wake_line != "":
		say_for(wake_line, LINE_STAYS)
	_morning()


func _process(delta: float) -> void:
	_day_time += delta
	_draw_feel(delta)
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_next_line()
	if lost_stack != null:
		_lost_left -= delta
		if _lost_left <= 0.0:
			street.remove_child(lost_stack)
			lost_stack.queue_free()
			lost_stack = null
		else:
			lost_stack.modulate.a = _lost_left / LOST_FADE
	for who in _want_left.keys():
		_want_left[who] -= delta
		if _want_left[who] <= 0.0:
			_want_left.erase(who)
			_want_label(people[who]).visible = false
	if breakfast_on:
		breakfast_time += delta
		_apply_drops()
		if breakfast_on and absf(walker.position.x - TABLE.get_center().x) > TABLE_RANGE:
			end_breakfast("skipped")
	if can_make() and Input.is_action_pressed("interact"):
		making += delta
		walker.frozen = true
		if making >= MAKING:
			make_pills()
	else:
		making = 0.0
		walker.frozen = false
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if breakfast_on:
			offer()
		elif bunk_in_range():
			go_to_sleep()
		elif can_make():
			pass   # the hold is read in _process
		else:
			var who := character_in_reach()
			if who != "":
				talk(who)
	elif breakfast_on:
		for i in 3:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				set_hand(i)
	elif event.is_action_pressed("choice_1") and bunk_in_range():
		take_pill()


# --- the street ----------------------------------------------------------------

## Re-reads the state: the day label, the tally wall, the ideas on the
## table, the plots, the small things, where the people stand, the dark at
## each end.
func refresh() -> void:
	day_label.text = str(words.get("day_label", "{day}")).format({"day": state.day})
	tally_wall.text = str(words.get("tally_mark", "|")).repeat(state.tally)
	for piece in table_ideas.get_children():
		table_ideas.remove_child(piece)
		piece.queue_free()
	for i in state.ideas_kept.size():
		_add_piece(table_ideas, state.ideas_kept[i], Vector2(TABLE.position.x + 8 + i * (PIECE.x + 6), TABLE.position.y - PIECE.y), i)
	_draw_plots()
	_draw_small_things()
	_place_people()
	_update_hand()
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


func stove_in_range() -> bool:
	return absf(walker.position.x - plot_rect("stove_shed").get_center().x) <= STOVE_RANGE


## The name of an idea, from ideas.json.
func idea_name(id: String) -> String:
	return str(idea_entry(id).get("name", id))


## The ideas.json entry of an idea; {} if there is none.
func idea_entry(id: String) -> Dictionary:
	for idea in ideas:
		if str(idea.get("id", "")) == id:
			return idea
	return {}


## The ideas kept, as drawn on the table, in order.
func table_idea_ids() -> Array[String]:
	var ids: Array[String] = []
	for piece in table_ideas.get_children():
		ids.append(str(piece.get_meta("id")))
	return ids


## The rect of a plot or a building of the LAYOUT, on the street.
func plot_rect(id: String) -> Rect2:
	for entry in LAYOUT:
		if entry[1] == id:
			return Rect2(entry[2], GROUND_Y - entry[4], entry[3], entry[4])
	return Rect2()


## What stands on a plot today: "empty", "scaffold" (claimed at breakfast) or "built".
func plot_state(plot: String) -> String:
	if state.ideas_built.has(plot):
		return "built"
	if state.ideas_claimed.has(plot):
		return "scaffold"
	return "empty"


## The node drawn for a plot (its label is the child named Name; a built
## plot's lit window is the child named Window).
func plot_node(plot: String) -> Node2D:
	return plot_nodes.get(plot, null)


## The small things on the street, as drawn, in order: their idea ids.
func small_thing_ids() -> Array[String]:
	var ids: Array[String] = []
	for thing in small_things.get_children():
		ids.append(str(thing.get_meta("id")))
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


## 1 at the bunk with pills in the house: one for tonight. The limit grows
## by the pill's bonus this night only; the game never says who it is for.
func take_pill() -> bool:
	if not state.has_pills or state.pill_tonight or _slept:
		return false
	state.pill_tonight = true
	say_for(str(words.get("pill_taken", "")), LINE_STAYS, true)
	acted.emit("pill", "")
	return true


# --- the feel --------------------------------------------------------------------

## The window of a building that stands since this morning: 0 at the
## start, 1 after WINDOW_FADE seconds.
func window_alpha(plot: String) -> float:
	if not lit_today.has(plot):
		return 1.0
	return clampf(_day_time / WINDOW_FADE, 0.0, 1.0)


## How many of a scaffold's crossbars show: one more every CROSSBAR_EVERY
## seconds since the claim; all of them for a scaffold claimed before this
## morning (none is: claims stand the next day).
func crossbars_shown(plot: String) -> int:
	var node := plot_node(plot)
	if node == null or not _claimed_at.has(plot):
		return _count_bars(node) if node != null else 0
	return mini(int((_day_time - float(_claimed_at[plot])) / CROSSBAR_EVERY), _count_bars(node))


## px a face at the table is dipped by its nod now; 0 when still.
func face_dip(who: String) -> float:
	if not _nods.has(who):
		return 0.0
	var left: int = _nods[who][1]
	return NOD_PX * sin(PI * (NOD_FRAMES - left + 1) / float(NOD_FRAMES + 1))


## True while a nod or a slide is being drawn.
func feel_in_flight() -> bool:
	return not _nods.is_empty() or not _slides.is_empty()


## The idea rects sliding to a face right now.
func slides_in_flight() -> int:
	return _slides.size()


func _count_bars(node: Node2D) -> int:
	var n := 0
	for child in node.get_children():
		if child.has_meta("bar"):
			n += 1
	return n


## Every drawn frame: the new windows fade in, the crossbars appear, the
## nods dip and come back, the slides move and are gone at the face.
func _draw_feel(delta: float) -> void:
	for plot in lit_today:
		var node := plot_node(plot)
		if node != null and node.has_node("Window"):
			node.get_node("Window").modulate.a = window_alpha(plot)
	for plot in _claimed_at:
		var node := plot_node(plot)
		if node == null:
			continue
		var shown := crossbars_shown(plot)
		for child in node.get_children():
			if child.has_meta("bar"):
				child.visible = int(child.get_meta("bar")) < shown
	for who in _nods.keys():
		var face: Node2D = _nods[who][0]
		if is_instance_valid(face):
			face.position.y = face_dip(who)
		_nods[who][1] -= 1
		if _nods[who][1] <= 0:
			_nods.erase(who)
			if is_instance_valid(face):
				face.position.y = 0.0
	var done: Array = []
	for slide in _slides:
		slide[3] -= delta
		var piece: Node2D = slide[0]
		if slide[3] <= 0.0:
			done.append(slide)
			slides_node.remove_child(piece)
			piece.queue_free()
		else:
			piece.position = (slide[1] as Vector2).lerp(slide[2], 1.0 - slide[3] / SLIDE)
	for slide in done:
		_slides.erase(slide)
	if _seats_retiring and not feel_in_flight():
		_seats_retiring = false
		_clear_seats()


## A claim: the face nods and the idea's rect slides from the hand to it.
func _claim_feel(who: String, id: String) -> void:
	_nods[who] = [seats[who].get_node("Face"), NOD_FRAMES]
	var from: Vector2 = walker.position + hand.position + Vector2(-PIECE.x / 2.0, -PIECE.y)
	var to: Vector2 = seats[who].position + Vector2(-PIECE.x / 2.0, -CAPSULE.y - SLIDE_ABOVE)
	var piece := _add_piece(slides_node, id, from, 0)
	_slides.append([piece, from, to, SLIDE])


# --- lines ---------------------------------------------------------------------

## A line on the panel for `seconds`: behind the one showing, or in its
## place (`now`, which also drops what was waiting).
func say_for(text: String, seconds: float, now := false) -> void:
	if text == "":
		return
	if now:
		_lines = []
	if now or _line_left <= 0.0:
		panel.say(text)
		_line_left = seconds
	else:
		_lines.append([text, seconds])


func _next_line() -> void:
	if _lines.is_empty():
		panel.say("")
		_line_left = 0.0
		return
	var next: Array = _lines.pop_front()
	panel.say(str(next[0]))
	_line_left = float(next[1])


## The lines waiting behind the one showing, in order.
func lines_waiting() -> Array[String]:
	var texts: Array[String] = []
	for entry in _lines:
		texts.append(str(entry[0]))
	return texts


# --- the morning ---------------------------------------------------------------

## The requests whose time has come, then breakfast if there is anything on the table.
func _morning() -> void:
	for c in characters:
		var request: Dictionary = c.get("request", {})
		if request.is_empty():
			continue
		var id := str(request.get("id", ""))
		if state.has_flag("asked:%s" % id) or not state.holds(request.get("when", [])):
			continue
		state.set_flag("asked:%s" % id)
		_apply_request(id)
		say_for(str(request.get("text", "")), REQUEST_STAYS)
		acted.emit("request", id)
	if not state.ideas_kept.is_empty() and state.breakfast_done_day != state.day:
		start_breakfast()


## What a request does the moment it is asked: the hat is handed over at once; the
## pills wait for the stove shed (can_make).
func _apply_request(id: String) -> void:
	if id == "hat":
		state.carry_limit = PinchState.HAT_CARRY


# --- the people ----------------------------------------------------------------

func character(who: String) -> Dictionary:
	for c in characters:
		if str(c.get("id", "")) == who:
			return c
	return {}


## Where a character stands today: in front of their plot once it stands,
## else at their post ("door", "stove" or "plot:<id>").
func stand_x(who: String) -> float:
	var c := character(who)
	var plot := str(c.get("plot", ""))
	if plot != "" and state.ideas_built.has(plot):
		return plot_rect(plot).get_center().x
	var where := str(c.get("where", ""))
	if where == "door":
		return DOOR_X
	if where == "stove":
		return STOVE.end.x + 20.0
	if where.begins_with("plot:"):
		return plot_rect(where.substr(5)).get_center().x
	return TABLE.get_center().x


## The character (standing on the street, not at the table) nearest the walker within TALK_RANGE.
func character_in_reach() -> String:
	var best := ""
	var best_distance := TALK_RANGE
	for who in people:
		if not people[who].visible:
			continue
		var distance: float = absf(people[who].position.x - walker.position.x)
		if distance <= best_distance:
			best = who
			best_distance = distance
	return best


## The line a talk would give now: the first unspoken memory line whose
## conditions hold (a "repeat" line may be said again), else the greeting.
## Does not mark it spoken; talk() does.
func line_for(who: String) -> Dictionary:
	var c := character(who)
	for line in c.get("lines", []):
		if state.has_flag(_said_flag(who, line)) and not line.get("repeat", false):
			continue
		if not state.holds(line.get("if", [])) or state.holds_any(line.get("unless", [])):
			continue
		return line
	return {"id": "greeting", "text": str(c.get("greeting", ""))}


## E next to a character: the line, the want over the head, the memory.
func talk(who: String) -> String:
	var c := character(who)
	if c.is_empty():
		return ""
	var line := line_for(who)
	if str(line.get("id", "")) != "greeting":
		state.set_flag(_said_flag(who, line))
	state.set_flag("talked:%s" % who)
	say_for(str(line.get("text", "")), LINE_STAYS, true)
	_want_label(people[who]).visible = true
	_want_left[who] = WANT_STAYS
	acted.emit("talk", who)
	return str(line.get("text", ""))


func _said_flag(who: String, line: Dictionary) -> String:
	return "said:%s:%s" % [who, str(line.get("id", ""))]


## The stove shed is open for making once Tove has asked and until the pills are made.
func can_make() -> bool:
	return state.has_flag("asked:pills") and not state.has_pills and not breakfast_on and not _slept and stove_in_range()


## E held MAKING seconds at the stove shed: the pills are in the house.
func make_pills() -> void:
	if state.has_pills:
		return
	state.has_pills = true
	state.set_flag("made:pills")
	making = 0.0
	walker.frozen = false
	say_for(str(words.get("made", "")), LINE_STAYS, true)
	acted.emit("made", "pills")


# --- breakfast -----------------------------------------------------------------

## The walker at the table, the three faces behind it with their wants, the
## top kept idea in the hand, the clock at zero.
func start_breakfast() -> void:
	if breakfast_on or state.ideas_kept.is_empty():
		return
	breakfast_on = true
	breakfast_time = 0.0
	heads_dropped = 0
	hand_index = 0
	walker.position.x = TABLE.get_center().x
	walker.velocity = Vector2.ZERO
	seats = {}
	seat_state = {}
	for i in characters.size():
		var c: Dictionary = characters[i]
		var who := str(c.get("id", ""))
		var seat := _capsule(c, Vector2(TABLE.get_center().x + (i - (characters.size() - 1) / 2.0) * SEAT_GAP, GROUND_Y), true)
		seats_node.add_child(seat)
		seats[who] = seat
		seat_state[who] = "awake"
		people[who].visible = false
	_update_hand()
	acted.emit("breakfast", "start")


## Breakfast over, for `reason` ("told": every idea placed; "dropped": the last
## head; "asleep": no face left awake; "skipped": walked away): what is left
## on the table becomes a small thing, the faces go, the people are back.
func end_breakfast(reason: String) -> void:
	if not breakfast_on:
		return
	breakfast_on = false
	for id in state.ideas_kept:
		state.small_things.append(id)
		acted.emit("small_thing", id)
	state.ideas_kept.clear()
	state.breakfast_done_day = state.day
	seats = {}
	if feel_in_flight():
		_seats_retiring = true   # the last claim's nod and slide are still being drawn: the faces go after them
	else:
		_clear_seats()
	for who in people:
		people[who].visible = true
	panel.prompt("")
	say_for(str(words.get("breakfast", {}).get("over", "")), LINE_STAYS)
	acted.emit("breakfast", reason)
	refresh()


## The faces leave the table.
func _clear_seats() -> void:
	for seat in seats_node.get_children():
		seats_node.remove_child(seat)
		seat.queue_free()


## The clock moved on by hand (tests, the designer): the heads that should have dropped, drop.
func step_breakfast(seconds: float) -> void:
	if not breakfast_on:
		return
	breakfast_time += seconds
	_apply_drops()


## The drop order of the faces: by "drops" in characters.json, lowest first.
func drop_order() -> Array[String]:
	var order: Array = characters.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("drops", 0)) < int(b.get("drops", 0)))
	var ids: Array[String] = []
	for c in order:
		ids.append(str(c.get("id", "")))
	return ids


func _apply_drops() -> void:
	var order := drop_order()
	while breakfast_on and heads_dropped < order.size() and heads_dropped < int(breakfast_time / HEAD_DROP):
		_drop_head(order[heads_dropped])
		heads_dropped += 1
	if breakfast_on and heads_dropped >= order.size():
		end_breakfast("dropped")


## A head drops: the capsule tilts, the want line fades, the face is out.
func _drop_head(who: String) -> void:
	seat_state[who] = "dropped"
	var seat: Node2D = seats[who]
	seat.rotation = DROPPED_TILT
	_set_eyes(seat, false)
	_want_label(seat).modulate.a = DROPPED_WANT_ALPHA
	acted.emit("dropped", who)


## The seat nearest the walker within SEAT_RANGE; "" when none.
func seat_in_reach() -> String:
	var best := ""
	var best_distance := SEAT_RANGE
	for who in seats:
		var distance: float = absf(seats[who].position.x - walker.position.x)
		if distance <= best_distance:
			best = who
			best_distance = distance
	return best


## The idea in the hand at breakfast; "" when none.
func hand_idea() -> String:
	if not breakfast_on or state.ideas_kept.is_empty():
		return ""
	return state.ideas_kept[clampi(hand_index, 0, state.ideas_kept.size() - 1)]


## 1, 2, 3: which kept idea is in the hand.
func set_hand(index: int) -> bool:
	if not breakfast_on or index < 0 or index >= state.ideas_kept.size():
		return false
	hand_index = index
	_update_hand()
	return true


## E at a face: the idea in the hand is offered. Its owner claims it; a wrong
## face says no and shuts its eyes; a dropped or shut face says nothing.
func offer() -> bool:
	var who := seat_in_reach()
	var id := hand_idea()
	if who == "" or id == "":
		return false
	var c := character(who)
	if seat_state[who] != "awake":
		say_for(str(words.get("breakfast", {}).get("asleep", "")).format({"name": str(c.get("name", who))}), LINE_STAYS, true)
		return false
	var idea := idea_entry(id)
	if str(idea.get("whose", "")) == who:
		state.ideas_kept.erase(id)
		var becomes := str(idea.get("becomes", ""))
		if plot_rect(becomes).size != Vector2.ZERO and becomes != "lantern_post":
			state.ideas_claimed[becomes] = id
			_claimed_at[becomes] = _day_time
		else:
			state.small_things.append(id)
			acted.emit("small_thing", id)
		say_for((str(c.get("claims", "")) + " " + str(idea.get("line", ""))).strip_edges(), LINE_STAYS, true)
		acted.emit("told", "%s:%s" % [id, who])
		_claim_feel(who, id)
		hand_index = clampi(hand_index, 0, maxi(0, state.ideas_kept.size() - 1))
		refresh()
		if state.ideas_kept.is_empty():
			end_breakfast("told")
		return true
	seat_state[who] = "closed"
	_set_eyes(seats[who], false)
	state.set_flag("told_wrong")
	say_for(str(c.get("not_mine", "")), LINE_STAYS, true)
	acted.emit("told_wrong", "%s:%s" % [id, who])
	if not seat_state.values().has("awake"):
		end_breakfast("asleep")
	return false


## Whether a seat's eyes are open (awake), for the designer's eye and the tests.
func seat_eyes_open(who: String) -> bool:
	return seats.has(who) and seats[who].get_node("Face/EyeL").size.y > 1.5


func _update_hand() -> void:
	for piece in hand.get_children():
		hand.remove_child(piece)
		piece.queue_free()
	var id := hand_idea()
	if id == "":
		if breakfast_on:
			panel.prompt("")
		return
	_add_piece(hand, id, Vector2(-PIECE.x / 2.0, -PIECE.y), 0)
	var breakfast_words: Dictionary = words.get("breakfast", {})
	var key := "offer_many" if state.ideas_kept.size() > 1 else "offer"
	panel.prompt(str(breakfast_words.get(key, "")).format({"idea": idea_name(id)}))


# --- the prompt over the walker --------------------------------------------------

func _update_prompt() -> void:
	var text := ""
	if _slept or breakfast_on:
		pass
	elif bunk_in_range():
		text = str(words.get("sleep_prompt_pills" if state.has_pills and not state.pill_tonight else "sleep_prompt", ""))
	elif can_make():
		text = str(words.get("making" if making > 0.0 else "make_prompt", ""))
	elif character_in_reach() != "":
		text = str(words.get("talk_prompt", ""))
	prompt_label.text = text
	prompt_label.visible = text != ""


# --- drawing -------------------------------------------------------------------

func _build_street() -> void:
	var buildings: Dictionary = words.get("buildings", {})
	var markers: Dictionary = words.get("markers", {})
	for entry in LAYOUT:
		if entry[0] != "building":
			continue
		var rect := Rect2(entry[2], GROUND_Y - entry[4], entry[3], entry[4])
		_add_box(rect, WALL)
		_add_label(str(buildings.get(entry[1], entry[1])), Vector2(rect.position.x, rect.position.y - 26), rect.size.x)
	_add_box(TABLE, MARKER)
	_add_label(str(markers.get("table", "")), Vector2(TABLE.position.x, TABLE.position.y - 22), TABLE.size.x)
	_add_box(STOVE, MARKER)
	_add_label(str(markers.get("stove", "")), Vector2(STOVE.position.x - 30, STOVE.position.y - 22), STOVE.size.x + 60)
	_add_box(BUNK, MARKER)
	_add_label(str(markers.get("bunk", "")), Vector2(BUNK.position.x, BUNK.position.y - 22), BUNK.size.x)
	_add_label(str(words.get("tally_title", "")), Vector2(TABLE.position.x, TABLE.position.y - 150), 200.0, HORIZONTAL_ALIGNMENT_LEFT)
	tally_wall = _add_label("", Vector2(TABLE.position.x, TABLE.position.y - 126), 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	plots = _holder("Plots")
	small_things = _holder("SmallThings")
	table_ideas = _holder("TableIdeas")
	people_node = _holder("People")
	seats_node = _holder("Seats")
	slides_node = _holder("Slides")
	hand = Node2D.new()
	hand.name = "Hand"
	hand.position = Vector2(0, -58)
	walker.add_child(hand)


func _holder(holder_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = holder_name
	street.add_child(holder)
	return holder


func _build_people() -> void:
	for c in characters:
		var who := str(c.get("id", ""))
		var person := _capsule(c, Vector2(stand_x(who), GROUND_Y), false)
		people_node.add_child(person)
		people[who] = person


func _place_people() -> void:
	for who in people:
		people[who].position.x = stand_x(who)


## The plots as they stand: an outline and the plot's name; a scaffold (the
## outline, two crossbars, a diagonal, "scaffold"); or the building (a
## filled rect, a lit window, the idea's name). The lantern post plot holds
## the lantern once a spoon has become one.
func _draw_plots() -> void:
	for plot in plots.get_children():
		plots.remove_child(plot)
		plot.queue_free()
	plot_nodes = {}
	var plot_names: Dictionary = words.get("plots", {})
	var markers: Dictionary = words.get("markers", {})
	for entry in LAYOUT:
		if entry[0] != "plot":
			continue
		var id: String = entry[1]
		var rect := Rect2(entry[2], GROUND_Y - entry[4], entry[3], entry[4])
		var node := Node2D.new()
		node.name = "Plot_%s" % id
		node.position = rect.position
		node.set_meta("id", id)
		var local := Rect2(Vector2.ZERO, rect.size)
		var what := plot_state(id)
		node.set_meta("state", what)
		if what == "built":
			_rect_under(node, local, WALL)
			var window := _rect_under(node, Rect2(Vector2(rect.size.x / 2.0 - WINDOW.x / 2.0, rect.size.y * 0.3), WINDOW), WINDOW_LIT)
			window.name = "Window"
			window.modulate.a = window_alpha(id)
			_label_under(node, idea_name(str(state.ideas_built[id])), Vector2(-60, -26), rect.size.x + 120).name = "Name"
		elif what == "scaffold":
			_outline_under(node, local, OUTLINE)
			var bars: Array[ColorRect] = []
			bars.append(_rect_under(node, Rect2(0, rect.size.y / 3.0, rect.size.x, 3), SCAFFOLD))
			bars.append(_rect_under(node, Rect2(0, rect.size.y * 2.0 / 3.0, rect.size.x, 3), SCAFFOLD))
			var diagonal := _rect_under(node, Rect2(Vector2(3, rect.size.y - 3), Vector2(local.size.length() - 6.0, 3)), SCAFFOLD)
			diagonal.rotation = -atan2(rect.size.y, rect.size.x)
			bars.append(diagonal)
			for i in bars.size():
				bars[i].set_meta("bar", i)   # shown one by one, CROSSBAR_EVERY apart, from the claim (_draw_feel)
				bars[i].visible = not _claimed_at.has(id)
			_label_under(node, str(markers.get("scaffold", "")), Vector2(-60, -26), rect.size.x + 120).name = "Name"
		elif id == "lantern_post" and _small_thing_for("lantern_post") != "":
			_rect_under(node, Rect2(rect.size.x / 2.0 - 4, 40, 8, rect.size.y - 40), SMALL)
			_rect_under(node, Rect2(rect.size.x / 2.0 - 12, 16, 24, 28), WINDOW_LIT)
			node.set_meta("state", "small_thing")
			_label_under(node, str(words.get("small_things", {}).get("lantern_post", "")), Vector2(-60, -26), rect.size.x + 120).name = "Name"
		else:
			_outline_under(node, local, OUTLINE)
			_label_under(node, str(plot_names.get(id, id)), Vector2(-60, -26), rect.size.x + 120).name = "Name"
		plots.add_child(node)
		plot_nodes[id] = node


## The small things on the street: a bench or a sign in the gaps between
## the buildings, labelled from village.json by what the idea becomes; the
## lantern is drawn on its post by _draw_plots.
func _draw_small_things() -> void:
	for thing in small_things.get_children():
		small_things.remove_child(thing)
		thing.queue_free()
	var names: Dictionary = words.get("small_things", {})
	var slot := 0
	for id in state.small_things:
		var becomes := str(idea_entry(id).get("becomes", "bench"))
		var node := Node2D.new()
		node.name = "Small_%s" % id
		node.set_meta("id", id)
		node.set_meta("becomes", becomes)
		if becomes == "lantern_post":
			node.position = Vector2(plot_rect("lantern_post").get_center().x, GROUND_Y)
		else:
			node.position = Vector2(SMALL_SLOTS[slot % SMALL_SLOTS.size()], GROUND_Y)
			slot += 1
			if becomes == "sign":
				_rect_under(node, Rect2(-3, -44, 6, 44), SMALL)
				_rect_under(node, Rect2(-18, -62, 36, 18), SMALL)
			else:
				_rect_under(node, Rect2(-20, -14, 40, 6), SMALL)
				_rect_under(node, Rect2(-16, -8, 4, 8), SMALL)
				_rect_under(node, Rect2(12, -8, 4, 8), SMALL)
		var label := str(names.get(becomes, names.get("default", "{name}"))).replace("{name}", str(idea_entry(id).get("name", id)))
		_label_under(node, label, Vector2(-60, -88), 120).name = "Name"
		small_things.add_child(node)


## The idea that became this kind of small thing, if any.
func _small_thing_for(becomes: String) -> String:
	for id in state.small_things:
		if str(idea_entry(id).get("becomes", "")) == becomes:
			return id
	return ""


## A person: a grey capsule standing at `at` (its feet), two eyes, the name
## over the head and, above that, the want line (shown at the table; on the
## street only after a talk).
func _capsule(c: Dictionary, at: Vector2, at_table: bool) -> Node2D:
	var who := str(c.get("id", ""))
	var node := Node2D.new()
	node.name = "%s_%s" % ["Seat" if at_table else "Person", who]
	node.position = at
	node.set_meta("id", who)
	var face := Node2D.new()   # the body and the eyes: what nods
	face.name = "Face"
	node.add_child(face)
	var body := Polygon2D.new()
	body.name = "Body"
	body.color = PERSON
	body.polygon = _stadium(CAPSULE)
	body.position = Vector2(-CAPSULE.x / 2.0, -CAPSULE.y)
	face.add_child(body)
	for i in 2:
		var eye := ColorRect.new()
		eye.name = "EyeL" if i == 0 else "EyeR"
		eye.color = EYE
		face.add_child(eye)
	_set_eyes(node, true)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = str(c.get("name", who))
	name_label.position = Vector2(-60, -CAPSULE.y - 26)
	name_label.size = Vector2(120, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(name_label)
	var want := Label.new()
	want.name = "Want"
	want.text = want_line.format({"name": str(c.get("name", who)), "want": str(c.get("want", ""))})
	want.position = Vector2(-180, -CAPSULE.y - 48)
	want.size = Vector2(360, 22)
	want.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	want.visible = at_table
	node.add_child(want)
	return node


## The points of a capsule (a stadium) `size` big, its top-left at the origin.
func _stadium(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := size.x / 2.0
	var steps := 8
	for i in steps + 1:   # the top half-circle, left to right
		var a := PI + PI * i / steps
		points.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
	for i in steps + 1:   # the bottom half-circle, right to left
		var a := PI * i / steps
		points.append(Vector2(r, size.y - r) + Vector2(cos(a), sin(a)) * r)
	return points


## Open eyes are 4 x 4 squares; shut eyes are 6 x 1 lines a little lower.
func _set_eyes(node: Node2D, open: bool) -> void:
	for i in 2:
		var eye: ColorRect = node.get_node("Face/EyeL" if i == 0 else "Face/EyeR")
		eye.size = Vector2(4, 4) if open else Vector2(6, 1)
		eye.position = Vector2(-9 + i * 10, -CAPSULE.y + 14) if open else Vector2(-10 + i * 10, -CAPSULE.y + 17)


func _want_label(node: Node2D) -> Label:
	return node.get_node("Want") as Label


## One idea as a white rect with a black edge and its name above (the
## dream's look, small), under `holder`.
func _add_piece(holder: Node2D, id: String, at: Vector2, index: int) -> Node2D:
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
	return piece


func _add_box(rect: Rect2, color: Color) -> ColorRect:
	return _rect_under(street, rect, color)


func _rect_under(holder: Node, rect: Rect2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	holder.add_child(box)
	return box


## An empty plot: four thin rects around the outline.
func _outline_under(holder: Node, rect: Rect2, color: Color) -> void:
	var t := 3.0
	_rect_under(holder, Rect2(rect.position, Vector2(rect.size.x, t)), color)
	_rect_under(holder, Rect2(rect.position + Vector2(0, rect.size.y - t), Vector2(rect.size.x, t)), color)
	_rect_under(holder, Rect2(rect.position, Vector2(t, rect.size.y)), color)
	_rect_under(holder, Rect2(rect.position + Vector2(rect.size.x - t, 0), Vector2(t, rect.size.y)), color)


func _add_label(text: String, at: Vector2, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return _label_under(street, text, at, width, align)


func _label_under(holder: Node, text: String, at: Vector2, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 22)
	label.horizontal_alignment = align
	holder.add_child(label)
	return label
