extends Node2D
## The street of Yawn by day (toy 4b, PINCH, the second loop): a side view
## four screens wide on one ground line. Three buildings stand (the Long
## House with the bunk, the table, the stove, the map on the wall and the
## tally wall; Jorun's hut; the stove shed) and three plots wait (Sixteen
## Stairs, Bo's loft, a lantern post). Two black rects mask the street
## beyond the lit tiles at each end; they recede one tile per building
## standing, read from the state. E at the bunk emits slept.
##
## THE PEOPLE (data/characters.json): Tove by the stove, Jorun by the Long
## House door, Bo by his plot; grey capsules with a name over the head. E
## within TALK_RANGE talks: the first unspoken memory line whose "if"
## flags hold (and no "unless" flag does; "repeat": true lines may be said
## again), else the greeting; talk() sets talked:<who>, which puts their
## branch on the wall. A character whose plot stands moves out and stands
## in front of it. THE REQUESTS: on a morning where a character's request
## "when" holds and it has not been asked, its line is said after the wake
## line and the flag asked:<id> is set (Tove's sends you to Bo's dream for
## the pills).
##
## THE WALL (wall.gd, WALL_AT): the map of the dream in the Long House,
## the hub and one row per talked-to villager, the goal named once
## reached, the rooms named as far as the map knows them; E within
## WALL_RANGE of WALL_X opens the picker (choose_dream: the shared panel's
## numbered choices over available_branches(), the talked-to villagers in
## branches.json order) and sets state.target, which the wall then names
## ("Tonight: Bo's dream") and the bunk needs: go_to_sleep refuses without
## a target while any branch exists (village.json wall.choose_first).
##
## THE DESK (desk.gd, SPEC-2 "The Desk, exactly"; day B, day C): every
## morning with an outline waiting on the desk (state.ideas_kept: the
## ideas reached, oldest first) or at least desk.MIN_CARDS scraps
## (state.scraps), after the wake line and the requests, the walker is
## put at the table and the Desk is drawn there: the idea's outline
## (branches.json "slots"; scraps.json's blank outline with no idea) with
## the slots an earlier morning filled already filled (state.outlines),
## the scraps as cards, the light draining from the Long House window for
## desk.BLUE_HOUR seconds. 1 2 3 (4 5 6) picks a card, A D moves the hand
## along the slots, E fits it (fit: a matching shape fills the slot, uses
## the card and is kept in the state at once; a wrong one costs five
## seconds, the walker shakes: fumble). The Desk ends when the light goes,
## every slot is filled, or the walker is DESK_RANGE px from the table
## (end_desk). NOTHING IS LOST (day C): an outline not yet complete stays
## on the desk with what is filled (the "kept" line, action desk_kept),
## morning after morning; the thing is DEVELOPED the moment the last slot
## fills (develop), in full only: a building (branches.json develops
## "building": Sixteen Stairs) is claimed for its plot (state.claim: a
## scaffold today with its crossbars, standing tomorrow with a lit window)
## and its owner moves out; the pill raises the limit for every night
## after (state.develop_pill: +2) and a jar is kept by the bunk; the
## lantern names every room on the wall (state.lantern) and hangs lit by
## the Long House door (its light fades in as a new window's does). With
## no outline, three scraps fitted to the blank outline reveal one more
## room on a branch of the player's choice (choose_branch, the picker;
## state.reveal). Leftover cards are kept as scraps, up to the state's
## cap. A development is said as two lines: the desk's line (village.json
## "desk"), then the idea's own (ideas.json "line") DEVELOP_GAP seconds
## later, while the desk stays drawn through its developed show (the
## outline flashing under the thing's name, desk.DEVELOPED_SHOWS seconds)
## and goes after. Milestones go through acted: desk_full, desk_reveal
## (and desk start / light / filled / walked, desk_kept, fit, fumble as
## actions).
##
## THE FEEL, drawn only, every number a constant below: the lit window of
## a building that stands this morning (lit_today, set by the controller)
## fades in over WINDOW_FADE seconds, and so does the lantern's light the
## morning it is developed; a scaffold's crossbars appear one every
## CROSSBAR_EVERY seconds after the claim; the scraps lost at a sudden
## waking float over the bunk and fade (fade_lost). Lines are said through
## the shared text panel (the controller's, or one of its own when run
## alone): say_for shows one for some seconds, queued behind the one
## showing unless `now`. THE DEV BAR (devbar.gd, data/devbar.json): a
## strip along the bottom listing ONLY what can be done now
## (devbar_text()); Tab toggles it (state.devbar_visible, kept for the
## session). LABELS (PinchLabel) sit on dark backings. Every word on screen
## comes from data/village.json and data/characters.json, idea names from
## data/ideas.json, room names from data/rooms.json; rewrite those.
##
## Gone with day B (the first loop's leftovers): breakfast and its faces,
## want lines, claims, head drops and small things; the stove shed's
## making and the pill at the bunk; the taller hat; the ideas on the table.
## Gone with day C: the weak grade and the "nothing" grade of the Desk
## (the small building, the +1 pill, the one-branch lantern).

signal slept
signal acted(kind: String, detail: String)

const WORDS_FILE := "res://prototypes/pinch/data/village.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const DEVBAR_FILE := "res://prototypes/pinch/data/devbar.json"
const BRANCHES_FILE := "res://prototypes/pinch/data/branches.json"
const SCRAPS_FILE := "res://prototypes/pinch/data/scraps.json"
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const PANEL := preload("res://prototypes/_shared/text_panel.tscn")
const DEVBAR := preload("res://prototypes/pinch/devbar.gd")
const WALL_MAP := preload("res://prototypes/pinch/wall.gd")
const DESK := preload("res://prototypes/pinch/desk.gd")
const WALL_AT := Vector2(2124, 290)   # the map's top-left corner, on the Long House wall above the table
const WALL_X := 2180.0                # px: where the walker stands to read the wall: at the table, under the map (clear of the bunk, the stove and Tove)
const WALL_RANGE := 48.0              # px: this close to WALL_X, E chooses tonight's dream
const TALLY_AT := Vector2(2400, 316)  # the tally's title, over the bunk; the marks one line under it
const LOST_FADE := 6.0           # s the lost stack takes to fade over the bunk
const PIECE := Vector2(32, 24)   # px: one lost thing as a rect over the bunk
const STREET_WIDTH := 4608.0   # px: four screens of 1152
const STREET_HEIGHT := 648.0   # px: one screen; the camera never scrolls up or down
const GROUND_Y := 540.0        # px: the ground line
const BUNK_RANGE := 48.0       # px: this close to the bunk's middle, E sleeps
const TALK_RANGE := 40.0       # px: this close to a character's feet, E talks
const DESK_RANGE := 140.0      # px from the table's middle: further, and the Desk is walked away from
const LINE_STAYS := 3.0        # s a line stays on screen
const DEVELOP_GAP := 1.5       # s the desk's line shows before the idea's own line follows it
const REQUEST_STAYS := 6.0     # s a request line stays
const WINDOW_FADE := 1.5       # s a new building's lit window (and the lantern's light) takes to fade in
const CROSSBAR_EVERY := 1.0    # s between a scaffold's crossbars appearing after the claim
const CAPSULE := Vector2(26, 52)
const PIECE_LABEL_WIDTH := 240.0 # px: a lost thing's name over its rect
const PIECE_LABEL_ROWS := 3      # neighbouring pieces' names at this many heights, so none share a line
const PIECE_LABEL_STEP := 18.0
const THING_LABEL_WIDTH := 160.0
const PLOT_LABEL_WIDTH := 220.0
const WINDOW := Vector2(18, 22)
const LANTERN_X := 2084.0        # px: the lantern just inside the Long House door, left of the table
const LANTERN_POST := Vector2(8, 60)
const LANTERN_LAMP := Vector2(20, 24)
const PILLS_JAR := Vector2(10, 14)
const WALL := Color(0.5, 0.5, 0.5)
const MARKER := Color(0.72, 0.72, 0.72)
const OUTLINE := Color(0.42, 0.42, 0.42)
const SCAFFOLD := Color(0.6, 0.6, 0.6)
const PERSON := Color(0.66, 0.66, 0.68)
const EYE := Color(0.12, 0.12, 0.14)
const WINDOW_LIT := Color(1.0, 0.9, 0.45)
const THING := Color(0.58, 0.58, 0.6)
const JAR := Color(0.82, 0.82, 0.86)

# The street, left to right: [kind, id, x, width, height]; buildings stand, plots wait.
const LAYOUT := [
	["plot", "sixteen_stairs", 1560.0, 200.0, 160.0],
	["building", "jorun_hut", 1800.0, 240.0, 180.0],
	["building", "long_house", 2074.0, 460.0, 260.0],   # its middle is the street's middle, 2304
	["building", "stove_shed", 2580.0, 160.0, 140.0],
	["plot", "bos_loft", 2800.0, 200.0, 200.0],
	["plot", "lantern_post", 3030.0, 30.0, 220.0],
]
const TABLE := Rect2(2130, 490, 90, 50)   # inside the Long House, left: the Desk by day
const STOVE := Rect2(2290, 504, 40, 36)   # inside the Long House, the middle
const BUNK := Rect2(2400, 500, 70, 40)    # inside the Long House, right
const DOOR_X := 2056.0                    # outside the Long House's left wall: where Jorun stands

@onready var walker: CharacterBody2D = $Walker
@onready var walker_body: ColorRect = $Walker/Body
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
var branches: Array = []      # branches.json "branches", in order
var scrap_shapes: Array = []  # scraps.json "shapes"
var scrap_outline: Dictionary = {}   # scraps.json "outline": the blank outline for scraps alone
var room_names := {}          # room id -> name, from rooms.json (the wall names them)
var tally_wall: Label = null  # the marks on the Long House wall, one per sudden waking
var wall: Node2D = null       # the map on the wall (wall.gd)
var desk: Node2D = null       # the Desk at the table (desk.gd), while it is on
var desk_on := false
var picking_target := false   # the wall's picker is up: the keys are its
var picking_branch := false   # the Desk's branch picker is up
var table_label: Label = null # the table's word, hidden while the Desk is on
var devbar: CanvasLayer = null     # the dev bar: what can be done now
var devbar_words: Dictionary = {}  # devbar.json
var devbar_visible := true         # Tab toggles it; mirrored in state.devbar_visible
var lost_stack: Node2D = null    # the scraps lost at waking, fading over the bunk; null when none
var plots: Node2D = null         # the plots as they stand today: outline, scaffold or building
var things: Node2D = null        # the developed things on the street: the pills' jar, the lantern
var people_node: Node2D = null   # the characters on the street
var people := {}                 # who -> Node2D (a capsule on the street)
var plot_nodes := {}             # plot id -> Node2D drawn for it
var _slept := false
var _lost_left := 0.0
var _lines: Array = []           # [text, seconds] waiting behind the line showing
var _line_left := 0.0            # s the line showing has left; 0: nothing showing
var _day_time := 0.0             # s since this morning began
var _claimed_at := {}            # plot id -> _day_time of its claim at the Desk (the crossbars count from it)
var _lantern_lit_at := -1.0      # _day_time the lantern was developed this morning; -1 when not this morning
var _body_x := 0.0               # the walker's body rect x when still (the fumble's shake moves it)


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
	loaded = PinchState.load_json(DEVBAR_FILE)
	devbar_words = loaded if loaded is Dictionary else {}
	loaded = PinchState.load_json(BRANCHES_FILE)
	branches = (loaded as Dictionary).get("branches", []) if loaded is Dictionary else []
	loaded = PinchState.load_json(SCRAPS_FILE)
	var scraps_json: Dictionary = loaded if loaded is Dictionary else {}
	scrap_shapes = scraps_json.get("shapes", [])
	scrap_outline = scraps_json.get("outline", {})
	loaded = PinchState.load_json(ROOMS_FILE)
	for entry in (loaded as Dictionary).get("rooms", []) if loaded is Dictionary else []:
		room_names[str(entry.get("id", ""))] = str(entry.get("name", entry.get("id", "")))
	if panel == null:
		panel = PANEL.instantiate()
		add_child(panel)
	_body_x = walker_body.position.x
	_build_street()
	_build_wall()
	_build_people()
	_build_devbar()
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
	if desk_on:
		desk.tick(delta)
		walker_body.position.x = _body_x + desk.shake_offset()
		if desk.light_gone():
			end_desk("light")
		elif absf(walker.position.x - TABLE.get_center().x) > DESK_RANGE:
			end_desk("walked")
	elif desk != null and not desk.developing():
		_free_desk()   # the developed show is over: the desk goes
	_update_prompt()
	devbar.set_actions(devbar_text())


func _unhandled_input(event: InputEvent) -> void:
	if picking_target or picking_branch:
		return   # a picker is up: the number keys are the panel's
	if event.is_action_pressed("devbar_toggle"):
		toggle_devbar()
	elif desk_on:
		if event.is_action_pressed("interact"):
			fit()
		elif event.is_action_pressed("move_left"):
			desk.move(-1)
		elif event.is_action_pressed("move_right"):
			desk.move(1)
		else:
			var index := _card_key(event)
			if index >= 0:
				pick_card(index)
	elif event.is_action_pressed("interact"):
		if bunk_in_range():
			go_to_sleep()
		elif wall_in_range():
			choose_dream()
		else:
			var who := character_in_reach()
			if who != "":
				talk(who)


## The card a key picks: 1 2 3 are the panel's choice actions, 4 5 6 the keys themselves; -1 for any other event.
func _card_key(event: InputEvent) -> int:
	for i in 3:
		if event.is_action_pressed("choice_%d" % (i + 1)):
			return i
	if event is InputEventKey and event.pressed and not event.echo:
		var keys := [KEY_4, KEY_5, KEY_6]
		var index := keys.find(event.physical_keycode)
		if index < 0:
			index = keys.find(event.keycode)
		if index >= 0:
			return 3 + index
	return -1


# --- the street ----------------------------------------------------------------

## Re-reads the state: the day label, the tally wall, the plots, the
## things, where the people stand, the wall, the dark at each end.
func refresh() -> void:
	day_label.text = str(words.get("day_label", "{day}")).format({"day": state.day})
	PinchLabel.set_text(tally_wall, str(words.get("tally_mark", "|")).repeat(state.tally))
	_draw_plots()
	_draw_things()
	_place_people()
	wall.refresh(state)
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


func wall_in_range() -> bool:
	return absf(walker.position.x - WALL_X) <= WALL_RANGE


## The name of an idea, from ideas.json.
func idea_name(id: String) -> String:
	return str(idea_entry(id).get("name", id))


## The ideas.json entry of an idea; {} if there is none.
func idea_entry(id: String) -> Dictionary:
	for idea in ideas:
		if str(idea.get("id", "")) == id:
			return idea
	return {}


## The branches.json entry whose idea this is; {} if none.
func branch_for_idea(id: String) -> Dictionary:
	for branch in branches:
		if str(branch.get("idea", "")) == id:
			return branch
	return {}


## A villager's branch from branches.json; {} when they have none.
func branch_of(who: String) -> Dictionary:
	for branch in branches:
		if str(branch.get("who", "")) == who:
			return branch
	return {}


## The name of a scrap's shape, from scraps.json.
func scrap_name(shape: String) -> String:
	return str(scrap_names().get(shape, shape))


## shape id -> name, from scraps.json.
func scrap_names() -> Dictionary:
	var names := {}
	for entry in scrap_shapes:
		names[str(entry.get("id", ""))] = str(entry.get("name", entry.get("id", "")))
	return names


## The name of a thing carried up from the dream: a scrap's ("scrap:<shape>"), or an idea's.
func thing_name(id: String) -> String:
	if id.begins_with("scrap:"):
		return scrap_name(id.substr(6))
	return idea_name(id)


## The rect of a plot or a building of the LAYOUT, on the street.
func plot_rect(id: String) -> Rect2:
	for entry in LAYOUT:
		if entry[1] == id:
			return Rect2(entry[2], GROUND_Y - entry[4], entry[3], entry[4])
	return Rect2()


## What stands on a plot today: "empty", "scaffold" (claimed at the Desk) or "built".
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


## The node drawn for a developed thing on the street ("pills", "lantern"), or null.
func thing_node(id: String) -> Node2D:
	return things.get_node_or_null("Thing_%s" % id) as Node2D


## The scraps lost at a sudden waking: a stack over the bunk, one rect per
## thing, fading away over LOST_FADE seconds.
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


## Lie down: emits slept once; the controller takes it from there. Without
## a target while a branch exists (SPEC-2) the bunk refuses: choose first.
func go_to_sleep() -> void:
	if _slept or desk_on:
		return
	if not sleep_allowed():
		say_for(str(words.get("wall", {}).get("choose_first", "")), LINE_STAYS, true)
		acted.emit("refused", "no_target")
		return
	_slept = true
	slept.emit()


## True when tonight has a target, or no branch exists yet (the hub alone is the night).
func sleep_allowed() -> bool:
	return state.target != "" or available_branches().is_empty()


# --- the wall --------------------------------------------------------------------

## The branches the wall shows and the pickers offer: the talked-to
## villagers' (flag talked:<who>), in branches.json order.
func available_branches() -> Array[String]:
	var whos: Array[String] = []
	for branch in branches:
		var who := str(branch.get("who", ""))
		if state.has_flag("talked:%s" % who):
			whos.append(who)
	return whos


## E at the wall: the picker over the available branches (1 2 3, or a
## click); the choice is tonight's target. With no branch yet, the note.
func choose_dream() -> void:
	if picking_target or picking_branch or _slept or desk_on:
		return
	var whos := available_branches()
	if whos.is_empty():
		say_for(str(words.get("wall", {}).get("talk_first", "")), LINE_STAYS, true)
		return
	picking_target = true
	_lines = []
	_line_left = 0.0
	panel.say(str(words.get("wall", {}).get("choose", "")))
	panel.prompt(str(words.get("wall", {}).get("pick", "")))
	var options: Array[String] = []
	for who in whos:
		options.append(str(character(who).get("name", who)))
	panel.choices(options)
	acted.emit("wall", "open")
	var index: int = await panel.chosen
	picking_target = false
	panel.prompt("")
	set_target(whos[index])


## Tonight's dream is `who`'s: the state knows, the wall names it, the line is said.
func set_target(who: String) -> void:
	state.target = who
	wall.refresh(state)
	say_for(str(words.get("wall", {}).get("chosen", "")).format({"name": str(character(who).get("name", who))}), LINE_STAYS, true)
	acted.emit("target", who)


func _build_wall() -> void:
	var idea_names := {}
	for idea in ideas:
		idea_names[str(idea.get("id", ""))] = str(idea.get("name", idea.get("id", "")))
	var villager_names := {}
	for c in characters:
		villager_names[str(c.get("id", ""))] = str(c.get("name", c.get("id", "")))
	wall = WALL_MAP.new()
	wall.name = "Wall"
	wall.position = WALL_AT
	wall.setup(words.get("wall", {}), branches, villager_names, idea_names, room_names)
	street.add_child(wall)


# --- the Desk --------------------------------------------------------------------

## Whether this morning has a Desk: an outline waiting, or scraps enough, and not yet today.
func desk_due() -> bool:
	return state.desk_done_day != state.day and (not state.ideas_kept.is_empty() or state.scraps.size() >= DESK.MIN_CARDS)


## The idea on the desk this morning (the oldest reached and not yet
## developed; "" for scraps alone), its outline's slots, and the slots
## filled on earlier mornings (day C: laid in the state the first time).
func desk_outline() -> Dictionary:
	if not state.ideas_kept.is_empty():
		var idea: String = state.ideas_kept[0]
		var slots: Array = branch_for_idea(idea).get("slots", [])
		return {"idea": idea, "name": idea_name(idea), "slots": slots, "filled": state.outline_filled(idea, slots.size()).duplicate()}
	return {"idea": "", "name": str(scrap_outline.get("name", "")), "slots": scrap_outline.get("slots", ["any", "any", "any"]), "filled": []}


## The walker at the table, the outline, the cards, the light: the blue hour begins.
func start_desk() -> void:
	if desk_on or _slept or not desk_due():
		return
	_free_desk()
	var outline := desk_outline()
	desk_on = true
	walker.position.x = TABLE.get_center().x
	walker.velocity = Vector2.ZERO
	desk = DESK.new()
	desk.name = "Desk"
	desk.position = TABLE.position
	desk.setup(str(outline.idea), str(outline.name), outline.slots, state.scraps, words.get("desk", {}), scrap_names(), outline.filled)
	street.add_child(desk)
	table_label.visible = false
	var before: int = desk.filled_count()
	var key := "begin_blank" if outline.idea == "" else ("begin_again" if before > 0 else "begin")
	say_for(str(words.get("desk", {}).get(key, "")).format({"name": str(outline.name), "filled": before, "total": outline.slots.size()}), LINE_STAYS)
	acted.emit("desk", "start")


## 1 2 3 (4 5 6): a card in the hand.
func pick_card(index: int) -> bool:
	if not desk_on or not desk.pick_card(index):
		return false
	acted.emit("pick", str(desk.cards[index]))
	return true


## E at the Desk: the picked card into the slot under the hand (desk.fit);
## a fumble is said and shakes the walker; the last slot filled ends the Desk.
func fit() -> String:
	if not desk_on:
		return ""
	var result: String = desk.fit()
	if result == "fit":
		if desk.idea != "":
			state.fill_slot(desk.idea, desk.hand, desk.filled[desk.hand])   # kept at once: nothing is lost
		acted.emit("fit", desk.filled[desk.hand])
		if desk.complete():
			end_desk("filled")
	elif result == "fumble":
		say_for(str(words.get("desk", {}).get("fumble", "")), LINE_STAYS, true)
		acted.emit("fumble", desk.picked_shape())
	return result


## The Desk is over, for `reason` ("light": the blue hour ended; "filled":
## every slot; "walked": the walker left the table): a complete outline is
## developed (the desk stays drawn through its developed show), an
## incomplete one waits on the desk with what is filled, or the scraps
## alone reveal a room; the leftover cards are kept as scraps, up to the
## state's cap.
func end_desk(reason: String) -> void:
	if not desk_on:
		return
	desk_on = false
	state.desk_done_day = state.day
	var idea: String = desk.idea
	var filled: int = desk.filled_count()
	var total: int = desk.slots.size()
	var leftovers: Array[String] = desk.cards_left()
	state.scraps.assign(leftovers.slice(0, PinchState.KEEP_SCRAPS))
	walker_body.position.x = _body_x
	table_label.visible = true
	acted.emit("desk", reason)
	if reason == "walked":
		say_for(str(words.get("desk", {}).get("walked", "")), LINE_STAYS, true)
	if idea != "":
		if filled == total:
			desk.show_developed(idea_name(idea))   # the node stays through the show; _process takes it away after
			develop(idea)
		else:
			_free_desk()
			say_for(str(words.get("desk", {}).get("kept", "")).format({"name": idea_name(idea), "filled": filled, "total": total}), LINE_STAYS, reason != "walked")
			acted.emit("desk_kept", "%s:%d/%d" % [idea, filled, total])
	elif filled >= total:
		_free_desk()
		var who := await choose_branch()
		if who != "":
			state.reveal(who, branch_of(who).get("rooms", []).size())
			say_for(str(words.get("desk", {}).get("reveal", "")).format({"name": str(character(who).get("name", who))}), LINE_STAYS, true)
			acted.emit("desk_reveal", who)
	else:
		_free_desk()
		say_for(str(words.get("desk", {}).get("reveal_none", "")), LINE_STAYS, true)
	refresh()


## The desk node goes (after its show, or at once).
func _free_desk() -> void:
	if desk == null:
		return
	var node := desk
	desk = null
	street.remove_child(node)
	node.queue_free()


## The idea developed, in full (every slot of its outline filled): the
## building claimed, the pill kept, the lantern lit; the outline leaves
## the desk (state.develop); the two lines; the milestone.
func develop(idea: String) -> void:
	var desk_words: Dictionary = words.get("desk", {})
	var entry := idea_entry(idea)
	var shown := idea_name(idea)
	match str(branch_for_idea(idea).get("develops", "")):
		"building":
			var plot := str(entry.get("becomes", ""))
			if plot_rect(plot).size != Vector2.ZERO:
				state.claim(plot, idea)
				_claimed_at[plot] = _day_time
		"pill":
			state.develop_pill()
		"lantern":
			state.lantern = true
			_lantern_lit_at = _day_time
	state.develop(idea)
	say_for(str(desk_words.get("full", "")).format({"name": shown}), DEVELOP_GAP, true)   # the desk's line first...
	say_for(str(entry.get("line", "")), LINE_STAYS)   # ...then the idea's own line, DEVELOP_GAP later
	acted.emit("desk_full", idea)


## The picker over the branches on the wall: which one grows a room (the
## reveal). Returns the villager chosen, "" with no branch.
func choose_branch() -> String:
	var whos := available_branches()
	if whos.is_empty():
		return ""
	picking_branch = true
	_lines = []
	_line_left = 0.0
	panel.say(str(words.get("desk", {}).get("choose_branch", "")))
	panel.prompt(str(words.get("desk", {}).get("pick", "")))
	var options: Array[String] = []
	for who in whos:
		options.append(str(character(who).get("name", who)))
	panel.choices(options)
	var index: int = await panel.chosen
	picking_branch = false
	panel.prompt("")
	return whos[index]


# --- the feel --------------------------------------------------------------------

## The window of a building that stands since this morning: 0 at the
## start, 1 after WINDOW_FADE seconds.
func window_alpha(plot: String) -> float:
	if not lit_today.has(plot):
		return 1.0
	return clampf(_day_time / WINDOW_FADE, 0.0, 1.0)


## The lantern's light: fading in over WINDOW_FADE seconds from the moment
## it was developed this morning; 1 on every morning after; 0 without it.
func lantern_alpha() -> float:
	if not state.lantern:
		return 0.0
	if _lantern_lit_at < 0.0:
		return 1.0
	return clampf((_day_time - _lantern_lit_at) / WINDOW_FADE, 0.0, 1.0)


## How many of a scaffold's crossbars show: one more every CROSSBAR_EVERY
## seconds since the claim; all of them for a scaffold claimed before this
## morning (none is: claims stand the next day).
func crossbars_shown(plot: String) -> int:
	var node := plot_node(plot)
	if node == null or not _claimed_at.has(plot):
		return _count_bars(node) if node != null else 0
	return mini(int((_day_time - float(_claimed_at[plot])) / CROSSBAR_EVERY), _count_bars(node))


func _count_bars(node: Node2D) -> int:
	var n := 0
	for child in node.get_children():
		if child.has_meta("bar"):
			n += 1
	return n


## Every drawn frame: the new windows and the lantern fade in, the crossbars appear.
func _draw_feel(_delta: float) -> void:
	for plot in lit_today:
		var node := plot_node(plot)
		if node != null and node.has_node("Window"):
			node.get_node("Window").modulate.a = window_alpha(plot)
	var lantern := thing_node("lantern")
	if lantern != null and lantern.has_node("Lamp"):
		lantern.get_node("Lamp").modulate.a = lantern_alpha()
	for plot in _claimed_at:
		var node := plot_node(plot)
		if node == null:
			continue
		var shown := crossbars_shown(plot)
		for child in node.get_children():
			if child.has_meta("bar"):
				child.visible = int(child.get_meta("bar")) < shown


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

## The requests whose time has come, then the Desk if there is anything to work on.
func _morning() -> void:
	for c in characters:
		var request: Dictionary = c.get("request", {})
		if request.is_empty():
			continue
		var id := str(request.get("id", ""))
		if state.has_flag("asked:%s" % id) or not state.holds(request.get("when", [])):
			continue
		state.set_flag("asked:%s" % id)
		say_for(str(request.get("text", "")), REQUEST_STAYS)
		acted.emit("request", id)
	if desk_due():
		start_desk()


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


## The character nearest the walker within TALK_RANGE.
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


## E next to a character: the line, the memory (talked:<who> puts their branch on the wall).
func talk(who: String) -> String:
	var c := character(who)
	if c.is_empty():
		return ""
	var line := line_for(who)
	if str(line.get("id", "")) != "greeting":
		state.set_flag(_said_flag(who, line))
	state.set_flag("talked:%s" % who)
	wall.refresh(state)
	say_for(str(line.get("text", "")), LINE_STAYS, true)
	acted.emit("talk", who)
	return str(line.get("text", ""))


func _said_flag(who: String, line: Dictionary) -> String:
	return "said:%s:%s" % [who, str(line.get("id", ""))]


# --- the prompt over the walker --------------------------------------------------

func _update_prompt() -> void:
	var text := ""
	if _slept or desk_on or picking_target or picking_branch:
		pass
	elif bunk_in_range():
		text = str(words.get("sleep_prompt", ""))
	elif wall_in_range():
		text = str(words.get("wall_prompt", ""))
	elif character_in_reach() != "":
		text = str(words.get("talk_prompt", ""))
	prompt_label.text = text
	prompt_label.visible = text != ""


# --- the dev bar -----------------------------------------------------------------

## ONLY what can be done right now, in devbar.json's words: at the Desk,
## pick a card, or move the hand and fit the picked one, and walk away;
## at a picker, the numbers; else walk, and sleep at the bunk, choose at
## the wall, or talk by a character. Nothing once asleep.
func devbar_text() -> String:
	if _slept:
		return ""
	var w: Dictionary = devbar_words.get("street", {})
	if picking_target:
		return str(w.get("wall_pick", ""))
	if picking_branch:
		return str(w.get("desk_branch", ""))
	if desk_on:
		if desk.picked_shape() == "":
			return str(w.get("desk_pick", ""))
		return str(w.get("desk", "")).format({"card": desk.picked_name()})
	var parts: Array[String] = [str(w.get("walk", ""))]
	if bunk_in_range():
		parts.append(str(w.get("sleep" if sleep_allowed() else "sleep_refused", "")))
	elif wall_in_range():
		parts.append(str(w.get("wall", "")))
	elif character_in_reach() != "":
		parts.append(str(w.get("talk", "")))
	return str(devbar_words.get("separator", " · ")).join(parts)


func toggle_devbar() -> void:
	devbar_visible = not devbar_visible
	state.devbar_visible = devbar_visible
	devbar.visible = devbar_visible
	acted.emit("devbar", "on" if devbar_visible else "off")


func _build_devbar() -> void:
	devbar = DEVBAR.new()
	devbar.name = "DevBar"
	add_child(devbar)
	devbar.set_toggle_word(str(devbar_words.get("toggle", "")))
	devbar_visible = state.devbar_visible
	devbar.visible = devbar_visible
	devbar.set_actions(devbar_text())


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
	table_label = _add_label(str(markers.get("table", "")), _inside(TABLE), TABLE.size.x)
	_add_box(STOVE, MARKER)
	_add_label(str(markers.get("stove", "")), _inside(STOVE) - Vector2(30, 0), STOVE.size.x + 60)
	_add_box(BUNK, MARKER)
	_add_label(str(markers.get("bunk", "")), _inside(BUNK), BUNK.size.x)
	_add_label(str(words.get("tally_title", "")), TALLY_AT, 130.0, HORIZONTAL_ALIGNMENT_LEFT)
	tally_wall = _add_label("", TALLY_AT + Vector2(0, 24), 130.0, HORIZONTAL_ALIGNMENT_LEFT)
	plots = _holder("Plots")
	things = _holder("Things")
	people_node = _holder("People")


func _holder(holder_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = holder_name
	street.add_child(holder)
	return holder


## Where a marker's word sits: inside its box, one line tall, vertically centred.
func _inside(rect: Rect2) -> Vector2:
	return Vector2(rect.position.x, rect.position.y + (rect.size.y - PinchLabel.LINE) / 2.0)


func _build_people() -> void:
	for c in characters:
		var who := str(c.get("id", ""))
		var person := _capsule(c, Vector2(stand_x(who), GROUND_Y))
		people_node.add_child(person)
		people[who] = person


func _place_people() -> void:
	for who in people:
		people[who].position.x = stand_x(who)


## The plots as they stand: an outline and the plot's name; a scaffold (the
## outline, two crossbars, a diagonal, "scaffold"); or the building (a
## filled rect, a lit window, the idea's name).
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
		var label_at := Vector2((rect.size.x - PLOT_LABEL_WIDTH) / 2.0, -26)
		if what == "built":
			var body := Rect2(Vector2.ZERO, rect.size)
			_rect_under(node, body, WALL)
			var window := _rect_under(node, Rect2(Vector2(rect.size.x / 2.0 - WINDOW.x / 2.0, body.position.y + rect.size.y * 0.3), WINDOW), WINDOW_LIT)
			window.name = "Window"
			window.modulate.a = window_alpha(id)
			_label_under(node, idea_name(str(state.ideas_built[id])), label_at + Vector2(0, body.position.y), PLOT_LABEL_WIDTH).name = "Name"
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
			_label_under(node, str(markers.get("scaffold", "")), label_at, PLOT_LABEL_WIDTH).name = "Name"
		else:
			_outline_under(node, local, OUTLINE)
			_label_under(node, str(plot_names.get(id, id)), label_at, PLOT_LABEL_WIDTH).name = "Name"
		plots.add_child(node)
		plot_nodes[id] = node


## The developed things on the street: the pills' jar by the bunk once a
## pill is developed; the lantern by the Long House door once the lantern
## is developed in full (its lamp fades in, lantern_alpha), just inside
## the door, left of the table. Labelled from
## village.json "things".
func _draw_things() -> void:
	for thing in things.get_children():
		things.remove_child(thing)
		thing.queue_free()
	var names: Dictionary = words.get("things", {})
	if state.pill_bonus > 0:
		var jar := Node2D.new()
		jar.name = "Thing_pills"
		jar.position = Vector2(BUNK.position.x + 4.0, BUNK.position.y)
		_rect_under(jar, Rect2(Vector2(0, -PILLS_JAR.y), PILLS_JAR), JAR)
		_label_under(jar, str(names.get("pills", "")), Vector2(PILLS_JAR.x / 2.0 - THING_LABEL_WIDTH / 2.0, -PILLS_JAR.y - 24.0), THING_LABEL_WIDTH).name = "Name"
		things.add_child(jar)
	if state.lantern:
		var lantern := Node2D.new()
		lantern.name = "Thing_lantern"
		lantern.position = Vector2(LANTERN_X, GROUND_Y)
		_rect_under(lantern, Rect2(Vector2(-LANTERN_POST.x / 2.0, -LANTERN_POST.y), LANTERN_POST), THING)
		var lamp := _rect_under(lantern, Rect2(Vector2(-LANTERN_LAMP.x / 2.0, -LANTERN_POST.y - LANTERN_LAMP.y), LANTERN_LAMP), WINDOW_LIT)
		lamp.name = "Lamp"
		lamp.modulate.a = lantern_alpha()
		_label_under(lantern, str(names.get("lantern", "")), Vector2(-THING_LABEL_WIDTH / 2.0, -LANTERN_POST.y - LANTERN_LAMP.y - 26.0), THING_LABEL_WIDTH).name = "Name"
		things.add_child(lantern)


## A person: a grey capsule standing at `at` (its feet), two eyes, the name over the head.
func _capsule(c: Dictionary, at: Vector2) -> Node2D:
	var who := str(c.get("id", ""))
	var node := Node2D.new()
	node.name = "Person_%s" % who
	node.position = at
	node.set_meta("id", who)
	var face := Node2D.new()   # the body and the eyes
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
		eye.size = Vector2(4, 4)
		eye.position = Vector2(-9 + i * 10, -CAPSULE.y + 14)
		face.add_child(eye)
	var name_label := PinchLabel.make(str(c.get("name", who)), Vector2(-60, -CAPSULE.y - 26), 120)
	name_label.name = "Name"
	node.add_child(name_label)
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


## One lost thing as a white rect with a black edge and its name above
## (the dream's look, small), under `holder`; the `index`-th of a row has
## its name at one of PIECE_LABEL_ROWS heights, so neighbours' never share a line.
func _add_piece(holder: Node2D, id: String, at: Vector2, index: int) -> Node2D:
	var piece := Node2D.new()
	piece.name = "Piece_%s" % id.replace(":", "_")
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
	var label := PinchLabel.make(thing_name(id), Vector2(PIECE.x / 2.0 - PIECE_LABEL_WIDTH / 2.0, -24 - (index % PIECE_LABEL_ROWS) * PIECE_LABEL_STEP), PIECE_LABEL_WIDTH)
	label.name = "Name"
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


## A one-line word on a dark backing (PinchLabel), `width` wide at `at`.
func _label_under(holder: Node, text: String, at: Vector2, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := PinchLabel.make(text, at, width, align)
	holder.add_child(label)
	return label
