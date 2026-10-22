extends Node2D
## The dream of toy 4, PINCH, day 3: the room dealer, the ideas, the frame,
## lucidity.
##
## Each night deals rooms one at a time under Rooms: the tutorial first on
## night 1 only, then ROOMS_PER_NIGHT of the rooms of data/rooms.json
## shuffled by a generator seeded with state.day (so a test can predict
## the order with deal()), then the bed room last. On nights where
## day % 3 == 0 the bed is also dealt in the middle, at position 2, with
## an exit past it ("your bed in the wrong place"): lie down and the night
## ends gently with everything; walk past and the night goes on. The
## dreamer (one body, kept across rooms) is put at each room's Door;
## standing pinched in a room's Exit deals the next.
##
## Ideas (data/ideas.json): the dealer lays one idea per dealt room on one
## of the room's IdeaSpots, from the ideas not yet kept or built, shuffled
## by the day; never in the bed room, never in the ladder. An idea is a
## crisp body (idea.gd): grab it with E while pinched and within GRAB_REACH
## of it, carry room permitting (state.carry_limit); it goes under the hat
## (the dreamer's stack) and the newest one is "in hand" for HAND seconds,
## counting double in effective (the SPEC: an idea in the hand counts
## double while held). Q while pinched on the floor sets the top idea down
## as a 48 x 24 solid step in front of the dreamer; it is an ordinary idea
## again there, and if the room is left it stays behind, lost for the
## night (rooms are dealt once per night; the pool has it back tomorrow).
##
## The frame, four black rects on a CanvasLayer, persists across rooms:
## its opening is aperture * the viewport, centred on the dreamer's screen
## position and clamped inside the viewport, placed every frame; aperture()
## = 1 - effective / limit moves on acts, shown_aperture() eases to it over
## EASE seconds; a blink is a snap shut. At the limit the frame eases shut
## and stays shut SHUT seconds before woke(true, carried) fires, so the
## player sees it close; E on the bed emits woke(false, carried) at once.
##
## Lucidity is an integer moved only by acts (the SPEC table): grab +2,
## set down +1, force +1, a hard fall while pinched +1, a failed screen
## +1, wonder -1 once per wonder per visit (drift through a soft wall
## asleep, ride the goat, stay still 3 s in a spot); never below 0;
## holding the button is free. effective = lucidity + ideas carried (+1
## while one is in hand). A failed screen (fell below the room, or touched
## a hazard pinched) blinks: the frame shuts for BLINK seconds, then the
## dreamer is back at the Door.
##
## Day 4. The limit is tonight's (state.night_limit(): 8, or 10 with a
## pill taken at the bunk). The dealer leaves out ideas that are kept,
## claimed, built or small things. THE SLEEP GAUGE (IDEAS, the designer's
## words: a sleep meter with the depths of sleep in it, and how long you
## can stay): a vertical bar at the bottom left on its own CanvasLayer over
## the frame (so it can still be read when the frame is nearly shut, which
## is when the designer wants to know which one the player looks at),
## GAUGE_PX tall per point of the limit (so the bar grows on a pill night), in three bands
## drawn and labelled from rooms.json "gauge": deep (effective up to
## DEEP_TO of the limit), light (to LIGHT_TO), waking (the rest); a needle
## at effective, easing like the frame; beside it "ideas n / carry_limit".
## H toggles it (gauge_visible, on by default, for this night only); the
## frame stays whatever the gauge does. gauge_band() and gauge_fraction()
## read it. Idea names come from data/ideas.json, every other word from
## data/rooms.json; rewrite those, not this.

signal woke(sudden: bool, carried: Array)
signal acted(kind: String, detail: String)
signal room_entered(id: String)

const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const IDEA := preload("res://prototypes/pinch/idea.gd")
const ROOM_SCENES := {
	"tutorial": preload("res://prototypes/pinch/rooms/room_tutorial.tscn"),
	"a": preload("res://prototypes/pinch/rooms/room_a.tscn"),
	"b": preload("res://prototypes/pinch/rooms/room_b.tscn"),
	"c": preload("res://prototypes/pinch/rooms/room_c.tscn"),
	"d": preload("res://prototypes/pinch/rooms/room_d.tscn"),
	"e": preload("res://prototypes/pinch/rooms/room_e.tscn"),
	"ladder": preload("res://prototypes/pinch/rooms/room_ladder.tscn"),
	"bed": preload("res://prototypes/pinch/rooms/room_bed.tscn"),
}
const TUTORIAL := "tutorial"
const BED := "bed"
const LADDER := "ladder"
const IDEALESS: Array[String] = ["bed", "ladder"]   # rooms the dealer never lays an idea in
const ROOMS_PER_NIGHT := 4    # SPEC: four dealt plus the bed
const EARLY_BED_EVERY := 3    # nights where day % 3 == 0 deal the bed early too
const EARLY_BED_AT := 2       # ... at this position
const REACH := 72.0           # px: this close to the block's or the bed's middle, E acts on it
const GRAB_REACH := 40.0      # px between the dreamer's box and an idea's: E takes it
const PUSH := 48.0            # px a forced block slides
const HAND := 2.0             # s a grabbed idea is in the hand, counting double
const SET_DOWN_AHEAD := 42.0  # px from the dreamer's middle to a set-down idea's: a 4 px gap
const BLINK := 1.0            # s the frame stays shut after a failed screen (SPEC: one second)
const EASE := 0.35            # s the shown aperture takes to reach the aperture after an act
const SHUT := 0.8             # s the frame is shown fully shut at the limit before woke fires
const STILL := 3.0            # s still inside a spot for its wonder
const GAUGE_PX := 16.0        # px of bar per point of the limit: 128 px at 8, 160 at 10
const GAUGE_WIDTH := 18.0     # px: the bar's width
const GAUGE_AT := Vector2(28, 624)   # the bar's bottom-left corner on the screen
const DEEP_TO := 0.4          # effective up to this share of the limit is deep sleep
const LIGHT_TO := 0.75        # ... up to this, light; past it, waking
const BAND_COLORS := {
	"deep": Color(0.2, 0.2, 0.3),
	"light": Color(0.42, 0.42, 0.52),
	"waking": Color(0.7, 0.7, 0.74),
}
const NEEDLE_COLOR := Color(1.0, 1.0, 1.0)
const GAUGE_LAYER := 6        # above the frame (5), below the text panel (10)

@onready var dreamer: CharacterBody2D = $Dreamer
@onready var rooms_holder: Node2D = $Rooms
@onready var room_label: Label = $Hud/RoomLabel
@onready var help_label: Label = $Hud/HelpLabel
@onready var frame_top: ColorRect = $Frame/Top
@onready var frame_bottom: ColorRect = $Frame/Bottom
@onready var frame_left: ColorRect = $Frame/Left
@onready var frame_right: ColorRect = $Frame/Right

var state: PinchState               # set by the controller before add_child; a fresh one when run alone
var lucidity := 0                   # moves only in grab(), set_down(), force(), fall(), fail(), wonder()
var carried: Array[String] = []     # idea ids under the hat, the newest last
var ideas: Array = []               # ideas.json, in order
var rooms_data: Array = []          # rooms.json "rooms", in order
var words: Dictionary = {}          # rooms.json "words"
var gauge_words: Dictionary = {}    # rooms.json "gauge"
var gauge_visible := true           # H toggles it; forgotten with the night
var gauge: Node2D = null            # the sleep gauge, on its own layer over the frame
var gauge_bands := {}               # band -> ColorRect
var gauge_labels := {}              # band -> Label
var gauge_needle: ColorRect = null
var ideas_label: Label = null       # "ideas n / carry_limit" beside the bar
var label_format := "{name}. {hint}"
var tonight: Array[String] = []     # the room ids dealt, in order
var tonight_ideas := {}             # room id -> idea id the dealer laid there
var left_behind: Array[String] = [] # ideas set down and left in rooms this night: lost, back in the pool tomorrow
var room_index := -1
var room: Node2D = null             # the room in play
var ideas_node: Node2D = null       # the room's Ideas
var block: StaticBody2D = null      # the room's Block, if any
var bed: ColorRect = null           # the room's Bed, if any
var frame_open := Rect2()           # the visible rectangle inside the frame, in screen px
var forced := false                 # the block has been pushed (once per visit)
var woken := false
var closing := false                # at the limit: the frame is closing, then shut, then woke fires
var wonders_seen := {}              # wonder id -> true, this visit
var blinking := false
var blink_left := 0.0
var blinks := 0                     # failed screens this night
var hard_falls := 0
var _hand_left := 0.0               # s the newest idea stays in the hand
var _shown := 1.0                   # the aperture drawn now
var _ease_from := 1.0
var _ease_to := 1.0
var _ease_t := EASE
var _shut_t := 0.0                  # s the frame has been shut while closing
var _still := {}                    # spot id -> s the dreamer has been still inside it
var _grace := 0                     # frames after a respawn in which the polls below are skipped (see _settle)
var _needle := 0.0                  # the needle drawn now, as a share of the limit
var _needle_from := 0.0
var _needle_to := 0.0
var _needle_t := EASE


func _ready() -> void:
	if state == null:
		state = PinchState.new()
	var loaded: Variant = PinchState.load_json(IDEAS_FILE)
	ideas = loaded if loaded is Array else []
	loaded = PinchState.load_json(ROOMS_FILE)
	var rooms_json: Dictionary = loaded if loaded is Dictionary else {}
	rooms_data = rooms_json.get("rooms", [])
	words = rooms_json.get("words", {})
	label_format = str(rooms_json.get("label", label_format))
	help_label.text = str(rooms_json.get("help", ""))
	gauge_words = rooms_json.get("gauge", {})
	_build_gauge()
	dreamer.hard_landing.connect(fall)
	dreamer.fell_out.connect(fail.bind("fell"))
	dreamer.pinch_changed.connect(_apply_soft)
	redeal(deal(state.day))
	_changed()


func _process(_delta: float) -> void:
	_update_frame()   # the opening follows the dreamer every drawn frame; four rects, cheap


func _physics_process(delta: float) -> void:
	if woken:
		return
	_ease(delta)
	_update_gauge()
	if closing:
		if _shown <= 0.0005:
			_shut_t += delta
			if _shut_t > SHUT + 0.001:
				_wake(true)   # the controller may take the dream out of the tree in its handler
				return
		_update_frame()
		return
	if _hand_left > 0.0:
		_hand_left -= delta
		if _hand_left <= 0.0:
			_hand_left = 0.0
			_changed()   # the idea settles under the hat: effective drops by one
	if blinking:
		blink_left -= delta
		if blink_left <= 0.0:
			_reopen()
		_update_frame()
		return
	_update_frame()
	if _grace > 0:
		_grace -= 1
		return
	_check_hazards()
	_check_wonders(delta)
	_check_exit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("set_down"):
		set_down()
	elif event.is_action_pressed("gauge_toggle"):
		toggle_gauge()


# --- the dealer ---------------------------------------------------------------

## The rooms of one night, in order: the tutorial on night 1 only, then
## ROOMS_PER_NIGHT of the other rooms shuffled by a generator seeded with
## the day, then the bed; every EARLY_BED_EVERY-th night the bed is dealt
## at EARLY_BED_AT as well, with an exit past it.
func deal(day: int) -> Array[String]:
	var pool: Array[String] = []
	for entry in rooms_data:
		var id := str(entry.get("id", ""))
		if id != TUTORIAL and id != BED and ROOM_SCENES.has(id):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = day
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var order: Array[String] = []
	if day == 1:
		order.append(TUTORIAL)
	for i in mini(ROOMS_PER_NIGHT, pool.size()):
		order.append(pool[i])
	if day % EARLY_BED_EVERY == 0 and order.size() > EARLY_BED_AT:
		order.insert(EARLY_BED_AT, BED)
	order.append(BED)
	return order


## The ideas of one night: room id -> idea id, one per dealt room that may
## hold one, from the pool (ideas_pool) shuffled by a generator seeded with
## the day. Pure: no state is touched, so a test can predict a night.
func deal_ideas(day: int, order: Array[String]) -> Dictionary:
	var pool := ideas_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 17
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var dealt := {}
	var next := 0
	for id in order:
		if dealt.has(id) or IDEALESS.has(id) or next >= pool.size():
			continue
		dealt[id] = pool[next]
		next += 1
	return dealt


## Which of a room's spots holds tonight's idea: by the day and the room's place in the night.
func spot_index(day: int, index: int, count: int) -> int:
	return (day * 131 + index * 17) % count


## The ideas the dealer may lay out: not kept, not claimed, not built, not
## a small thing on the street (day 4: an idea is never nothing).
func ideas_pool() -> Array[String]:
	var pool: Array[String] = []
	for idea in ideas:
		var id := str(idea.get("id", ""))
		if state.ideas_kept.has(id) or state.ideas_claimed.values().has(id) or state.ideas_built.values().has(id) or state.small_things.has(id):
			continue
		pool.append(id)
	return pool


## Tonight's rooms set by hand (for tests and the designer): deals the
## ideas for them and enters the first.
func redeal(order: Array[String]) -> void:
	tonight = order.duplicate()
	tonight_ideas = deal_ideas(state.day, tonight)
	room_index = -1
	if room != null:   # the old deal's room goes without a trace: this is a new night
		rooms_holder.remove_child(room)
		room.queue_free()
		room = null
	left_behind = []
	_enter_room(0)


func rooms_tonight() -> Array[String]:
	return tonight.duplicate()


func current_room_id() -> String:
	return tonight[room_index] if room_index >= 0 and room_index < tonight.size() else ""


## The next room of the night; nothing past the last.
func next_room() -> bool:
	if room_index + 1 >= tonight.size():
		return false
	_enter_room(room_index + 1)
	return true


## Straight to one of tonight's rooms (for tests and the designer); the
## first of that id when it was dealt twice.
func jump_to_room(id: String) -> bool:
	var index := tonight.find(id)
	if index < 0:
		return false
	_enter_room(index)
	return true


func room_words(id: String) -> Dictionary:
	for entry in rooms_data:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


## The name of an idea, from ideas.json.
func idea_name(id: String) -> String:
	for idea in ideas:
		if str(idea.get("id", "")) == id:
			return str(idea.get("name", id))
	return id


func _enter_room(index: int) -> void:
	if room != null:
		for id in ideas_in_room():
			left_behind.append(id)
			acted.emit("left", id)   # walked past or set down and abandoned; "lost" is reserved for waking
		rooms_holder.remove_child(room)   # out of the tree now, so its geometry leaves the physics space at once
		room.queue_free()
	room_index = index
	var id := tonight[index]
	room = ROOM_SCENES[id].instantiate()
	room.name = "Room"
	room.words = words
	rooms_holder.add_child(room)
	ideas_node = room.ideas
	block = room.block()
	bed = room.bed()
	if id == BED and index == tonight.size() - 1:
		room.remove_exit()   # the last bed: the bed is the only way out
	forced = false
	wonders_seen = {}
	_still = {}
	blinking = false
	var entry := room_words(id)
	room_label.text = label_format.format({"name": str(entry.get("name", id)), "hint": str(entry.get("hint", ""))})
	if tonight_ideas.has(id):
		var spots: Array[Vector2] = room.idea_spots()
		if not spots.is_empty():
			place_idea(tonight_ideas[id], spots[spot_index(state.day, index, spots.size())])
	_settle()
	_apply_soft(dreamer.pinched)
	_update_frame()
	acted.emit("enter", id)
	room_entered.emit(id)


# --- lucidity -----------------------------------------------------------------

## Tonight's limit: 8, or 10 with a pill (state.night_limit()).
func limit() -> int:
	return state.night_limit()


## Lucidity plus the ideas carried, the one in hand counted twice.
func effective() -> int:
	return lucidity + carried.size() + (1 if in_hand() else 0)


## True for HAND seconds after a grab: the newest idea is in the hand.
func in_hand() -> bool:
	return _hand_left > 0.0 and not carried.is_empty()


func aperture() -> float:
	return clampf(1.0 - float(effective()) / float(limit()), 0.0, 1.0)


## What the frame shows: shut during a blink, easing to the aperture otherwise.
func shown_aperture() -> float:
	return 0.0 if blinking else _shown


## Take the idea in reach while pinched, room under the hat permitting:
## +2, in the hand, gone from the room.
func grab() -> bool:
	if not _can_act() or not dreamer.pinched or carried.size() >= state.carry_limit:
		return false
	var idea := idea_in_reach()
	if idea == null:
		return false
	var id: String = idea.id
	carried.append(id)
	ideas_node.remove_child(idea)
	idea.queue_free()
	_hand_left = HAND
	lucidity += 2
	acted.emit("grab", id)
	_changed()
	return true


## Set the top idea down as a step in front of the feet, pinched and on
## the floor: +1; it is an ordinary idea again, there.
func set_down() -> bool:
	if not _can_act() or not dreamer.pinched or not dreamer.is_on_floor() or carried.is_empty():
		return false
	var id: String = carried.pop_back()
	_hand_left = 0.0
	var at := Vector2(dreamer.position.x + dreamer.facing * SET_DOWN_AHEAD, dreamer.position.y + dreamer.BODY_SIZE.y / 2.0 - IDEA.SIZE.y / 2.0)
	at.x = clampf(at.x, room.WALL + IDEA.SIZE.x / 2.0, room.SIZE.x - room.WALL - IDEA.SIZE.x / 2.0)
	place_idea(id, at)
	lucidity += 1
	acted.emit("set_down", id)
	_changed()
	return true


## Push the block in reach while pinched: +1, once per visit.
func force() -> bool:
	if not _can_act() or forced or block == null or not dreamer.pinched or not block_in_reach():
		return false
	forced = true
	block.position.x += PUSH
	lucidity += 1
	acted.emit("force", "block")
	_changed()
	return true


## A hard landing while pinched (the dreamer reports it): +1.
func fall() -> void:
	if not _can_act():
		return
	hard_falls += 1
	lucidity += 1
	acted.emit("fall", "")
	_changed()


## A failed screen (fell out, or a hazard while pinched): blink shut, +1,
## then back at the door.
func fail(reason: String) -> void:
	if not _can_act():
		return
	blinks += 1
	blinking = true
	blink_left = BLINK
	dreamer.freeze()
	lucidity += 1
	acted.emit("fail", reason)
	_shown = 0.0   # a blink is a snap shut; the reopening eases
	_changed()


## A wonder, once per visit: -1, never below 0.
func wonder(id: String, kind: String) -> bool:
	if not _can_act() or wonders_seen.has(id):
		return false
	wonders_seen[id] = true
	lucidity = maxi(0, lucidity - 1)
	acted.emit("wonder:%s" % id, kind)
	_changed()
	return true


## Lie in the bed in reach: wake gently with everything.
func lie_down() -> bool:
	if not _can_act() or not bed_in_reach():
		return false
	acted.emit("lie_down", "")
	_wake(false)
	return true


## An idea lying in the room, placed by the dealer or by hand (tests, the
## designer): a crisp body at `at` (its middle), named from ideas.json.
func place_idea(id: String, at: Vector2) -> StaticBody2D:
	var idea: StaticBody2D = IDEA.new()
	idea.setup(id, idea_name(id))
	idea.position = at
	ideas_node.add_child(idea)
	return idea


## The ids of the ideas lying in the room in play, in order.
func ideas_in_room() -> Array[String]:
	var ids: Array[String] = []
	if ideas_node != null:
		for idea in ideas_node.get_children():
			ids.append(idea.id)
	return ids


## The nearest idea whose box is within GRAB_REACH of the dreamer's box.
func idea_in_reach() -> StaticBody2D:
	var best: StaticBody2D = null
	var best_distance := INF
	if ideas_node == null:
		return null
	var hand: Rect2 = dreamer.rect().grow(GRAB_REACH)
	for idea in ideas_node.get_children():
		if not hand.intersects(idea.rect(), true):   # borders count: 40 px is in reach
			continue
		var distance: float = dreamer.position.distance_to(idea.position)
		if distance < best_distance:
			best = idea
			best_distance = distance
	return best


func block_in_reach() -> bool:
	return block != null and dreamer.position.distance_to(block.position + block.size / 2.0) <= REACH


func bed_in_reach() -> bool:
	return bed != null and dreamer.position.distance_to(bed.position + bed.size / 2.0) <= REACH


func _can_act() -> bool:
	return not woken and not closing and not blinking


func _interact() -> void:
	if not _can_act():
		return
	if dreamer.pinched and (grab() or force()):
		return
	lie_down()


# --- the room in play -----------------------------------------------------------

func _check_hazards() -> void:
	if not dreamer.pinched:
		return
	for hazard in get_tree().get_nodes_in_group("hazard"):
		if hazard.overlaps_body(dreamer):
			fail("hazard")
			return


func _check_wonders(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("wonder"):
		if wonders_seen.has(node.id):
			continue
		if not node.overlaps_body(dreamer):
			_still.erase(node.id)
			continue
		match node.kind:
			"soft_wall", "goat":
				if not dreamer.pinched:
					wonder(node.id, node.kind)
			"spot":
				if dreamer.is_still():
					_still[node.id] = _still.get(node.id, 0.0) + delta
					if _still[node.id] >= STILL:
						wonder(node.id, node.kind)
				else:
					_still[node.id] = 0.0


func _check_exit() -> void:
	if room.exit != null and dreamer.pinched and dreamer.is_on_floor() and room.exit.overlaps_body(dreamer):
		next_room()


## Soft things are seen only asleep: hidden, and their shapes off, while pinched.
func _apply_soft(pinched: bool) -> void:
	for node in get_tree().get_nodes_in_group("soft"):
		if node is CanvasItem:
			node.visible = not pinched
		for shape in node.find_children("*", "CollisionShape2D", true, false):
			shape.disabled = pinched


func _reopen() -> void:
	blinking = false
	_settle()
	_ease_from = 0.0
	_ease_to = aperture()
	_ease_t = 0.0
	_shown = 0.0
	_update_frame()


## The dreamer back at the door. A kinematic body's new place reaches the
## physics server one step late, so for two frames the areas still report
## the overlaps of where it was (the hazard it fell into, the exit it stood
## in): the polls wait those frames out.
func _settle() -> void:
	dreamer.respawn(room.door.position)
	_grace = 2


## After every act: the hat, the frame's target, and the limit.
func _changed() -> void:
	state.ideas_carried.assign(carried)
	dreamer.set_hat(carried.size(), in_hand())
	if not is_equal_approx(_ease_to, aperture()):
		_ease_from = _shown
		_ease_to = aperture()
		_ease_t = 0.0
	var share := float(effective()) / float(limit())
	if not is_equal_approx(_needle_to, share):
		_needle_from = _needle
		_needle_to = share
		_needle_t = 0.0
	_update_frame()
	_update_gauge()
	if effective() >= limit() and not closing and not woken:
		closing = true
		_shut_t = 0.0


## The shown aperture moves from where it was to the aperture over EASE
## seconds; the gauge's needle the same way, to effective / limit.
func _ease(delta: float) -> void:
	if _ease_t < EASE:
		_ease_t = minf(_ease_t + delta, EASE)
		_shown = lerpf(_ease_from, _ease_to, _ease_t / EASE)
	if _needle_t < EASE:
		_needle_t = minf(_needle_t + delta, EASE)
		_needle = lerpf(_needle_from, _needle_to, _needle_t / EASE)


# --- the sleep gauge -------------------------------------------------------------

## Which band effective is in tonight: deep (up to DEEP_TO of the limit),
## light (up to LIGHT_TO), waking (the rest, including the limit itself).
func gauge_band() -> String:
	var e := float(effective())
	var l := float(limit())
	if e <= l * DEEP_TO + 0.0001:
		return "deep"
	if e <= l * LIGHT_TO + 0.0001:
		return "light"
	return "waking"


## Where the needle is drawn: effective / limit, eased over EASE seconds after an act.
func gauge_fraction() -> float:
	return _needle


## The bar's full height in px: GAUGE_PX per point of tonight's limit.
func gauge_height() -> float:
	return limit() * GAUGE_PX


func toggle_gauge() -> void:
	gauge_visible = not gauge_visible
	gauge.visible = gauge_visible
	acted.emit("gauge", "on" if gauge_visible else "off")


func _build_gauge() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GaugeLayer"
	layer.layer = GAUGE_LAYER
	add_child(layer)
	gauge = Node2D.new()
	gauge.name = "Gauge"
	gauge.position = GAUGE_AT
	layer.add_child(gauge)
	for band in ["deep", "light", "waking"]:
		var rect := ColorRect.new()
		rect.name = band.capitalize()
		rect.color = BAND_COLORS[band]
		gauge.add_child(rect)
		gauge_bands[band] = rect
		var label := Label.new()
		label.name = band.capitalize() + "Label"
		label.text = str(gauge_words.get(band, band))
		label.size = Vector2(80, 22)
		label.add_theme_font_size_override("font_size", 13)
		gauge.add_child(label)
		gauge_labels[band] = label
	gauge_needle = ColorRect.new()
	gauge_needle.name = "Needle"
	gauge_needle.color = NEEDLE_COLOR
	gauge_needle.size = Vector2(GAUGE_WIDTH + 10.0, 3)
	gauge.add_child(gauge_needle)
	ideas_label = Label.new()
	ideas_label.name = "Ideas"
	ideas_label.size = Vector2(160, 22)
	gauge.add_child(ideas_label)
	gauge.visible = gauge_visible
	_update_gauge()


## The bands stacked from the bar's bottom (deep) to its top (waking), the
## needle at the eased share of the limit, the ideas count beside it.
func _update_gauge() -> void:
	if gauge == null:
		return
	var height := gauge_height()
	var edges := {"deep": [0.0, DEEP_TO], "light": [DEEP_TO, LIGHT_TO], "waking": [LIGHT_TO, 1.0]}
	for band in edges:
		var from: float = edges[band][0] * height
		var to: float = edges[band][1] * height
		var rect: ColorRect = gauge_bands[band]
		rect.position = Vector2(0, -to)
		rect.size = Vector2(GAUGE_WIDTH, to - from)
		var label: Label = gauge_labels[band]
		label.position = Vector2(GAUGE_WIDTH + 8.0, -(from + to) / 2.0 - 11.0)
	gauge_needle.position = Vector2(-5.0, -_needle * height - 1.5)
	ideas_label.position = Vector2(GAUGE_WIDTH + 8.0, -height - 26.0)
	ideas_label.text = str(gauge_words.get("ideas", "{n} / {limit}")).format({"n": carried.size(), "limit": state.carry_limit})


# --- the frame -----------------------------------------------------------------

## Where the dreamer is on the screen (the camera's view of the room).
func dreamer_screen_position() -> Vector2:
	return dreamer.get_global_transform_with_canvas().origin


## The middle of the frame's opening, in screen px.
func frame_center() -> Vector2:
	return frame_open.get_center()


## The opening: shown_aperture() * the viewport, centred on the dreamer,
## clamped inside the viewport; four black rects around it.
func _update_frame() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var open := screen * shown_aperture()
	var corner := (dreamer_screen_position() - open / 2.0).clamp(Vector2.ZERO, screen - open)
	frame_open = Rect2(corner, open)
	frame_top.position = Vector2.ZERO
	frame_top.size = Vector2(screen.x, corner.y)
	frame_bottom.position = Vector2(0, corner.y + open.y)
	frame_bottom.size = Vector2(screen.x, screen.y - corner.y - open.y)
	frame_left.position = Vector2(0, corner.y)
	frame_left.size = Vector2(corner.x, open.y)
	frame_right.position = Vector2(corner.x + open.x, corner.y)
	frame_right.size = Vector2(screen.x - corner.x - open.x, open.y)


func _wake(sudden: bool) -> void:
	if woken:
		return
	woken = true
	closing = false
	woke.emit(sudden, carried.duplicate())
