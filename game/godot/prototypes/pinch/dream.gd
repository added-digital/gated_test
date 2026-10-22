extends Node2D
## The dream of toy 4, PINCH: day 1's stub, one room. The dreamer drifts
## asleep and walks only while PINCH is held. Lucidity is an integer moved
## only by acts (the SPEC table: grab +2, force +1, a hard fall +1; holding
## the button is free); effective lucidity adds the ideas carried; the
## frame, four black rects on a CanvasLayer, closes to
## aperture = 1 - effective / limit. At the limit the dream emits
## woke(true, carried); E on the bed emits woke(false, carried). Idea names
## come from data/ideas.json and the room's words from data/village.json;
## rewrite those, not this.

signal woke(sudden: bool, carried: Array)
signal acted(kind: String, detail: String)

const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const WORDS_FILE := "res://prototypes/pinch/data/village.json"
const IDEA_SPOTS := [Vector2(460, 580), Vector2(640, 580)]   # the first two ideas lie here
const REACH := 72.0       # px: this close to an idea, the block or the bed, E acts on it
const PUSH := 48.0        # px a forced block slides
const IDEA_SIZE := 40.0   # px: an idea is a white square with a black edge and a shadow

@onready var dreamer: CharacterBody2D = $Dreamer
@onready var ideas_node: Node2D = $Ideas
@onready var block: StaticBody2D = $Block
@onready var bed: ColorRect = $Bed
@onready var frame_top: ColorRect = $Frame/Top
@onready var frame_bottom: ColorRect = $Frame/Bottom
@onready var frame_left: ColorRect = $Frame/Left
@onready var frame_right: ColorRect = $Frame/Right

var state: PinchState               # set by the controller before add_child; a fresh one when run alone
var lucidity := 0                   # moves only in grab(), force(), fall()
var carried: Array[String] = []     # idea ids under the hat
var ideas: Array = []               # ideas.json, in order
var frame_open := Rect2()           # the visible rectangle inside the frame, in screen px
var forced := false                 # the block has been pushed (once per visit)
var woken := false


func _ready() -> void:
	if state == null:
		state = PinchState.new()
	var loaded: Variant = PinchState.load_json(IDEAS_FILE)
	ideas = loaded if loaded is Array else []
	loaded = PinchState.load_json(WORDS_FILE)
	var room: Dictionary = (loaded if loaded is Dictionary else {}).get("dream", {})
	$Bed/Name.text = str(room.get("bed", ""))
	$Block/Name.text = str(room.get("block", ""))
	for i in mini(IDEA_SPOTS.size(), ideas.size()):
		_spawn_idea(ideas[i], IDEA_SPOTS[i])
	dreamer.hard_landing.connect(fall)
	_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()


func limit() -> int:
	return state.lucidity_limit


func effective() -> int:
	return lucidity + carried.size()


func aperture() -> float:
	return clampf(1.0 - float(effective()) / float(limit()), 0.0, 1.0)


## Take the idea in reach while pinched: +2, under the hat, gone from the room.
func grab() -> bool:
	if woken or not dreamer.pinched or carried.size() >= state.carry_limit:
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


## Push the block in reach while pinched: +1, once.
func force() -> bool:
	if woken or forced or not dreamer.pinched or not block_in_reach():
		return false
	forced = true
	block.position.x += PUSH
	lucidity += 1
	acted.emit("force", "block")
	_changed()
	return true


## A hard landing while pinched (the dreamer reports it): +1.
func fall() -> void:
	if woken:
		return
	lucidity += 1
	acted.emit("fall", "")
	_changed()


## Lie in the bed in reach: wake gently with everything.
func lie_down() -> bool:
	if woken or not bed_in_reach():
		return false
	acted.emit("lie_down", "")
	_wake(false)
	return true


func idea_in_reach() -> Node2D:
	var best: Node2D = null
	var best_distance := REACH
	for idea in ideas_node.get_children():
		var distance: float = dreamer.position.distance_to(idea.position)
		if distance <= best_distance:
			best = idea
			best_distance = distance
	return best


func block_in_reach() -> bool:
	return dreamer.position.distance_to(block.position) <= REACH


func bed_in_reach() -> bool:
	return dreamer.position.distance_to(bed.position + bed.size / 2.0) <= REACH


func _interact() -> void:
	if woken:
		return
	if dreamer.pinched and (grab() or force()):
		return
	lie_down()


## After every act: the hat, the frame, and the limit.
func _changed() -> void:
	state.ideas_carried.assign(carried)
	dreamer.set_hat(carried.size())
	_update_frame()
	if effective() >= limit():
		_wake(true)


func _update_frame() -> void:
	var screen := get_viewport().get_visible_rect().size
	var open := screen * aperture()
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
