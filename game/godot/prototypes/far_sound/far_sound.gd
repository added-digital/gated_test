extends Node3D
## Toy 3, Far sound (rung 3). You start in a grey courtyard. A chime rings
## somewhere beyond the walls, ahead. The gap in the wall ahead leads to an
## alley that ends. Out the open back and around the outside works. A narrow
## slit in the east wall, behind a baffle, is the short way through. Walk
## up to the chime and the ringing stops, one resolved chord plays, and one
## line appears. Nothing else. One verb: find the way.
##
## Every word the player reads is in lines.json next to this script:
##   start     shown for START_STAYS seconds at the spawn
##   arrived   shown when the chime is reached
## The walls are a table in layout.gd. Rewrite those, not this.

const LINES_FILE := "res://prototypes/far_sound/lines.json"
const Layout := preload("res://prototypes/far_sound/layout.gd")
const START_STAYS := 4.0   # s the start line stays on screen
const ARRIVE := 2.0        # m from the chime: arrived

@onready var player: CharacterBody3D = $Player
@onready var source: Node3D = $Source
@onready var chime: AudioStreamPlayer3D = $Source/Chime   # the loop
@onready var chord: AudioStreamPlayer3D = $Source/Chord   # played once on arrival
@onready var panel: CanvasLayer = $TextPanel
@onready var harness: Node = $Harness

var lines: Dictionary = {}
var arrived := false
var start_timer := 0.0
var last_pos := Vector3.ZERO   # where the player stood last physics frame, for the gap crossings


func _ready() -> void:
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_FILE))
	lines = loaded if loaded is Dictionary else {}
	if lines.is_empty():
		push_error("[far_sound] cannot read %s" % LINES_FILE)
	harness.start("far_sound")
	chime.play()
	panel.say(lines.get("start", ""))
	start_timer = START_STAYS
	last_pos = player.global_position
	print("[far_sound] the chime is %.1f m from the spawn, %s" % [_flat(player).distance_to(_flat(source)), "looping" if chime.stream is AudioStreamWAV and chime.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED else "NOT looping"])


func _process(delta: float) -> void:
	if start_timer > 0.0:
		start_timer -= delta
		if start_timer <= 0.0:
			panel.say("")


func _physics_process(_delta: float) -> void:
	var pos := player.global_position
	_watch_gaps(last_pos, pos)
	last_pos = pos
	var flat := _flat(player)
	if not Layout.COURTYARD.has_point(flat):
		harness.milestone("left_courtyard")
	if Layout.DEAD_END.has_point(flat):
		harness.milestone("dead_end")
	if not arrived and flat.distance_to(_flat(source)) <= ARRIVE:
		_arrive()


## The chime stops, the chord plays, the line appears. Once.
func _arrive() -> void:
	arrived = true
	chime.stop()
	chord.play()
	start_timer = 0.0   # so the start line's timer cannot clear this line
	panel.say(lines.get("arrived", ""))
	harness.milestone("arrived")
	print("[far_sound] arrived at (%.1f, %.1f)" % [player.global_position.x, player.global_position.z])


## Count a walk through either gap, with its direction: "out" is away from the courtyard.
func _watch_gaps(prev: Vector3, now: Vector3) -> void:
	if prev.distance_to(now) > 1.0:
		return   # a jump (the respawn after a fall), not a walk
	if _crossed(prev.z, now.z, Layout.NORTH_WALL_Z) and _within(now.x, Layout.OBVIOUS_GAP_X):
		harness.action("gap_used", "obvious " + ("out" if now.z < prev.z else "back"))
	if _crossed(prev.x, now.x, Layout.EAST_WALL_X) and _within(now.z, Layout.NARROW_GAP_Z):
		harness.action("gap_used", "narrow " + ("out" if now.x > prev.x else "back"))


static func _crossed(a: float, b: float, line: float) -> bool:
	return (a < line) != (b < line)


static func _within(v: float, span: Vector2) -> bool:
	return v >= span.x and v <= span.y


## A node's position on the ground, (x, z).
static func _flat(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)


## Quitting while a stream plays leaves the audio server holding the playback,
## reported as "resources still in use at exit". Stop both and give the mix
## thread a moment before the scene goes away (the harness log is written by
## the Harness node's own _exit_tree, unaffected).
func _exit_tree() -> void:
	chime.stop()
	chord.stop()
	OS.delay_msec(200)
