extends Node3D
## Toy 2, Help (rung 3). Someone in a rush hurries along the path between
## the two posts. Get within TALK_RANGE of them and they stop, turn and ask
## for a crate: a box with a name on it somewhere on the field. Walk to it,
## E picks it up (it floats in front of you), bring it back, E hands it
## over. A clock runs from the moment they ask. One verb: help.
##
## Every word the player reads comes from two files next to this script:
##   requests.json  the requests, in order; each {ask, item, where, at,
##                  seconds, thanks, too_late}, "at" is the crate's [x, z];
##                  an optional "then": {ask, item, where, at} is a second
##                  crate asked for after the first is handed over, on the
##                  same clock; an optional "ask_after_miss" is said instead
##                  of "ask" when the request before it ended too late
##   words.json     the hints: start, countdown, pick_up, bring_back,
##                  hand_over, after ({item} and {seconds} are filled in)
## Rewrite those, not this.

const REQUESTS_FILE := "res://prototypes/help/requests.json"
const WORDS_FILE := "res://prototypes/help/words.json"
const TALK_RANGE := 3.0   # m: this close to the runner they stop; also the hand-over range
const PICK_RANGE := 2.0   # m: this close to a crate, E picks it up
const HOLD_AT := Vector3(0, 1.2, -1.0)   # a carried crate floats here, in the player's frame: in front, chest height
const LINE_STAYS := 5.0   # s a thanks or too-late line stays on screen after the runner leaves
const CRATE_SIZE := 0.5   # m: the box
const GREY := Color(0.55, 0.55, 0.55)

@onready var player: CharacterBody3D = $Player
@onready var runner: Node3D = $Runner
@onready var panel: CanvasLayer = $TextPanel
@onready var harness: Node = $Harness

var requests: Array = []       # requests.json, in order
var words: Dictionary = {}     # words.json
var number := 0                # 1-based number of the request open or last closed (0: none yet)
var request: Dictionary = {}   # the open request; {} between requests
var legs: Array[Dictionary] = []   # crates still to ask for after the current one (the "then" chain)
var leg: Dictionary = {}       # the crate being fetched now: {ask, item, where, at}
var crate: Node3D = null       # that crate's node, on the field or carried
var time_left := 0.0           # s on the open request's clock
var line_timer := 0.0          # s until the sentence on screen clears (0: it stays)
var missed_last := false       # the last closed request ended too late: the next ask is its ask_after_miss, if it has one


func _ready() -> void:
	var loaded: Variant = _load_json(REQUESTS_FILE)
	requests = loaded if loaded is Array else []
	loaded = _load_json(WORDS_FILE)
	words = loaded if loaded is Dictionary else {}
	harness.start("help")
	panel.say(words.get("start", ""))
	print("[help] %d requests loaded from %s" % [requests.size(), REQUESTS_FILE])


func _process(delta: float) -> void:
	var near_runner := _near(runner, TALK_RANGE)
	if request.is_empty():
		if near_runner and runner.passed_an_end:
			if number < requests.size():
				_offer(requests[number])
			else:
				panel.say(words.get("after", ""))
				line_timer = 1.0
	else:
		time_left -= delta
		if time_left <= 0.0:
			_too_late()
		else:
			_show_hint(near_runner)
	if line_timer > 0.0:
		line_timer -= delta
		if line_timer <= 0.0:
			panel.say("")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or crate == null:
		return
	if carrying():
		if _near(runner, TALK_RANGE):
			_deliver()
	elif _near(crate, PICK_RANGE):
		_pick_up()


## True while the player holds the crate.
func carrying() -> bool:
	return crate != null and crate.get_parent() == player


## The runner stops, asks, and the clock starts.
func _offer(r: Dictionary) -> void:
	number += 1
	request = r
	time_left = float(r.get("seconds", 30))
	legs = []
	var more: Variant = r.get("then")
	while more is Dictionary:   # the optional chain of further crates
		legs.append(more)
		more = more.get("then")
	line_timer = 0.0
	runner.stop_for(player)
	var after_miss := missed_last and str(r.get("ask_after_miss", "")) != ""
	print("[help] request %d offered, %d s on the clock%s" % [number, int(time_left), ", asked the after-a-miss way" if after_miss else ""])
	_ask(r, "ask_after_miss" if after_miss else "ask")


## Say one crate's ask line (ask_key picks which) and put that crate on the field.
func _ask(l: Dictionary, ask_key: String = "ask") -> void:
	leg = l
	panel.say(l.get(ask_key, ""))
	crate = _spawn_crate(str(l.get("item", "?")), l.get("at", [0, 0]))
	_show_hint(_near(runner, TALK_RANGE))   # the countdown shows from this frame, not the next


func _pick_up() -> void:
	crate.reparent(player, false)
	crate.position = HOLD_AT
	crate.rotation = Vector3.ZERO
	crate.get_node("Name").visible = false   # the label would float above your head
	harness.action("pickup", leg.get("item", ""))
	print("[help] picked up %s" % leg.get("item", ""))


func _deliver() -> void:
	harness.action("deliver", leg.get("item", ""))
	print("[help] handed over %s with %d s left" % [leg.get("item", ""), int(time_left)])
	crate.queue_free()
	crate = null
	if legs.is_empty():
		missed_last = false
		_close(request.get("thanks", ""))
		harness.milestone("request_%d_done" % number)
	else:
		_ask(legs.pop_front())   # the next crate, same clock


func _too_late() -> void:
	print("[help] too late on request %d" % number)
	missed_last = true
	_close(request.get("too_late", ""))
	harness.milestone("too_late")


## The runner says a last line and hurries on; the crate, if any, is gone.
func _close(line: String) -> void:
	panel.say(line)
	panel.prompt("")
	line_timer = LINE_STAYS
	if crate != null:
		crate.queue_free()
		crate = null
	request = {}
	legs = []
	leg = {}
	runner.go()


## The prompt line while a request is open: the countdown, then what to do.
func _show_hint(near_runner: bool) -> void:
	var fill := {"item": leg.get("item", ""), "seconds": ceili(time_left)}
	var hint: String
	if carrying():
		hint = words.get("hand_over" if near_runner else "bring_back", "")
	elif _near(crate, PICK_RANGE):
		hint = words.get("pick_up", "")
	else:
		hint = leg.get("where", "")
	panel.prompt((words.get("countdown", "{seconds}") + "   " + hint).format(fill))


## A grey 0.5 m box with its name floating above it, at (x, z) on the field.
func _spawn_crate(item: String, at: Array) -> Node3D:
	var box := MeshInstance3D.new()
	box.name = "Crate"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CRATE_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = GREY
	mesh.material = material
	box.mesh = mesh
	box.position = Vector3(float(at[0]), CRATE_SIZE / 2.0, float(at[1]))
	var label := Label3D.new()
	label.name = "Name"
	label.text = item
	label.position = Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # always faces the camera
	label.no_depth_test = true                           # readable through the posts and the runner
	label.font_size = 96
	label.pixel_size = 0.01                              # about 1 m tall letters: visible from the far side of the field
	box.add_child(label)
	add_child(box)
	return box


## Flat distance from the player to node, within range?
func _near(node: Node3D, range_m: float) -> bool:
	var a := player.global_position
	var b := node.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= range_m


func _load_json(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("[help] cannot read %s" % path)
	return data
