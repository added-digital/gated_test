extends Node3D
## Scripted play of toy 3, Far sound (prototypes/far_sound/far_sound.tscn),
## headless. The player is driven through the physics engine with auto_move,
## as in the walk test; nothing is teleported. The run: at the spawn, the
## start line is up, the chime loops, and a ray from the eye to the chime
## hits a wall; through the obvious gap into the alley to its dead end and
## back; then the short way: behind the baffle, through the 0.9 m slit, up
## the outside of the east wall, round the block to the chime, where the loop
## must have stopped, the chord started and the arrived line shown; last,
## the long way in reverse: from the chime down the outside and in through
## the courtyard's open south end, with no gap crossed on the way. Prints
## PASS/FAIL per check and quits with 0 only if every check passes. Audio
## does not play headless: the streams must load and the players must exist.

const TOY := preload("res://prototypes/far_sound/far_sound.tscn")
const Layout := preload("res://prototypes/far_sound/layout.gd")
const CHIME := "res://prototypes/far_sound/chime.wav"
const CHORD := "res://prototypes/far_sound/chord.wav"

# Waypoints on the ground (x, z); the player starts at (0, 0) facing north (-z).
const OBVIOUS_ROUTE: Array[Vector2] = [Vector2(0, -5), Vector2(0, -8.3), Vector2(3.3, -8.3), Vector2(3.3, -10.9)]
const BACK_ROUTE: Array[Vector2] = [Vector2(3.3, -8.3), Vector2(0, -8.3), Vector2(0, -5), Vector2(0, 0)]
const NARROW_ROUTE: Array[Vector2] = [Vector2(5.5, 0.5), Vector2(5.5, -3.0), Vector2(7.5, -3.0), Vector2(7.5, -13.5), Vector2(1.5, -16.5), Vector2(0, -16.3)]
const AROUND_ROUTE: Array[Vector2] = [Vector2(7.5, -13.5), Vector2(7.5, 9.5), Vector2(0, 9.5), Vector2(0, 0)]   # the long way, walked backwards
const REACHED := 0.1       # m: close enough to steer for the next waypoint
const FRAMES_PER_M := 40   # budget: 3.5 m/s is 17 frames per metre; allow more than double

var toy: Node3D
var player: CharacterBody3D
var panel: CanvasLayer
var harness: Node
var failures := 0


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	toy = TOY.instantiate()
	add_child(toy)
	player = toy.player
	panel = toy.panel
	harness = toy.harness
	await settle()

	# 1. The spawn: sounds, words, walls.
	var chime_stream: Variant = load(CHIME)
	var chord_stream: Variant = load(CHORD)
	check(chime_stream is AudioStreamWAV, "chime.wav loads as an AudioStreamWAV")
	check(chord_stream is AudioStreamWAV, "chord.wav loads as an AudioStreamWAV")
	check(chime_stream is AudioStreamWAV and chime_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and chime_stream.loop_end > 800000, "the chime's loop points came through the import: forward, frames 0..%d of a %.1f s stream" % [chime_stream.loop_end if chime_stream is AudioStreamWAV else -1, chime_stream.get_length() if chime_stream is AudioStreamWAV else -1.0])
	check(toy.chime is AudioStreamPlayer3D and toy.chime.stream == chime_stream, "the Chime player exists at the source and holds chime.wav")
	check(toy.chord is AudioStreamPlayer3D and toy.chord.stream == chord_stream, "the Chord player exists at the source and holds chord.wav")
	check(toy.chime.playing, "the chime is playing from the start")
	check(not toy.chord.playing, "the chord is not")
	check(harness.toy_name == "far_sound", "the harness was started as 'far_sound' (%s)" % harness.toy_name)
	check(panel.say_label.visible and panel.say_label.text == toy.lines.start, "the start line is on screen: '%s'" % panel.say_label.text)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "the player stands on the ground, feet at y = %.3f" % player.position.y)
	var dist: float = toy._flat(player).distance_to(toy._flat(toy.source))
	check(dist >= 15.0 and dist <= 20.0, "the chime is %.1f m from the spawn (15 to 20)" % dist)
	check(toy.get_node("Walls").get_child_count() == Layout.WALLS.size(), "%d walls stand (%d in the table)" % [toy.get_node("Walls").get_child_count(), Layout.WALLS.size()])
	check(is_equal_approx(Layout.NARROW_GAP_Z.y - Layout.NARROW_GAP_Z.x, 0.9), "the slit is 0.9 m wide")
	var hit := ray_to_source()
	check(not hit.is_empty() and str(hit.get("collider").name).begins_with("Wall"), "the direct line from the eye to the chime is blocked: %s" % describe(hit))

	# 2. The obvious gap, to the dead end and back.
	var frames := await walk(OBVIOUS_ROUTE, "the obvious way")
	check(harness.summary().contains("left_courtyard"), "milestone left_courtyard")
	check(harness.summary().contains("dead_end"), "milestone dead_end after %d frames" % frames)
	check(harness.summary().contains("gap_used  obvious out"), "action gap_used 'obvious out'")
	check(not harness.summary().contains("arrived"), "not arrived: the dead end is not the chime")
	frames = await walk(BACK_ROUTE, "back to the spawn")
	check(harness.summary().contains("gap_used  obvious back"), "action gap_used 'obvious back'")
	check(not panel.say_label.visible, "the start line is gone after %.0f s" % toy.START_STAYS)
	check(toy.chime.playing, "the chime still loops (%.1f s in)" % toy.chime.get_playback_position())

	# 3. The short way through the slit, round the outside, to the chime.
	frames = await walk(NARROW_ROUTE, "the short way")
	check(harness.summary().contains("gap_used  narrow out"), "action gap_used 'narrow out': the capsule fits the 0.9 m slit")
	check(toy.arrived and harness.summary().contains("arrived"), "milestone arrived, %.2f m from the chime after %d frames" % [toy._flat(player).distance_to(toy._flat(toy.source)), frames])
	check(not toy.chime.playing, "the looping chime stopped")
	check(toy.chord.playing, "the chord is playing")
	check(panel.say_label.visible and panel.say_label.text == toy.lines.arrived, "the arrived line is on screen: '%s'" % panel.say_label.text)
	check(harness.summary().contains("  gap_used: 3"), "the harness counted 3 gap_used actions")

	# 4. The long way, in reverse: no wall between the chime and the open south end.
	frames = await walk(AROUND_ROUTE, "around the outside")
	check(Layout.COURTYARD.has_point(toy._flat(player)), "back inside the courtyard through its open south end after %d frames" % frames)
	check(harness.summary().contains("  gap_used: 3"), "no gap was crossed on the way around")

	print("--- summary() ---\n%s\n--- end ---" % harness.summary())
	print("RESULT: %d failure(s)" % failures)
	# Quitting while a sound plays leaves its playback in the audio server
	# (reported as leaked at exit): stop both and give the mix thread a moment.
	toy.chime.stop()
	toy.chord.stop()
	OS.delay_msec(200)
	get_tree().quit(0 if failures == 0 else 1)


## Let gravity put the capsule on the ground before driving it.
func settle() -> void:
	player.auto_move = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame


## Steer toward each waypoint in turn, one physics frame at a time. Returns the frames used.
func walk(route: Array[Vector2], what: String) -> int:
	var budget := 0
	var prev := Vector2(player.position.x, player.position.z)
	for p in route:
		budget += int(prev.distance_to(p) * FRAMES_PER_M) + 60
		prev = p
	var frames := 0
	var next := 0
	while next < route.size() and frames < budget:
		var to := Vector3(route[next].x, 0.0, route[next].y) - player.position
		to.y = 0.0
		if to.length() < REACHED:
			next += 1
			continue
		player.auto_move = to.normalized()
		await get_tree().physics_frame
		frames += 1
		if frames % 120 == 0:
			print("  frame %4d: at (%.2f, %.2f)" % [frames, player.position.x, player.position.z])
	player.auto_move = Vector3.ZERO
	await get_tree().physics_frame   # the toy reads the player's position a frame behind
	await get_tree().physics_frame
	print("%s: %d of %d waypoints in %d frames (budget %d), ended at (%.2f, %.2f)" % [what, next, route.size(), frames, budget, player.position.x, player.position.z])
	check(next == route.size(), "%s: every waypoint reached" % what)
	return frames


## The ray from the eye at the spawn to the chime's box, through the physics world.
func ray_to_source() -> Dictionary:
	var from: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	var to: Vector3 = toy.source.global_position
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


static func describe(hit: Dictionary) -> String:
	if hit.is_empty():
		return "nothing hit"
	var p: Vector3 = hit.position
	return "hit '%s' at (%.1f, %.1f, %.1f)" % [hit.collider.name, p.x, p.y, p.z]
