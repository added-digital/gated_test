extends Node3D
## Toy 3, Far sound (rung 3). One verb, find the way, three times over, each
## search longer than the last. You start in a grey courtyard. A chime rings
## beyond the walls ahead: the obvious gap dead-ends, the slit behind the
## baffle or the way round the outside gets you there. Walk up to it: the
## ringing stops, one resolved chord plays, a line shows. Three seconds
## later a second chime starts, in a walled yard to the south-west whose one
## opening faces away; the slit is no help, the way is round the outside.
## Reach it, the same again, and a third chime starts: in a pen to the east,
## right behind a gate slab that will not move from your side. The way round
## to the pen's far opening is the longest; stepping into the pen's west
## half slides the gate away, and it stays open: a short way back. At the
## third chime the toy is done. Nothing else.
##
## Every word the player reads is in lines.json next to this script:
##   start              shown for START_STAYS seconds at the spawn
##   arrived_1/2/3      shown at each chime; the first two clear when the next chime starts
## The walls are a table in layout.gd. The chimes sit under Source1..3 in
## the scene, the gate slab is the Gate node, its trigger GateTrigger.
## Rewrite those, not this.

const LINES_FILE := "res://prototypes/far_sound/lines.json"
const Layout := preload("res://prototypes/far_sound/layout.gd")
const START_STAYS := 4.0      # s the start line stays on screen
const ARRIVE := 2.0           # m from a chime: arrived
const NEXT_AFTER := 3.0       # s after an arrival before the next chime starts
const GATE_SLIDE_TIME := 1.2  # s the gate slab takes to slide away

@onready var player: CharacterBody3D = $Player
@onready var sources: Array[Node3D] = [$Source1, $Source2, $Source3]
@onready var chimes: Array[AudioStreamPlayer3D] = [$Source1/Chime, $Source2/Chime, $Source3/Chime]   # the loops
@onready var chords: Array[AudioStreamPlayer3D] = [$Source1/Chord, $Source2/Chord, $Source3/Chord]   # once each, on arrival
@onready var gate: AnimatableBody3D = $Gate
@onready var gate_trigger: Area3D = $GateTrigger
@onready var panel: CanvasLayer = $TextPanel
@onready var harness: Node = $Harness

var lines: Dictionary = {}
var search := 0         # which chime rings now: 0, 1 or 2
var arrived := 0        # how many chimes have been reached, 0..3
var done := false       # the third chime reached: nothing rings any more
var gate_open := false
var start_timer := 0.0
var next_timer := 0.0   # > 0 during the pause between an arrival and the next chime
var last_pos := Vector3.ZERO   # where the player stood last physics frame, for the crossings


func _ready() -> void:
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_FILE))
	lines = loaded if loaded is Dictionary else {}
	if lines.is_empty():
		push_error("[far_sound] cannot read %s" % LINES_FILE)
	harness.start("far_sound")
	gate_trigger.body_entered.connect(_on_gate_trigger)
	chimes[0].play()
	panel.say(lines.get("start", ""))
	start_timer = START_STAYS
	last_pos = player.global_position
	print("[far_sound] chime 1 is %.1f m from the spawn, chime 2 %.1f m from chime 1, chime 3 %.1f m from chime 2; the loop is %s" % [
		_flat(player).distance_to(_flat(sources[0])), _flat(sources[0]).distance_to(_flat(sources[1])),
		_flat(sources[1]).distance_to(_flat(sources[2])),
		"looping" if chimes[0].stream is AudioStreamWAV and chimes[0].stream.loop_mode != AudioStreamWAV.LOOP_DISABLED else "NOT looping"])


func _process(delta: float) -> void:
	if start_timer > 0.0:
		start_timer -= delta
		if start_timer <= 0.0:
			panel.say("")
	if next_timer > 0.0:
		next_timer -= delta
		if next_timer <= 0.0:
			search += 1
			panel.say("")
			chimes[search].play()
			print("[far_sound] chime %d rings, %.1f m from the player" % [search + 1, _flat(player).distance_to(_flat(sources[search]))])


func _physics_process(_delta: float) -> void:
	var pos := player.global_position
	_watch_crossings(last_pos, pos)
	last_pos = pos
	var flat := _flat(player)
	if not Layout.COURTYARD.has_point(flat):
		harness.milestone("left_courtyard")
	if Layout.DEAD_END.has_point(flat):
		harness.milestone("dead_end")
	if not gate_open and Layout.GATE_FRONT.has_point(flat):
		harness.milestone("gate_found")
	if not done and next_timer <= 0.0 and flat.distance_to(_flat(sources[search])) <= ARRIVE:
		_arrive()


## The chime stops, its chord plays, the line appears; the next chime
## follows after NEXT_AFTER seconds, or nothing after the third.
func _arrive() -> void:
	chimes[search].stop()
	chords[search].play()
	arrived = search + 1
	start_timer = 0.0   # so the start line's timer cannot clear this line
	panel.say(lines.get("arrived_%d" % arrived, ""))
	harness.milestone("arrived_%d" % arrived)
	print("[far_sound] chime %d reached at (%.1f, %.1f)" % [arrived, player.global_position.x, player.global_position.z])
	if arrived < sources.size():
		next_timer = NEXT_AFTER
	else:
		done = true


## The pen's west half: stepping in from the far side slides the gate away, once, for good.
func _on_gate_trigger(body: Node3D) -> void:
	if gate_open or body != player:
		return
	gate_open = true
	harness.milestone("gate_opened")
	var tween := create_tween()
	tween.tween_property(gate, "position", gate.position + Layout.GATE_SLIDE, GATE_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	print("[far_sound] the gate slides open")


## Count a walk across any line in Layout.CROSSINGS, with its direction.
func _watch_crossings(prev: Vector3, now: Vector3) -> void:
	if prev.distance_to(now) > 1.0:
		return   # a jump (the respawn after a fall), not a walk
	for c in Layout.CROSSINGS:
		var on_z: bool = c[2] == "z"
		var a: float = prev.z if on_z else prev.x
		var b: float = now.z if on_z else now.x
		var across: float = now.x if on_z else now.z
		if _crossed(a, b, c[3]) and _within(across, c[4]):
			harness.action(c[0], "%s %s" % [c[1], c[5] if b < a else c[6]])


static func _crossed(a: float, b: float, line: float) -> bool:
	return (a < line) != (b < line)


static func _within(v: float, span: Vector2) -> bool:
	return v >= span.x and v <= span.y


## A node's position on the ground, (x, z).
static func _flat(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)


## Quitting while a stream plays leaves the audio server holding the playback,
## reported as "resources still in use at exit". Stop every player and give
## the mix thread a moment before the scene goes away (the harness log is
## written by the Harness node's own _exit_tree, unaffected).
func _exit_tree() -> void:
	for p in chimes + chords:
		p.stop()
	OS.delay_msec(200)
