extends Node2D
## The dream of toy 4, PINCH, day 2: the room dealer, the frame, lucidity.
##
## Each night deals rooms one at a time under Rooms: the tutorial first on
## night 1 only, then the rooms of data/rooms.json shuffled by a generator
## seeded with state.day (so a test can predict the order with deal()),
## then the bed room last. The dreamer (one body, kept across rooms) is put
## at each room's Door; standing pinched in a room's Exit deals the next.
## The frame, four black rects on a CanvasLayer, persists across rooms and
## closes to aperture = 1 - effective / limit.
##
## Lucidity is an integer moved only by acts (the SPEC table): grab +2,
## set down +1 (reserved for day 3), force +1, a hard fall while pinched
## +1, a failed screen +1, wonder -1 once per wonder per visit (drift
## through a soft wall asleep, ride the goat, stay still 3 s in a spot);
## never below 0; holding the button is free. effective adds the ideas
## carried. A failed screen (fell below the room, or touched a hazard
## pinched) blinks: the frame shuts for BLINK seconds, then the dreamer is
## back at the Door. At the limit the dream emits woke(true, carried); E on
## the bed emits woke(false, carried). Idea names come from
## data/ideas.json, every other word from data/rooms.json; rewrite those,
## not this.

signal woke(sudden: bool, carried: Array)
signal acted(kind: String, detail: String)
signal room_entered(id: String)

const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const ROOM_SCENES := {
	"tutorial": preload("res://prototypes/pinch/rooms/room_tutorial.tscn"),
	"a": preload("res://prototypes/pinch/rooms/room_a.tscn"),
	"b": preload("res://prototypes/pinch/rooms/room_b.tscn"),
	"bed": preload("res://prototypes/pinch/rooms/room_bed.tscn"),
}
const TUTORIAL := "tutorial"
const BED := "bed"
const ROOMS_PER_NIGHT := 4    # SPEC: four dealt plus the bed; day 2 has only two to deal
const PLACEHOLDER_IDEAS := 2  # until day 3 deals ideas, the first two lie in the bed room
const REACH := 72.0           # px: this close to an idea, the block or the bed, E acts on it
const PUSH := 48.0            # px a forced block slides
const IDEA_SIZE := 40.0       # px: an idea is a white square with a black edge and a shadow
const BLINK := 1.0            # s the frame stays shut after a failed screen (SPEC: one second)
const STILL := 3.0            # s still inside a spot for its wonder

@onready var dreamer: CharacterBody2D = $Dreamer
@onready var rooms_holder: Node2D = $Rooms
@onready var room_label: Label = $Hud/RoomLabel
@onready var frame_top: ColorRect = $Frame/Top
@onready var frame_bottom: ColorRect = $Frame/Bottom
@onready var frame_left: ColorRect = $Frame/Left
@onready var frame_right: ColorRect = $Frame/Right

var state: PinchState               # set by the controller before add_child; a fresh one when run alone
var lucidity := 0                   # moves only in grab(), set_down(), force(), fall(), fail(), wonder()
var carried: Array[String] = []     # idea ids under the hat
var ideas: Array = []               # ideas.json, in order
var rooms_data: Array = []          # rooms.json "rooms", in order
var words: Dictionary = {}          # rooms.json "words"
var label_format := "{name}. {hint}"
var tonight: Array[String] = []     # the room ids dealt, in order
var room_index := -1
var room: Node2D = null             # the room in play
var ideas_node: Node2D = null       # the room's Ideas
var block: StaticBody2D = null      # the room's Block, if any
var bed: ColorRect = null           # the room's Bed, if any
var frame_open := Rect2()           # the visible rectangle inside the frame, in screen px
var forced := false                 # the block has been pushed (once per visit)
var woken := false
var wonders_seen := {}              # wonder id -> true, this visit
var blinking := false
var blink_left := 0.0
var blinks := 0                     # failed screens this night
var hard_falls := 0
var _still := {}                    # spot id -> s the dreamer has been still inside it
var _grace := 0                     # frames after a respawn in which the polls below are skipped (see _settle)


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
	dreamer.hard_landing.connect(fall)
	dreamer.fell_out.connect(fail.bind("fell"))
	dreamer.pinch_changed.connect(_apply_soft)
	tonight = deal(state.day)
	_enter_room(0)
	_changed()


func _physics_process(delta: float) -> void:
	if woken:
		return
	if blinking:
		blink_left -= delta
		if blink_left <= 0.0:
			_reopen()
		return
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


# --- the dealer ---------------------------------------------------------------

## The rooms of one night, in order: the tutorial on night 1 only, then the
## other rooms shuffled by a generator seeded with the day, then the bed.
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
	order.append(BED)
	return order


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


## Straight to one of tonight's rooms (for tests and the designer).
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


func _enter_room(index: int) -> void:
	if room != null:
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
	forced = false
	wonders_seen = {}
	_still = {}
	blinking = false
	var entry := room_words(id)
	room_label.text = label_format.format({"name": str(entry.get("name", id)), "hint": str(entry.get("hint", ""))})
	if id == BED:
		var spots: Array[Vector2] = room.idea_spots()
		for i in mini(PLACEHOLDER_IDEAS, mini(spots.size(), ideas.size())):
			_spawn_idea(ideas[i], spots[i])
	_settle()
	_apply_soft(dreamer.pinched)
	acted.emit("enter", id)
	room_entered.emit(id)


# --- lucidity -----------------------------------------------------------------

func limit() -> int:
	return state.lucidity_limit


func effective() -> int:
	return lucidity + carried.size()


func aperture() -> float:
	return clampf(1.0 - float(effective()) / float(limit()), 0.0, 1.0)


## What the frame shows: shut during a blink, the aperture otherwise.
func shown_aperture() -> float:
	return 0.0 if blinking else aperture()


## Take the idea in reach while pinched: +2, under the hat, gone from the room.
func grab() -> bool:
	if woken or blinking or not dreamer.pinched or carried.size() >= state.carry_limit:
		return false
	var idea := idea_in_reach()
	if idea == null:
		return false
	var id: String = idea.get_meta("id")
	carried.append(id)
	ideas_node.remove_child(idea)
	idea.queue_free()
	lucidity += 2
	acted.emit("grab", id)
	_changed()
	return true


## Set a carried idea down as a step: +1. Reserved: day 3 builds it.
func set_down() -> bool:
	return false


## Push the block in reach while pinched: +1, once per visit.
func force() -> bool:
	if woken or blinking or forced or block == null or not dreamer.pinched or not block_in_reach():
		return false
	forced = true
	block.position.x += PUSH
	lucidity += 1
	acted.emit("force", "block")
	_changed()
	return true


## A hard landing while pinched (the dreamer reports it): +1.
func fall() -> void:
	if woken or blinking:
		return
	hard_falls += 1
	lucidity += 1
	acted.emit("fall", "")
	_changed()


## A failed screen (fell out, or a hazard while pinched): blink shut, +1,
## then back at the door.
func fail(reason: String) -> void:
	if woken or blinking:
		return
	blinks += 1
	blinking = true
	blink_left = BLINK
	dreamer.freeze()
	lucidity += 1
	acted.emit("fail", reason)
	_changed()


## A wonder, once per visit: -1, never below 0.
func wonder(id: String, kind: String) -> bool:
	if woken or blinking or wonders_seen.has(id):
		return false
	wonders_seen[id] = true
	lucidity = maxi(0, lucidity - 1)
	acted.emit("wonder:%s" % id, kind)
	_changed()
	return true


## Lie in the bed in reach: wake gently with everything.
func lie_down() -> bool:
	if woken or blinking or not bed_in_reach():
		return false
	acted.emit("lie_down", "")
	_wake(false)
	return true


func idea_in_reach() -> Node2D:
	var best: Node2D = null
	var best_distance := REACH
	if ideas_node == null:
		return null
	for idea in ideas_node.get_children():
		var distance: float = dreamer.position.distance_to(idea.position)
		if distance <= best_distance:
			best = idea
			best_distance = distance
	return best


func block_in_reach() -> bool:
	return block != null and dreamer.position.distance_to(block.position + block.size / 2.0) <= REACH


func bed_in_reach() -> bool:
	return bed != null and dreamer.position.distance_to(bed.position + bed.size / 2.0) <= REACH


func _interact() -> void:
	if woken or blinking:
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
	_update_frame()


## The dreamer back at the door. A kinematic body's new place reaches the
## physics server one step late, so for two frames the areas still report
## the overlaps of where it was (the hazard it fell into, the exit it stood
## in): the polls wait those frames out.
func _settle() -> void:
	dreamer.respawn(room.door.position)
	_grace = 2


## After every act: the hat, the frame, and the limit.
func _changed() -> void:
	state.ideas_carried.assign(carried)
	dreamer.set_hat(carried.size())
	_update_frame()
	if effective() >= limit():
		_wake(true)


func _update_frame() -> void:
	var screen := get_viewport().get_visible_rect().size
	var open := screen * shown_aperture()
	var corner := (screen - open) / 2.0
	frame_open = Rect2(corner, open)
	frame_top.position = Vector2.ZERO
	frame_top.size = Vector2(screen.x, corner.y)
	frame_bottom.position = Vector2(0, corner.y + open.y)
	frame_bottom.size = Vector2(screen.x, corner.y)
	frame_left.position = Vector2(0, corner.y)
	frame_left.size = Vector2(corner.x, open.y)
	frame_right.position = Vector2(corner.x + open.x, corner.y)
	frame_right.size = Vector2(corner.x, open.y)


func _wake(sudden: bool) -> void:
	if woken:
		return
	woken = true
	woke.emit(sudden, carried.duplicate())


## A crisp idea: white, black-edged, with a drop shadow, its name above.
func _spawn_idea(idea: Dictionary, at: Vector2) -> void:
	var node := Node2D.new()
	node.name = "Idea_%s" % idea.get("id", "")
	node.position = at
	node.set_meta("id", str(idea.get("id", "")))
	node.add_to_group("crisp")
	var half := IDEA_SIZE / 2.0
	_square(node, Vector2(-half + 5, -half + 5), IDEA_SIZE, Color(0, 0, 0, 0.45))
	_square(node, Vector2(-half - 2, -half - 2), IDEA_SIZE + 4, Color.BLACK)
	_square(node, Vector2(-half, -half), IDEA_SIZE, Color.WHITE)
	var label := Label.new()
	label.text = str(idea.get("name", ""))
	label.position = Vector2(-110, -half - 28)
	label.size = Vector2(220, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label)
	ideas_node.add_child(node)


func _square(parent: Node, at: Vector2, side: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = Vector2(side, side)
	rect.color = color
	parent.add_child(rect)
