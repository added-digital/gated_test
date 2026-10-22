extends Node
## Toy 4b, PINCH (rung 3, the second loop): the controller. Holds the one
## PinchState and the harness, shows the village by day and the dream by
## night, and handles waking. The dream's reached(who, idea) marks the
## villager's branch reached (state.reach: the idea is kept for the Desk,
## the wall names it; milestones reached:<who>, kept:<idea>) and its
## woke(false, scraps) follows at once. Gentle wakings (the idea reached,
## the self-pinch: milestone self_pinch, not on the tally; the first
## loop's bed, dealt by hand) keep every scrap (state.keep_scrap, up to
## the state's cap: the rest are lost); a sudden waking marks the tally
## and keeps ONE scrap through the picker when two or more were carried
## (names from data/scraps.json; shown only once the dream's frame has
## been shut its SHUT seconds, since woke fires after that), and the rest
## fade over the bunk (the village draws them). Then the day moves on
## (state.new_day: the ideas developed at yesterday's Desk are standing,
## milestone built:<plot>) and the village comes back with the wake line
## first (village.json wake_reached, wake_self, wake_gentle,
## wake_sudden_scrap, wake_sudden_none) and then whatever the morning
## brings (a request, the Desk: village.gd); the plots raised this
## morning are handed over so their windows fade in. The village's doings
## (talk:<who>, target, desk, fit, fumble, desk_kept, desk_full /
## desk_reveal: milestones desk_full:<idea>, desk_reveal:<who>) go to the
## harness here. Every word the player reads
## comes from data/village.json, data/characters.json, data/ideas.json
## and data/scraps.json; rewrite those, not this.

const VILLAGE := preload("res://prototypes/pinch/village.tscn")
const DREAM := preload("res://prototypes/pinch/dream.tscn")
const VILLAGE_FILE := "res://prototypes/pinch/data/village.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const SCRAPS_FILE := "res://prototypes/pinch/data/scraps.json"
const LINE_STAYS := 3.0   # s a waking line stays on screen after the village returns

@onready var panel: CanvasLayer = $TextPanel
@onready var harness: Node = $Harness
@onready var blackout: ColorRect = $Night/Blackout

var state := PinchState.new()
var words: Dictionary = {}   # village.json
var ideas: Array = []        # ideas.json, in order
var scrap_shapes: Array = [] # scraps.json "shapes"
var _reached_idea := ""      # the idea reached this night, for the wake line
var _self_pinched := false   # the night ended by the self-pinch
var village: Node2D = null   # the street, by day
var dream: Node2D = null     # the dream, by night
var picking := false         # the keep-one picker is up


func _ready() -> void:
	var loaded: Variant = PinchState.load_json(VILLAGE_FILE)
	words = loaded if loaded is Dictionary else {}
	loaded = PinchState.load_json(IDEAS_FILE)
	ideas = loaded if loaded is Array else []
	loaded = PinchState.load_json(SCRAPS_FILE)
	scrap_shapes = (loaded as Dictionary).get("shapes", []) if loaded is Dictionary else []
	harness.start("pinch")
	_show_village()


func get_state() -> PinchState:
	return state


## The name of an idea, from ideas.json.
func idea_name(id: String) -> String:
	for idea in ideas:
		if idea.get("id", "") == id:
			return str(idea.get("name", id))
	return id


## The name of a scrap's shape, from scraps.json.
func scrap_name(shape: String) -> String:
	for entry in scrap_shapes:
		if str(entry.get("id", "")) == shape:
			return str(entry.get("name", shape))
	return shape


## The name of a thing carried up: a scrap's ("scrap:<shape>"), or an idea's.
func thing_name(id: String) -> String:
	if id.begins_with("scrap:"):
		return scrap_name(id.substr(6))
	return idea_name(id)


func _show_village(wake_line := "", lit_today: Array[String] = []) -> void:
	village = VILLAGE.instantiate()
	village.name = "Village"
	village.state = state
	village.panel = panel
	village.wake_line = wake_line
	village.lit_today = lit_today
	village.slept.connect(_on_slept)
	village.acted.connect(_on_village_acted)
	add_child(village)


func _show_dream() -> void:
	dream = DREAM.instantiate()
	dream.name = "Dream"
	dream.state = state
	dream.woke.connect(_on_woke)
	dream.acted.connect(_on_acted)
	dream.reached.connect(_on_reached)
	_reached_idea = ""
	_self_pinched = false
	add_child(dream)


func _on_slept() -> void:
	harness.action("sleep", "")
	harness.milestone("slept_%d" % state.day)
	remove_child(village)   # out of the tree now, so its ground leaves the physics space before the dreamer's first step
	village.queue_free()
	village = null
	panel.hide_all()
	_show_dream()


func _on_acted(kind: String, detail: String) -> void:
	harness.action(kind, detail)
	if kind == "grab_scrap":
		harness.milestone("grabbed_scrap")
	elif kind == "self_pinch":
		_self_pinched = true
		harness.milestone("self_pinch")
	elif kind == "retarget":
		harness.milestone("retarget:%s" % detail)


## The goal room's idea reached (SPEC-2): kept at once, the wall names it;
## the dream's gentle woke follows.
func _on_reached(who: String, idea: String) -> void:
	_reached_idea = idea
	state.reach(who, idea)
	harness.milestone("reached:%s" % who)
	harness.milestone("kept:%s" % idea)


## What the village reports by day: the Desk's developments and reveals
## are milestones, the rest are actions.
func _on_village_acted(kind: String, detail: String) -> void:
	match kind:
		"talk":
			harness.action("talk:%s" % detail)
		"desk_full", "desk_reveal":
			harness.action(kind, detail)
			harness.milestone("%s:%s" % [kind, detail])
		_:
			harness.action(kind, detail)


## Waking: sudden keeps one scrap (the player picks when two or more were
## carried) and marks the wall; gentle keeps all. Then the next day.
func _on_woke(sudden: bool, scraps: Array) -> void:
	var things: Array = []   # the scraps as scrap:<shape>
	for shape in scraps:
		things.append("scrap:%s" % shape)
	remove_child(dream)   # out of the tree now, so its room leaves the physics space before the walker's first step
	dream.queue_free()
	dream = null
	harness.milestone("woke_sudden" if sudden else "woke_gentle")
	blackout.visible = true
	var keep: Array = things.duplicate()
	var line := str(words.get("wake_gentle", ""))
	if _reached_idea != "":
		line = str(words.get("wake_reached", "")).format({"name": idea_name(_reached_idea)})
	elif _self_pinched:
		line = str(words.get("wake_self", ""))
	if sudden:
		state.tally += 1
		if things.size() >= 2:
			keep = [await _pick_one(things)]
			line = ""
		elif things.size() == 1:
			line = str(words.get("wake_sudden_scrap", ""))
		else:
			line = str(words.get("wake_sudden_none", ""))
	var lost: Array = []
	for id in things:
		if not keep.has(id):
			lost.append(id)
	for id in keep:
		var shape := str(id).substr(6)
		if state.keep_scrap(shape):
			harness.action("keep_scrap", shape)
		else:
			lost.append(id)   # past the state's cap: it falls back into the dream
	for id in lost:
		harness.action("lost", id)
	state.scraps_carried.clear()
	var raised: Array[String] = state.new_day()
	for plot in raised:
		harness.milestone("built:%s" % plot)
	blackout.visible = false
	panel.hide_all()
	_show_village(line, raised)   # the new buildings' windows fade in this morning
	if not lost.is_empty():
		village.fade_lost(lost)


## The keep-one picker: the scraps carried as numbered choices; returns the id kept.
func _pick_one(carried: Array) -> String:
	picking = true
	panel.say(str(words.get("wake_sudden", "")))
	panel.prompt(str(words.get("keep_one", "")))
	var names: Array[String] = []
	for id in carried:
		names.append(thing_name(id))
	panel.choices(names)
	var index: int = await panel.chosen
	harness.action("keep", str(carried[index]))
	picking = false
	return carried[index]
