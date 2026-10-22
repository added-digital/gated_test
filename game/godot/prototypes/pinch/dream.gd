extends Node2D
## The dream of toy 4, PINCH, day 3: the room dealer, the ideas, the frame,
## lucidity.
##
## Each night deals rooms one at a time under Rooms (the first loop dealt
## them from a shuffled deck with the bed room last; SPEC-2's branch dealer,
## below, replaces that: the hub, a branch, a goal room; the tutorial, the
## ladder and the bed room stay in ROOM_SCENES for redeal() by hand). The
## dreamer (one body, kept across rooms) is put at each room's Door;
## standing pinched in a room's Exit deals the next.
##
## Ideas (data/ideas.json) were the first loop's pickups: deal_ideas laid
## one per room on an IdeaSpot (it is kept, pure, but the night no longer
## calls it: the dealer hangs scraps there instead, and the goal room's
## idea is placed from the branch). place_idea lays one by hand. An idea is a
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
## a hazard pinched) blinks (day 5, three phases, blink_phase()): the
## frame shuts over BLINK_SHUT_FRAMES, holds shut until BLINK seconds have
## passed since the fail, then the dreamer is back at the Door (dropping
## in, dreamer.gd) and the frame reopens over BLINK_OPEN_FRAMES; blinking
## is true for the first two phases only, when nothing counts. Within
## THIN_STEPS of the limit every soft shape is drawn through the THIN
## modulate, so the dream visibly thins as the frame nears shut.
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
## H toggles it (gauge_visible, on by default; day 5: kept in
## state.gauge_visible, so the choice holds for the session); the frame
## stays whatever the gauge does. gauge_band() and gauge_fraction() read
## it. Idea names come from data/ideas.json, every other word from
## data/rooms.json; rewrite those, not this.
##
## The readability pass. THE DEV BAR (devbar.gd, data/devbar.json): a thin
## strip at the bottom of the screen on its own layer above the frame,
## listing ONLY the actions available right now, computed every drawn
## frame from the state (devbar_text(): asleep, in a current, over a
## spot, pinched on the floor or in the air, an idea in reach with room
## under the hat, an idea to set down, the block to push, the exit near,
## the bed in reach); its right half shows the room's one-line hint
## (rooms.json "hint") for the first seconds after entering a room, then
## fades it (the fixed controls line is gone; the dev bar replaces it);
## the room's NAME stays as a small label at the top left (rooms.json
## "label"). Tab toggles the bar (toggle_devbar; state.devbar_visible, kept
## for the session). THE FRAME's four rects are rounded to whole pixels
## and the side rects overlap the top and bottom ones by FRAME_OVERLAP px
## (frame_rects()), so no half-pixel seam shows as a grey line. The gauge
## sits GAUGE_AT, 24 px higher than before, above the dev bar and clear of
## the door's word (room.gd), which now sits left of the door at the
## floor line.
##
## THE SECOND LOOP (SPEC-2, day A). THE BRANCH DEALER replaces the deck:
## tonight's rooms are the hub (rooms/room_hub.tscn, the Long House's
## reflection), then the two rooms of the target's branch in their fixed
## order (data/branches.json), then the villager's goal room; with no
## target (nobody talked to yet) the hub alone is the night. The hub has
## two exits with signs (rooms.json sign_left / sign_right): the right one
## leads down the target's branch, the left down another talked-to
## villager's (none when there is no other); walking into the other sign's
## exit retargets the night (state.target changes; the wall shows it
## tomorrow): the sign is the choice. Every exit carries its branch in its
## metadata, and a branch room's name reads "whose dream" (rooms.json
## label_whose). IDEAS no longer spawn in rooms: the dealer lays SCRAPS
## instead (data/scraps.json: three shapes, scraps_per_night of them over
## the hub and the branch rooms, never the goal room; deal_scraps is pure),
## hung SCRAP_HOVER px over the rooms' IdeaSpots and ScrapSpots at hand
## height so they never block a walk; a scrap (scrap.gd) is grabbed with E
## pinched within GRAB_REACH (+1, not +2), carried at the hip up to
## state.carry_scraps, set down with Q as a small step (+1, with no idea on
## the hat; an idea goes first) and grabbed again. effective = lucidity +
## ideas carried (+1 in hand) + scraps carried. THE GOAL ROOM holds the
## villager asleep and their idea beside them (placed by the dealer from
## the branch, marked `goal`: it cannot be grabbed): E at it while pinched
## REACHES it: reached(who, idea), then woke(false, carried) at once; the
## night ends gently with the idea and every scrap. THE SELF-PINCH: holding
## PINCH for SELF_PINCH seconds standing still on a floor (no movement
## input, the body still) wakes the dreamer on purpose (self_pinch, then
## woke(false, carried): every scrap, not the idea; not on the tally); from
## FLICKER_FROM seconds into the hold the shown aperture flickers +-FLICKER
## at FLICKER_HZ; moving or letting go resets the hold (hold_seconds()),
## and so does standing in a quiet spot whose wonder is still to be had
## (the spot takes the stillness: 3 s there is the wonder, not a waking).
## The controller reads scraps_carried at the woke signal (the dream is
## still whole then). Villager names come from data/characters.json.

signal woke(sudden: bool, carried: Array)
signal acted(kind: String, detail: String)
signal room_entered(id: String)
signal reached(who: String, idea: String)

const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const DEVBAR_FILE := "res://prototypes/pinch/data/devbar.json"
const BRANCHES_FILE := "res://prototypes/pinch/data/branches.json"
const SCRAPS_FILE := "res://prototypes/pinch/data/scraps.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const IDEA := preload("res://prototypes/pinch/idea.gd")
const SCRAP := preload("res://prototypes/pinch/scrap.gd")
const DEVBAR := preload("res://prototypes/pinch/devbar.gd")
const ROOM_SCENES := {
	"hub": preload("res://prototypes/pinch/rooms/room_hub.tscn"),
	"goal_tove": preload("res://prototypes/pinch/rooms/goal_tove.tscn"),
	"goal_jorun": preload("res://prototypes/pinch/rooms/goal_jorun.tscn"),
	"goal_bo": preload("res://prototypes/pinch/rooms/goal_bo.tscn"),
	"tutorial": preload("res://prototypes/pinch/rooms/room_tutorial.tscn"),
	"a": preload("res://prototypes/pinch/rooms/room_a.tscn"),
	"b": preload("res://prototypes/pinch/rooms/room_b.tscn"),
	"c": preload("res://prototypes/pinch/rooms/room_c.tscn"),
	"d": preload("res://prototypes/pinch/rooms/room_d.tscn"),
	"e": preload("res://prototypes/pinch/rooms/room_e.tscn"),
	"f": preload("res://prototypes/pinch/rooms/room_f.tscn"),
	"ladder": preload("res://prototypes/pinch/rooms/room_ladder.tscn"),
	"bed": preload("res://prototypes/pinch/rooms/room_bed.tscn"),
}
const TUTORIAL := "tutorial"
const BED := "bed"
const LADDER := "ladder"
const HUB := "hub"
const IDEALESS: Array[String] = ["bed", "ladder"]   # rooms the first loop's idea dealer (deal_ideas, unused by the night now) never lays an idea in
const SCRAP_ROOMS: Array[String] = ["hub", "a", "b", "c", "d", "e", "f"]   # rooms with spots the scrap dealer may use
const SCRAP_HOVER := 64.0     # px a dealt scrap hangs above its spot: at hand height, clear of a body standing under it
const SCRAP_SPREAD := 40.0    # px sideways between scraps sharing a spot (the hub alone holds all six)
const SELF_PINCH := 3.0       # s PINCH is held still on a floor to wake on purpose
const FLICKER_FROM := 1.0     # s into the hold the frame starts to flicker
const FLICKER := 0.05         # the shown aperture swings this far either way while it flickers
const FLICKER_HZ := 4.0       # swings per second
const HOLD_EPSILON := 0.0001  # s: 180 frames of 1/60 add up a hair short of 3.0
const REACH := 72.0           # px: this close to the block's or the bed's middle, E acts on it
const GRAB_REACH := 40.0      # px between the dreamer's box and an idea's: E takes it
const PUSH := 48.0            # px a forced block slides
const HAND := 2.0             # s a grabbed idea is in the hand, counting double
const SET_DOWN_AHEAD := 42.0  # px from the dreamer's middle to a set-down idea's: a 4 px gap
const BLINK := 1.0            # s from a failed screen to the dreamer back at the door (SPEC: one second)
const BLINK_SHUT_FRAMES := 4  # frames the frame takes to shut at a failed screen
const BLINK_OPEN_FRAMES := 12 # frames the frame takes to reopen once the dreamer is back
const THIN_STEPS := 2         # effective this close to the limit, or closer: the dream thins
const THIN := Color(0.55, 0.55, 0.6, 1.0)   # the modulate on every soft shape while the dream is thin
const EASE := 0.35            # s the shown aperture takes to reach the aperture after an act
const SHUT := 0.8             # s the frame is shown fully shut at the limit before woke fires
const STILL := 3.0            # s still inside a spot for its wonder
const GAUGE_PX := 16.0        # px of bar per point of the limit: 128 px at 8, 160 at 10
const GAUGE_WIDTH := 18.0     # px: the bar's width
const GAUGE_AT := Vector2(28, 600)   # the bar's bottom-left corner on the screen: above the dev bar, its labels clear of the door's word
const EXIT_NEAR := 64.0       # px around the exit zone within which the dev bar says to walk in
const FRAME_OVERLAP := 1.0    # px the frame's side rects reach into its top and bottom rects: no seam
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
@onready var frame_top: ColorRect = $Frame/Top
@onready var frame_bottom: ColorRect = $Frame/Bottom
@onready var frame_left: ColorRect = $Frame/Left
@onready var frame_right: ColorRect = $Frame/Right

var state: PinchState               # set by the controller before add_child; a fresh one when run alone
var lucidity := 0                   # moves only in grab(), set_down(), force(), fall(), fail(), wonder()
var carried: Array[String] = []     # idea ids under the hat, the newest last
var ideas: Array = []               # ideas.json, in order
var branches: Array = []            # branches.json "branches", in order
var scrap_shapes: Array = []        # scraps.json "shapes", in order
var scraps_per_night := 6           # scraps.json "per_night"
var names := {}                     # who -> name, from characters.json (the signs, the labels)
var scraps_carried: Array[String] = []   # scrap shapes at the hip, the newest last
var tonight_scraps := {}            # room id -> the shapes the dealer hangs there, in spot order
var scraps_node: Node2D = null      # the room's Scraps
var goal_who := ""                  # the goal room in play: whose, and
var goal_idea := ""                 # which idea lies by them ("" elsewhere)
var _hold := 0.0                    # s PINCH has been held still on a floor (the self-pinch)
var _self_pinched := false          # the night ended by the self-pinch
var rooms_data: Array = []          # rooms.json "rooms", in order
var words: Dictionary = {}          # rooms.json "words"
var gauge_words: Dictionary = {}    # rooms.json "gauge"
var devbar_words: Dictionary = {}   # devbar.json
var devbar: CanvasLayer = null      # the dev bar: what can be done now, on its own layer over the frame
var devbar_visible := true          # Tab toggles it; mirrored in state.devbar_visible for the session
var gauge_visible := true           # H toggles it; mirrored in state.gauge_visible for the session
var gauge: Node2D = null            # the sleep gauge, on its own layer over the frame
var gauge_bands := {}               # band -> ColorRect
var gauge_labels := {}              # band -> Label
var gauge_needle: ColorRect = null
var ideas_label: Label = null       # "ideas n / carry_limit" beside the bar
var label_format := "{name}. {hint}"
var label_whose := "{name} · {whose}"   # rooms.json "label_whose": a branch room's name with whose dream it is
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
var blinking := false               # the blink's shutting and shut phases: nothing counts
var blink_left := 0.0
var blinks := 0                     # failed screens this night
var _shut_frames := 0               # frames into the blink's shutting phase
var _open_frames := 0               # frames left of the blink's reopening phase
var _blink_from := 1.0              # the shown aperture when the blink began
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
	label_whose = str(rooms_json.get("label_whose", label_whose))
	gauge_words = rooms_json.get("gauge", {})
	loaded = PinchState.load_json(DEVBAR_FILE)
	devbar_words = loaded if loaded is Dictionary else {}
	loaded = PinchState.load_json(BRANCHES_FILE)
	branches = (loaded as Dictionary).get("branches", []) if loaded is Dictionary else []
	loaded = PinchState.load_json(SCRAPS_FILE)
	var scraps_json: Dictionary = loaded if loaded is Dictionary else {}
	scrap_shapes = scraps_json.get("shapes", [])
	scraps_per_night = int(scraps_json.get("per_night", scraps_per_night))
	loaded = PinchState.load_json(CHARACTERS_FILE)
	for c in (loaded as Dictionary).get("characters", []) if loaded is Dictionary else []:
		names[str(c.get("id", ""))] = str(c.get("name", c.get("id", "")))
	gauge_visible = state.gauge_visible
	_build_gauge()
	_build_devbar()
	dreamer.hard_landing.connect(fall)
	dreamer.fell_out.connect(fail.bind("fell"))
	dreamer.pinch_changed.connect(_apply_soft)
	redeal(deal_branch(state.target))
	_changed()


func _process(_delta: float) -> void:
	_update_frame()   # the opening follows the dreamer every drawn frame; four rects, cheap
	devbar.set_actions(devbar_text())


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
		_shut_frames = mini(_shut_frames + 1, BLINK_SHUT_FRAMES)
		blink_left -= delta
		if blink_left <= 0.0:
			_reopen()
		_update_frame()
		return
	if _open_frames > 0:
		_open_frames -= 1
	_update_frame()
	if _grace > 0:
		_grace -= 1
		return
	_check_hazards()
	_check_wonders(delta)
	_update_hold(delta)
	if woken:
		return
	_check_exit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("set_down"):
		set_down()
	elif event.is_action_pressed("gauge_toggle"):
		toggle_gauge()
	elif event.is_action_pressed("devbar_toggle"):
		toggle_devbar()


# --- the dealer ---------------------------------------------------------------

## The rooms of one night (SPEC-2): the hub, then the target's two branch
## rooms in their fixed order, then the goal room; the hub alone when there
## is no target or no branch for it. Pure.
func deal_branch(who: String) -> Array[String]:
	var order: Array[String] = [HUB]
	var branch := branch_of(who)
	if branch.is_empty():
		return order
	for id in branch.get("rooms", []):
		if ROOM_SCENES.has(str(id)):
			order.append(str(id))
	var goal := str(branch.get("goal", ""))
	if ROOM_SCENES.has(goal):
		order.append(goal)
	return order


## A villager's branch from branches.json; {} when they have none.
func branch_of(who: String) -> Dictionary:
	for branch in branches:
		if str(branch.get("who", "")) == who:
			return branch
	return {}


## The villager whose goal room this is, "" for any other room.
func goal_owner(id: String) -> String:
	for branch in branches:
		if str(branch.get("goal", "")) == id:
			return str(branch.get("who", ""))
	return ""


## The villager whose branch a room lies on (the goal room included), "" for the hub and the rest.
func branch_owner(id: String) -> String:
	for branch in branches:
		if branch.get("rooms", []).has(id) or str(branch.get("goal", "")) == id:
			return str(branch.get("who", ""))
	return ""


## The branches the dreamer may go down tonight: the talked-to villagers'
## (flag talked:<who>), in branches.json order.
func available_branches() -> Array[String]:
	var whos: Array[String] = []
	for branch in branches:
		var who := str(branch.get("who", ""))
		if state.has_flag("talked:%s" % who):
			whos.append(who)
	return whos


## The scraps of one night: room id -> shapes, `count` of them over the
## rooms of `order` that have spots (SCRAP_ROOMS; never the goal room),
## filled room by room, the shapes cycling round, square, long. Pure.
func deal_scraps(order: Array[String], count: int) -> Dictionary:
	var dealt := {}
	var rooms: Array[String] = []
	for id in order:
		if SCRAP_ROOMS.has(id) and not rooms.has(id):
			rooms.append(id)
	if rooms.is_empty() or scrap_shapes.is_empty():
		return dealt
	var per := ceili(float(count) / float(rooms.size()))
	for i in count:
		var room_id: String = rooms[mini(i / per, rooms.size() - 1)]
		if not dealt.has(room_id):
			dealt[room_id] = [] as Array[String]
		dealt[room_id].append(str(scrap_shapes[i % scrap_shapes.size()].get("id", "")))
	return dealt


## Which of a room's spots holds tonight's idea: by the day and the room's place in the night.
func spot_index(day: int, index: int, count: int) -> int:
	return (day * 131 + index * 17) % count


## The ideas of one night (the first loop's dealer, kept for the record
## and the tests; the night no longer calls it): room id -> idea id, one
## per room that may hold one, from the pool shuffled by the day. Pure.
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
## scraps for them (none with `with_scraps` false) and enters the first.
## No idea is dealt any more (SPEC-2); place_idea lays one by hand.
func redeal(order: Array[String], with_scraps := true) -> void:
	tonight = order.duplicate()
	tonight_ideas = {}
	tonight_scraps = deal_scraps(tonight, scraps_per_night) if with_scraps else {}
	room_index = -1
	if room != null:   # the old deal's room goes without a trace: this is a new night
		rooms_holder.remove_child(room)
		room.queue_free()
		room = null
	left_behind = []
	_enter_room(0)


## The hub's other exit was taken (SPEC-2: the sign is the choice): the
## night is that villager's from here on, its scraps dealt afresh for the
## rooms still to come, and the state's target follows.
func retarget(who: String) -> void:
	if who == "" or who == state.target or branch_of(who).is_empty():
		return
	state.target = who
	tonight = deal_branch(who)
	tonight_scraps = deal_scraps(tonight, scraps_per_night)
	acted.emit("retarget", who)


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


## The name of a scrap's shape, from scraps.json.
func scrap_name(shape: String) -> String:
	for entry in scrap_shapes:
		if str(entry.get("id", "")) == shape:
			return str(entry.get("name", shape))
	return shape


## A villager's name, from characters.json.
func villager_name(who: String) -> String:
	return str(names.get(who, who))


func _enter_room(index: int) -> void:
	if room != null:
		for id in ideas_in_room():
			left_behind.append(id)
			acted.emit("left", id)   # walked past or set down and abandoned; "lost" is reserved for waking
		for shape in scraps_in_room():
			acted.emit("left", "scrap:%s" % shape)
		rooms_holder.remove_child(room)   # out of the tree now, so its geometry leaves the physics space at once
		room.queue_free()
	room_index = index
	var id := tonight[index]
	room = ROOM_SCENES[id].instantiate()
	room.name = "Room"
	room.words = words
	rooms_holder.add_child(room)
	ideas_node = room.ideas
	scraps_node = room.scraps_holder()
	block = room.block()
	bed = room.bed()
	if id == BED and index == tonight.size() - 1:
		room.remove_exit()   # the last bed: the bed is the only way out
	forced = false
	wonders_seen = {}
	_still = {}
	_hold = 0.0
	blinking = false
	goal_who = goal_owner(id)
	goal_idea = ""
	var entry := room_words(id)
	var whose := branch_owner(id)
	var room_name := str(entry.get("name", id))
	if whose != "" and whose == state.target:
		room_label.text = label_whose.format({"name": room_name, "whose": villager_name(whose), "hint": str(entry.get("hint", ""))})
	else:
		room_label.text = label_format.format({"name": room_name, "hint": str(entry.get("hint", ""))})
	devbar.show_hint(str(entry.get("hint", "")))
	if tonight_ideas.has(id):
		var spots: Array[Vector2] = room.idea_spots()
		if not spots.is_empty():
			place_idea(tonight_ideas[id], spots[spot_index(state.day, index, spots.size())])
	if tonight_scraps.has(id):
		var spots: Array[Vector2] = room.idea_spots() + room.scrap_spots()
		var shapes: Array = tonight_scraps[id]
		for i in shapes.size():
			if spots.is_empty():
				break
			var at: Vector2 = spots[i % spots.size()] + Vector2(SCRAP_SPREAD * (i / spots.size()), -SCRAP_HOVER)
			place_scrap(str(shapes[i]), at)
	if id == HUB:
		_set_signs()
	elif whose != "":
		for zone in room.exits():   # a branch room's exit leads on down its branch
			zone.set_meta("branch", whose)
	if goal_who != "":
		var branch := branch_of(goal_who)
		goal_idea = str(branch.get("idea", ""))
		var spots: Array[Vector2] = room.idea_spots()
		if goal_idea != "" and not spots.is_empty():
			var idea := place_idea(goal_idea, spots[0])
			idea.set_meta("goal", true)
		var sleeper: Node2D = room.sleeper()
		if sleeper != null:
			sleeper.set_words(str(words.get("asleep", "{name}")).format({"name": villager_name(goal_who)}), str(words.get("snore", "")))
	_settle()
	_apply_soft(dreamer.pinched)
	_apply_thin()
	_update_frame()
	acted.emit("enter", id)
	room_entered.emit(id)


## The hub's signs: the right exit leads down the target's branch, the
## left down another talked-to villager's; an exit with nowhere to lead
## goes (no target: the hub alone, no way on but waking).
func _set_signs() -> void:
	var right := state.target if not branch_of(state.target).is_empty() else ""
	var left := ""
	for who in available_branches():
		if who != right:
			left = who
			break
	if right == "":
		room.remove_exit()
		return
	room.set_sign("ExitRight", str(words.get("sign_right", "{name}")).format({"name": villager_name(right)}), right)
	if left == "":
		room.remove_exit_named("ExitLeft")
	else:
		room.set_sign("ExitLeft", str(words.get("sign_left", "{name}")).format({"name": villager_name(left)}), left)


## The hub's signs as set: {"left": who, "right": who} ("" for a missing side).
func hub_signs() -> Dictionary:
	var signs := {"left": "", "right": ""}
	if room == null:
		return signs
	for zone in room.exits():
		var side := "left" if zone.name == "ExitLeft" else "right"
		signs[side] = str(zone.get_meta("branch", ""))
	return signs


## The sign texts as shown: {"left": text, "right": text}.
func sign_texts() -> Dictionary:
	var texts := {"left": "", "right": ""}
	if room == null:
		return texts
	for zone in room.exits():
		var side := "left" if zone.name == "ExitLeft" else "right"
		texts[side] = zone.label.text if zone.label != null else ""
	return texts


# --- lucidity -----------------------------------------------------------------

## Tonight's limit: 8, or 10 with a pill (state.night_limit()).
func limit() -> int:
	return state.night_limit()


## Lucidity plus the ideas carried (the one in hand counted twice) plus
## the scraps carried (SPEC-2: no doubling; scraps are small).
func effective() -> int:
	return lucidity + carried.size() + (1 if in_hand() else 0) + scraps_carried.size()


## True for HAND seconds after a grab: the newest idea is in the hand.
func in_hand() -> bool:
	return _hand_left > 0.0 and not carried.is_empty()


func aperture() -> float:
	return clampf(1.0 - float(effective()) / float(limit()), 0.0, 1.0)


## What the frame shows: shutting then shut during a blink, reopening
## after it, easing to the aperture otherwise.
func shown_aperture() -> float:
	if blinking:
		return lerpf(_blink_from, 0.0, _shut_frames / float(BLINK_SHUT_FRAMES))
	if _open_frames > 0:
		return _shown * (1.0 - _open_frames / float(BLINK_OPEN_FRAMES))
	return clampf(_shown + flicker(), 0.0, 1.0)


## The self-pinch's flicker: from FLICKER_FROM seconds into the hold the
## shown aperture swings +-FLICKER at FLICKER_HZ; 0 otherwise.
func flicker() -> float:
	if _hold < FLICKER_FROM:
		return 0.0
	return FLICKER * sin(TAU * FLICKER_HZ * (_hold - FLICKER_FROM))


## The blink's phase: "shutting" (BLINK_SHUT_FRAMES), "shut" (until BLINK
## seconds have passed), "reopening" (BLINK_OPEN_FRAMES, the dreamer back),
## or "" when the frame is not blinking.
func blink_phase() -> String:
	if blinking:
		return "shutting" if _shut_frames < BLINK_SHUT_FRAMES else "shut"
	return "reopening" if _open_frames > 0 else ""


## True within THIN_STEPS of the limit: the soft shapes are drawn dimmer.
func thin() -> bool:
	return effective() >= limit() - THIN_STEPS


## Take the idea in reach while pinched, room under the hat permitting:
## +2, in the hand, gone from the room.
func grab() -> bool:
	if not _can_act() or not dreamer.pinched or carried.size() >= state.carry_limit:
		return false
	var idea := idea_in_reach()
	if idea == null or idea.has_meta("goal"):   # the goal room's idea is reached (E), never carried
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


## Take the scrap in reach while pinched, the hip permitting
## (state.carry_scraps): +1, gone from the room.
func grab_scrap() -> bool:
	if not _can_act() or not dreamer.pinched or scraps_carried.size() >= state.carry_scraps:
		return false
	var scrap := scrap_in_reach()
	if scrap == null:
		return false
	var shape: String = scrap.shape
	scraps_carried.append(shape)
	scraps_node.remove_child(scrap)
	scrap.queue_free()
	lucidity += 1
	acted.emit("grab_scrap", shape)
	_changed()
	return true


## E at the goal room's idea while pinched (SPEC-2): reached. The night
## ends gently at once with the idea and every scrap.
func reach() -> bool:
	if not _can_act() or not dreamer.pinched or goal_idea == "":
		return false
	var idea := idea_in_reach()
	if idea == null or not idea.has_meta("goal"):
		return false
	acted.emit("reach", goal_idea)
	reached.emit(goal_who, goal_idea)
	_wake(false)
	return true


## True while the goal room's idea is in reach and the dreamer is pinched.
func can_reach() -> bool:
	if goal_idea == "" or not dreamer.pinched:
		return false
	var idea := idea_in_reach()
	return idea != null and idea.has_meta("goal")


## Set the top idea down as a step in front of the feet, pinched and on
## the floor: +1; it is an ordinary idea again, there. With no idea on the
## hat, the top scrap goes down instead (set_down_scrap).
func set_down() -> bool:
	if not _can_act() or not dreamer.pinched or not dreamer.is_on_floor():
		return false
	if carried.is_empty():
		return set_down_scrap()
	var id: String = carried.pop_back()
	_hand_left = 0.0
	var at := Vector2(dreamer.position.x + dreamer.facing * SET_DOWN_AHEAD, dreamer.position.y + dreamer.BODY_SIZE.y / 2.0 - IDEA.SIZE.y / 2.0)
	at.x = clampf(at.x, room.WALL + IDEA.SIZE.x / 2.0, room.SIZE.x - room.WALL - IDEA.SIZE.x / 2.0)
	place_idea(id, at)
	lucidity += 1
	acted.emit("set_down", id)
	_changed()
	return true


## Set the top scrap down as a small step in front of the feet, pinched and
## on the floor (SPEC-2): +1; it lies there, grabbable again.
func set_down_scrap() -> bool:
	if not _can_act() or not dreamer.pinched or not dreamer.is_on_floor() or scraps_carried.is_empty():
		return false
	var shape: String = scraps_carried.pop_back()
	var at := Vector2(dreamer.position.x + dreamer.facing * SET_DOWN_AHEAD, dreamer.position.y + dreamer.BODY_SIZE.y / 2.0 - SCRAP.SIZE.y / 2.0)
	at.x = clampf(at.x, room.WALL + SCRAP.SIZE.x / 2.0, room.SIZE.x - room.WALL - SCRAP.SIZE.x / 2.0)
	place_scrap(shape, at)
	lucidity += 1
	acted.emit("set_down_scrap", shape)
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
	_blink_from = shown_aperture()   # read before blinking is set: the shut starts from what is shown now
	blinking = true
	blink_left = BLINK
	_shut_frames = 0
	_open_frames = 0
	dreamer.freeze()
	lucidity += 1
	acted.emit("fail", reason)
	_shown = 0.0   # the frame shuts over BLINK_SHUT_FRAMES, holds, and reopens over BLINK_OPEN_FRAMES
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


## A scrap lying in the room, hung by the dealer or set down: a small crisp
## body at `at` (its middle), named from scraps.json.
func place_scrap(shape: String, at: Vector2) -> StaticBody2D:
	var scrap: StaticBody2D = SCRAP.new()
	scrap.setup(shape, scrap_name(shape))
	scrap.position = at
	scraps_node.add_child(scrap)
	return scrap


## The shapes of the scraps lying in the room in play, in order.
func scraps_in_room() -> Array[String]:
	var shapes: Array[String] = []
	if scraps_node != null:
		for scrap in scraps_node.get_children():
			shapes.append(scrap.shape)
	return shapes


## The nearest scrap whose box is within GRAB_REACH of the dreamer's box.
func scrap_in_reach() -> StaticBody2D:
	var best: StaticBody2D = null
	var best_distance := INF
	if scraps_node == null:
		return null
	var hand: Rect2 = dreamer.rect().grow(GRAB_REACH)
	for scrap in scraps_node.get_children():
		if not hand.intersects(scrap.rect(), true):
			continue
		var distance: float = dreamer.position.distance_to(scrap.position)
		if distance < best_distance:
			best = scrap
			best_distance = distance
	return best


## Every scrap in every room of the night as dealt, counted.
func scraps_dealt() -> int:
	var n := 0
	for id in tonight_scraps:
		n += tonight_scraps[id].size()
	return n


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


## A quiet spot the dreamer overlaps whose wonder is still to be had this visit.
func spot_in_reach() -> Area2D:
	for node in get_tree().get_nodes_in_group("wonder"):
		if node.kind == "spot" and not wonders_seen.has(node.id) and node.overlaps_body(dreamer):
			return node
	return null


## True within EXIT_NEAR px of one of the room's exit zones.
func exit_near() -> bool:
	if room == null:
		return false
	for zone in room.exits():
		if Rect2(zone.position, zone.size).grow(EXIT_NEAR).intersects(dreamer.rect()):
			return true
	return false


# --- the dev bar -----------------------------------------------------------------

## ONLY what can be done right now, from the state, in devbar.json's words:
## asleep (drift, pinch) with the current and the spot when inside one;
## pinched on the floor (walk, jump, let go) or in the air (let go), with
## the grab when an idea is in reach and the hat has room, the set-down
## when something is carried on a floor, the push when the block is in
## reach and unpushed; the exit when near it; the bed when in reach.
## Nothing while the frame blinks, closes or the night is over.
func devbar_text() -> String:
	if not _can_act():
		return ""
	var w: Dictionary = devbar_words.get("dream", {})
	var parts: Array[String] = []
	if not dreamer.pinched:
		parts.append(str(w.get("asleep", "")))
		if not dreamer.carried_by.is_empty():
			parts.append(str(w.get("current", "")))
	else:
		parts.append(str(w.get("pinched" if dreamer.is_on_floor() else "falling", "")))
		if can_reach():
			parts.append(str(w.get("reach", "")))
		elif idea_in_reach() != null and carried.size() < state.carry_limit:
			parts.append(str(w.get("grab", "")))
		if scrap_in_reach() != null and scraps_carried.size() < state.carry_scraps:
			parts.append(str(w.get("scrap", "")))
		if dreamer.is_on_floor() and not carried.is_empty():
			parts.append(str(w.get("set_down", "")))
		elif dreamer.is_on_floor() and not scraps_carried.is_empty():
			parts.append(str(w.get("set_down_scrap", "")))
		if block != null and not forced and block_in_reach():
			parts.append(str(w.get("push", "")))
		if dreamer.is_on_floor() and spot_in_reach() == null:
			parts.append(str(w.get("self_pinch", "")).format({"s": "%.1f" % maxf(SELF_PINCH - _hold, 0.0)}))
	if spot_in_reach() != null:
		parts.append(str(w.get("wonder", "")))
	if current_room_id() == HUB and room != null and not room.exits().is_empty():
		var texts := sign_texts()
		parts.append(str(w.get("signs", "")).format({"left": texts.left, "right": texts.right}))
	if exit_near():
		parts.append(str(w.get("exit", "")))
	if bed_in_reach():
		parts.append(str(w.get("bed", "")))
	return str(devbar_words.get("separator", " · ")).join(parts)


## The room's hint as the dev bar shows it (rooms.json).
func hint_text() -> String:
	return devbar.hint_text()


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


func _can_act() -> bool:
	return not woken and not closing and not blinking


func _interact() -> void:
	if not _can_act():
		return
	if dreamer.pinched and (reach() or grab() or grab_scrap() or force()):
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


## Standing pinched in an exit deals the next room; in the hub, an exit
## whose branch is not tonight's (the other sign) retargets the night
## first. A branch room's exit only leads on (its branch is on it for the
## record; a night dealt by hand keeps its order).
func _check_exit() -> void:
	if not dreamer.pinched or not dreamer.is_on_floor():
		return
	for zone in room.exits():
		if zone.overlaps_body(dreamer):
			var who := str(zone.get_meta("branch", ""))
			if current_room_id() == HUB and who != "" and who != state.target:
				retarget(who)
			next_room()
			return


# --- the self-pinch --------------------------------------------------------------

## The hold grows while PINCH is held standing still on a floor with no
## movement input; anything else resets it; at SELF_PINCH seconds the
## dreamer wakes on purpose (self_pinch).
func _update_hold(delta: float) -> void:
	var still: bool = dreamer.pinched and dreamer.is_on_floor() and Input.get_axis("move_left", "move_right") == 0.0 and not Input.is_action_pressed("jump") and dreamer.is_still()
	if not still or spot_in_reach() != null:
		_hold = 0.0
		return
	_hold += delta
	if _hold + HOLD_EPSILON >= SELF_PINCH:
		self_pinch()


## Seconds PINCH has been held still on a floor so far this hold.
func hold_seconds() -> float:
	return _hold


## True while the hold is past FLICKER_FROM: the frame is flickering.
func flickering() -> bool:
	return _hold >= FLICKER_FROM and not woken


## Woken on purpose: every scrap comes up, no idea; not on the tally.
func self_pinch() -> void:
	if not _can_act():
		return
	_self_pinched = true
	acted.emit("self_pinch", "%.1f" % _hold)
	_wake(false)


func self_pinched() -> bool:
	return _self_pinched


## Soft things are seen only asleep: hidden, and their shapes off, while pinched.
func _apply_soft(pinched: bool) -> void:
	for node in get_tree().get_nodes_in_group("soft"):
		if node is CanvasItem:
			node.visible = not pinched
		for shape in node.find_children("*", "CollisionShape2D", true, false):
			shape.disabled = pinched


## The dreamer back at the door; the frame reopens over BLINK_OPEN_FRAMES
## (shown_aperture scales the eased value, which is the aperture itself).
## Within THIN_STEPS of the limit the soft shapes dim (THIN); else plain.
func _apply_thin() -> void:
	var modulate := THIN if thin() else Color.WHITE
	for node in get_tree().get_nodes_in_group("soft"):
		if node is CanvasItem:
			node.modulate = modulate


func _reopen() -> void:
	blinking = false
	_settle()
	_shown = aperture()
	_ease_from = _shown
	_ease_to = _shown
	_ease_t = EASE
	_open_frames = BLINK_OPEN_FRAMES
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
	state.scraps_carried.assign(scraps_carried)
	dreamer.set_hat(carried.size(), in_hand())
	dreamer.set_hip(scraps_carried.size())
	if not is_equal_approx(_ease_to, aperture()):
		_ease_from = _shown
		_ease_to = aperture()
		_ease_t = 0.0
	var share := float(effective()) / float(limit())
	if not is_equal_approx(_needle_to, share):
		_needle_from = _needle
		_needle_to = share
		_needle_t = 0.0
	_apply_thin()
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
	state.gauge_visible = gauge_visible
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
## clamped inside the viewport, rounded to whole pixels; four black rects
## around it, the left and right ones reaching FRAME_OVERLAP px into the
## top and bottom ones (over black), so no seam shows at a shared edge.
func _update_frame() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var open := (screen * shown_aperture()).round()
	var corner := (dreamer_screen_position() - open / 2.0).clamp(Vector2.ZERO, screen - open).round()
	frame_open = Rect2(corner, open)
	frame_top.position = Vector2.ZERO
	frame_top.size = Vector2(screen.x, corner.y)
	frame_bottom.position = Vector2(0, corner.y + open.y)
	frame_bottom.size = Vector2(screen.x, screen.y - corner.y - open.y)
	frame_left.position = Vector2(0, corner.y - FRAME_OVERLAP)
	frame_left.size = Vector2(corner.x, open.y + FRAME_OVERLAP * 2.0)
	frame_right.position = Vector2(corner.x + open.x, corner.y - FRAME_OVERLAP)
	frame_right.size = Vector2(screen.x - corner.x - open.x, open.y + FRAME_OVERLAP * 2.0)


## The four frame rects as drawn, in order: top, bottom, left, right.
func frame_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for rect in [frame_top, frame_bottom, frame_left, frame_right]:
		rects.append(Rect2(rect.position, rect.size))
	return rects


func _wake(sudden: bool) -> void:
	if woken:
		return
	woken = true
	closing = false
	woke.emit(sudden, carried.duplicate())
