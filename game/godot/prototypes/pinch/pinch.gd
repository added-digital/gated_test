extends Node
## Toy 4, PINCH (rung 3): the controller. Holds the one PinchState and the
## harness, shows the village by day and the dream by night, and handles
## waking: sudden keeps one idea (a picker when two or more were carried,
## shown only once the dream's frame has been shut its SHUT seconds, since
## woke fires after that) and marks the tally; the rest float over the
## bunk and fade (the village draws them). Gentle keeps all. Then the day
## moves on (state.new_day: the ideas claimed at yesterday's breakfast are
## standing, milestone built:<plot>; the pill has worn off) and the village
## comes back with the kept ideas on the table, the wake line first and
## then whatever the morning brings (a request, breakfast: village.gd);
## the plots raised this morning are handed over so their windows fade in.
## The village's doings (talk:<who>, told, told_wrong, made, pill, the
## breakfast) go to the harness here. Every word the player reads comes
## from data/village.json, data/characters.json and data/ideas.json;
## rewrite those, not this.
##
## The second loop (SPEC-2, day A): the dream's reached(who, idea) marks
## the villager's branch reached (state.reach: the idea is kept, the wall
## names it; milestones reached:<who>, kept:<idea>) and its woke(false)
## follows at once. Scraps come up with the ideas: the dream's
## scraps_carried is read at the woke signal; gentle wakings (the bed, the
## idea reached, the self-pinch: milestone self_pinch, not on the tally)
## keep every one (state.keep_scrap); a sudden waking keeps ONE thing of
## everything carried, ideas and scraps together, through the picker
## (names from data/ideas.json and data/scraps.json), and the rest fade
## over the bunk. The wake line names what happened (village.json
## wake_reached, wake_self, wake_sudden_scrap).

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


## The name of a thing carried: an idea's, or a scrap's ("scrap:<shape>").
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
	harness.action("sleep", "pill" if state.pill_tonight else "")
	harness.milestone("slept_%d" % state.day)
	remove_child(village)   # out of the tree now, so its ground leaves the physics space before the dreamer's first step
	village.queue_free()
	village = null
	panel.hide_all()
	_show_dream()


func _on_acted(kind: String, detail: String) -> void:
	harness.action(kind, detail)
	if kind == "grab":
		harness.milestone("grabbed")
	elif kind == "grab_scrap":
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


## What the village reports by day: a telling is a milestone, the rest are actions.
func _on_village_acted(kind: String, detail: String) -> void:
	match kind:
		"told":
			harness.action("told", detail)
			harness.milestone("told:%s" % detail)
		"talk":
			harness.action("talk:%s" % detail)
		_:
			harness.action(kind, detail)


## Waking: sudden keeps one (the player picks when two or more were carried)
## and marks the wall; gentle keeps all. Then the next day.
func _on_woke(sudden: bool, carried: Array) -> void:
	var things: Array = carried.duplicate()   # the ideas, then the scraps as scrap:<shape>
	for shape in dream.scraps_carried:
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
			line = str(words.get("wake_sudden_scrap" if str(things[0]).begins_with("scrap:") else "wake_sudden_one", ""))
		else:
			line = str(words.get("wake_sudden_none", ""))
	var lost: Array = []
	for id in things:
		if keep.has(id):
			continue
		lost.append(id)
		harness.action("lost", id)
	for id in keep:
		if str(id).begins_with("scrap:"):
			state.keep_scrap(str(id).substr(6))
			harness.action("keep_scrap", str(id).substr(6))
		else:
			state.keep(id)
			harness.milestone("kept:%s" % id)
	state.ideas_carried.clear()
	state.scraps_carried.clear()
	var raised: Array[String] = state.new_day()
	for plot in raised:
		harness.milestone("built:%s" % plot)
	blackout.visible = false
	panel.hide_all()
	_show_village(line, raised)   # the new buildings' windows fade in this morning
	if not lost.is_empty():
		village.fade_lost(lost)


## The keep-one picker: the things carried (ideas, scraps) as numbered
## choices; returns the id kept.
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
