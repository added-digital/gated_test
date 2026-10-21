extends Node3D
## Scripted play of toy 3, Far sound (prototypes/far_sound/far_sound.tscn),
## headless: the three searches in a row. The player is driven through the
## physics engine with auto_move, as in the walk test; nothing is teleported.
## Search 1: at the spawn the start line is up, chime 1 loops alone, and a
## ray from the eye to it hits a wall; through the obvious gap to the dead
## end and back; then behind the baffle, through the 0.9 m slit, round the
## block to chime 1: arrived_1, the loop stopped, the chord started, the
## line shown; NEXT_AFTER seconds later chime 2 rings alone, the line gone,
## and the ray to chime 2 hits a wall. Search 2: round the north of the yard
## to its west opening and in: arrived_2, then chime 3 alone, its ray
## blocked. Search 3: out of the yard, round its south, up the east corridor
## to the gate: gate_found, the ray to chime 3 hits the gate slab, pushing
## does not pass it; round the north of the pen, in at its east opening,
## into the pen's west half: gate_opened before arrived_3, the slab slid
## clear, the ray from the corridor side clear, the toy done; then out
## through the gate, which stays open. Each scripted search takes more
## frames than the one before, and at no frame do two chimes play. Prints
## PASS/FAIL per check and quits with 0 only if every check passes. Audio
## does not play headless: the streams must load and the players must exist.

const TOY := preload("res://prototypes/far_sound/far_sound.tscn")
const Layout := preload("res://prototypes/far_sound/layout.gd")
const CHIME := "res://prototypes/far_sound/chime.wav"
const CHORD := "res://prototypes/far_sound/chord.wav"

# Waypoints on the ground (x, z); the player starts at (0, 0) facing north (-z).
# Search 1: the obvious gap to the dead end and back, then the slit and round the block.
const OBVIOUS_ROUTE: Array[Vector2] = [Vector2(0, -5), Vector2(0, -8.3), Vector2(3.3, -8.3), Vector2(3.3, -10.9)]
const BACK_ROUTE: Array[Vector2] = [Vector2(3.3, -8.3), Vector2(0, -8.3), Vector2(0, -5), Vector2(0, 0)]
const NARROW_ROUTE: Array[Vector2] = [Vector2(5.5, 0.5), Vector2(5.5, -3.0), Vector2(7.5, -3.0), Vector2(7.5, -13.5), Vector2(1.5, -16.5), Vector2(0, -16.3)]
# Search 2: from chime 1, round the north of the yard to its west opening, in to chime 2.
const YARD_ROUTE: Array[Vector2] = [Vector2(-8, -13.5), Vector2(-23.5, -1.5), Vector2(-23.5, 6), Vector2(-13.8, 6)]
# Search 3: out of the yard, round its south, along the courtyard's open end, up the east corridor to the gate...
const TO_GATE_ROUTE: Array[Vector2] = [Vector2(-23.5, 6), Vector2(-23.5, 13.5), Vector2(8, 13.5), Vector2(8, 1.0), Vector2(9.6, 0)]
# ...then round the north of the pen, in at its east opening, into the west half (the trigger) to chime 3.
const AROUND_PEN_ROUTE: Array[Vector2] = [Vector2(8, -9.5), Vector2(25.5, -9.5), Vector2(25.5, 0), Vector2(17, 0), Vector2(14.8, 0)]
# The way back: round chime 3's box, out through the opened gate.
const GATE_BACK_ROUTE: Array[Vector2] = [Vector2(14.5, 1.3), Vector2(11.5, 1.0), Vector2(9.5, 0.3), Vector2(8.5, 0)]
const REACHED := 0.1       # m: close enough to steer for the next waypoint
const FRAMES_PER_M := 40   # budget: 3.5 m/s is 17 frames per metre; allow more than double
const PUSH_FRAMES := 45    # frames of walking into the closed gate

var toy: Node3D
var player: CharacterBody3D
var panel: CanvasLayer
var harness: Node
var failures := 0
var most_chimes_at_once := 0   # the most chime players found playing in any one frame
var frames_watched := 0
var tail_after_arrival := 0    # frames the last walk went on after the toy counted an arrival


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

	# 1. The spawn: sounds, words, walls, the three sources.
	var chime_stream: Variant = load(CHIME)
	var chord_stream: Variant = load(CHORD)
	check(chime_stream is AudioStreamWAV, "chime.wav loads as an AudioStreamWAV")
	check(chord_stream is AudioStreamWAV, "chord.wav loads as an AudioStreamWAV")
	check(chime_stream is AudioStreamWAV and chime_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and chime_stream.loop_end > 800000, "the chime's loop points came through the import: forward, frames 0..%d of a %.1f s stream" % [chime_stream.loop_end if chime_stream is AudioStreamWAV else -1, chime_stream.get_length() if chime_stream is AudioStreamWAV else -1.0])
	check(toy.sources.size() == 3 and toy.chimes.size() == 3 and toy.chords.size() == 3, "three sources, each with a chime and a chord player")
	var players_ok := true
	for i in 3:
		players_ok = players_ok and toy.chimes[i] is AudioStreamPlayer3D and toy.chimes[i].stream == chime_stream and toy.chords[i] is AudioStreamPlayer3D and toy.chords[i].stream == chord_stream and toy.chimes[i].get_parent() == toy.sources[i]
	check(players_ok, "every Chime holds chime.wav and every Chord chord.wav, under its source")
	check(toy.chimes[0].playing and not toy.chimes[1].playing and not toy.chimes[2].playing, "chime 1 plays from the start, alone")
	check(not toy.chords[0].playing and not toy.chords[1].playing and not toy.chords[2].playing, "no chord plays")
	check(harness.toy_name == "far_sound", "the harness was started as 'far_sound' (%s)" % harness.toy_name)
	check(panel.say_label.visible and panel.say_label.text == toy.lines.start, "the start line is on screen: '%s'" % panel.say_label.text)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "the player stands on the ground, feet at y = %.3f" % player.position.y)
	var d1: float = toy._flat(player).distance_to(toy._flat(toy.sources[0]))
	var d2: float = toy._flat(toy.sources[0]).distance_to(toy._flat(toy.sources[1]))
	var d3: float = toy._flat(toy.sources[1]).distance_to(toy._flat(toy.sources[2]))
	check(d1 >= 15.0 and d1 <= 20.0, "chime 1 is %.1f m from the spawn (15 to 20)" % d1)
	check(d2 >= 25.0 and d2 <= 35.0, "chime 2 is %.1f m from chime 1 (25 to 35)" % d2)
	check(d3 >= 20.0, "chime 3 is %.1f m from chime 2" % d3)
	check(toy.get_node("Walls").get_child_count() == Layout.WALLS.size(), "%d walls stand (%d in the table)" % [toy.get_node("Walls").get_child_count(), Layout.WALLS.size()])
	check(is_equal_approx(Layout.NARROW_GAP_Z.y - Layout.NARROW_GAP_Z.x, 0.9), "the slit is 0.9 m wide")
	var gate_z: float = toy.gate.position.z
	check(toy.gate is AnimatableBody3D and absf(toy.gate.position.x - Layout.GATE_WALL_X) < 0.5 and gate_z > Layout.GATE_Z.x and gate_z < Layout.GATE_Z.y, "the gate slab stands in the pen's west wall at (%.2f, %.2f), the wall's gap z %.1f..%.1f" % [toy.gate.position.x, gate_z, Layout.GATE_Z.x, Layout.GATE_Z.y])
	var src3: Vector2 = toy._flat(toy.sources[2])
	check(src3.x > Layout.GATE_WALL_X and src3.x - Layout.GATE_WALL_X <= 5.0 and src3.y > Layout.GATE_Z.x and src3.y < Layout.GATE_Z.y, "chime 3 sits %.1f m behind the gate" % (src3.x - Layout.GATE_WALL_X))
	check(toy.gate_trigger is Area3D and toy.gate_trigger.position.x > Layout.GATE_WALL_X, "the gate's trigger is an Area3D on the far side of the gate (x %.1f)" % toy.gate_trigger.position.x)
	var hit := ray_to(toy.sources[0])
	check(hits_wall(hit), "the direct line from the eye at the spawn to chime 1 is blocked: %s" % describe(hit))

	# 2. Search 1: the obvious gap, to the dead end and back; then the slit, round the block.
	var frames := await walk(OBVIOUS_ROUTE, "the obvious way")
	check(harness.summary().contains("left_courtyard"), "milestone left_courtyard")
	check(harness.summary().contains("dead_end"), "milestone dead_end after %d frames" % frames)
	check(harness.summary().contains("gap_used  obvious out"), "action gap_used 'obvious out'")
	check(toy.arrived == 0 and not harness.summary().contains("arrived_1"), "not arrived: the dead end is not the chime")
	frames = await walk(BACK_ROUTE, "back to the spawn")
	check(harness.summary().contains("gap_used  obvious back"), "action gap_used 'obvious back'")
	check(not panel.say_label.visible, "the start line is gone after %.0f s" % toy.START_STAYS)
	check(toy.chimes[0].playing, "chime 1 still loops (%.1f s in)" % toy.chimes[0].get_playback_position())
	var frames_1 := await walk(NARROW_ROUTE, "search 1, the short way")
	check(harness.summary().contains("gap_used  narrow out"), "action gap_used 'narrow out': the capsule fits the 0.9 m slit")
	check(toy.arrived == 1 and harness.summary().contains("arrived_1"), "milestone arrived_1, %.2f m from chime 1 after %d frames" % [toy._flat(player).distance_to(toy._flat(toy.sources[0])), frames_1])
	check(not toy.chimes[0].playing, "chime 1 stopped")
	check(toy.chords[0].playing, "chord 1 is playing")
	check(not toy.chimes[1].playing and not toy.chimes[2].playing, "chimes 2 and 3 are silent while chord 1 plays")
	check(panel.say_label.visible and panel.say_label.text == toy.lines.arrived_1, "the arrived_1 line is on screen: '%s'" % panel.say_label.text)
	var waited := await wait_until(func() -> bool: return toy.chimes[1].playing, 400) + tail_after_arrival
	check(toy.chimes[1].playing and waited >= int(toy.NEXT_AFTER * 60) - 5 and waited <= int(toy.NEXT_AFTER * 60) + 30, "chime 2 started %d frames after arriving (%.0f s)" % [waited, toy.NEXT_AFTER])
	check(not toy.chimes[0].playing and not toy.chimes[2].playing, "chime 2 plays alone")
	check(not panel.say_label.visible, "the arrived_1 line cleared when chime 2 started")
	hit = ray_to(toy.sources[1])
	check(hits_wall(hit), "the direct line from the eye at chime 1 to chime 2 is blocked: %s" % describe(hit))

	# 3. Search 2: round the north of the yard, in at its west opening.
	var frames_2 := await walk(YARD_ROUTE, "search 2, round the yard")
	check(harness.summary().contains("route  north of the yard going west"), "action route 'north of the yard going west'")
	check(harness.summary().contains("gap_used  yard in"), "action gap_used 'yard in'")
	check(toy.arrived == 2 and harness.summary().contains("arrived_2"), "milestone arrived_2, %.2f m from chime 2 after %d frames" % [toy._flat(player).distance_to(toy._flat(toy.sources[1])), frames_2])
	check(not toy.chimes[1].playing and toy.chords[1].playing, "chime 2 stopped, chord 2 is playing")
	check(panel.say_label.visible and panel.say_label.text == toy.lines.arrived_2, "the arrived_2 line is on screen: '%s'" % panel.say_label.text)
	waited = await wait_until(func() -> bool: return toy.chimes[2].playing, 400) + tail_after_arrival
	check(toy.chimes[2].playing and waited >= int(toy.NEXT_AFTER * 60) - 5 and waited <= int(toy.NEXT_AFTER * 60) + 30, "chime 3 started %d frames after arriving" % waited)
	check(not toy.chimes[0].playing and not toy.chimes[1].playing, "chime 3 plays alone")
	check(not panel.say_label.visible, "the arrived_2 line cleared when chime 3 started")
	hit = ray_to(toy.sources[2])
	check(hits_wall(hit), "the direct line from the eye at chime 2 to chime 3 is blocked: %s" % describe(hit))

	# 4. Search 3, first half: to the gate, which holds.
	var frames_3 := await walk(TO_GATE_ROUTE, "search 3, to the gate")
	check(harness.summary().contains("gap_used  yard out"), "action gap_used 'yard out'")
	check(harness.summary().contains("route  south of the yard going east"), "action route 'south of the yard going east'")
	check(harness.summary().contains("route  east corridor going north"), "action route 'east corridor going north'")
	check(harness.summary().contains("gate_found"), "milestone gate_found, standing at (%.2f, %.2f)" % [player.position.x, player.position.z])
	check(not toy.gate_open and is_equal_approx(toy.gate.position.z, gate_z), "the gate is closed from this side")
	check(toy.arrived == 2 and not harness.summary().contains("arrived_3"), "not arrived: chime 3 is %.1f m away through the gate" % toy._flat(player).distance_to(toy._flat(toy.sources[2])))
	hit = ray_to(toy.sources[2])
	check(not hit.is_empty() and str(hit.get("collider").name) == "Gate", "the direct line from the eye to chime 3 is blocked by the gate slab: %s" % describe(hit))
	var furthest := await push(Vector3(1, 0, 0), PUSH_FRAMES)
	check(furthest < Layout.GATE_WALL_X and not toy.gate_open, "pushing into the gate for %d frames gets no further than x = %.2f (the wall line is %.1f)" % [PUSH_FRAMES, furthest, Layout.GATE_WALL_X])

	# 5. Search 3, second half: round the pen, in at the far side, the gate slides, the chime.
	frames_3 += await walk(AROUND_PEN_ROUTE, "search 3, round the pen")
	check(harness.summary().contains("route  north of the pen going east"), "action route 'north of the pen going east'")
	check(harness.summary().contains("gap_used  pen in"), "action gap_used 'pen in'")
	check(toy.gate_open and harness.summary().contains("gate_opened"), "milestone gate_opened: the trigger on the far side fired")
	check(toy.arrived == 3 and toy.done and harness.summary().contains("arrived_3"), "milestone arrived_3, %.2f m from chime 3 after %d frames in all" % [toy._flat(player).distance_to(toy._flat(toy.sources[2])), frames_3])
	check(harness.summary().find("gate_opened") < harness.summary().find("arrived_3"), "gate_opened came before arrived_3")
	check(not toy.chimes[2].playing and toy.chords[2].playing, "chime 3 stopped, chord 3 is playing")
	check(not toy.chimes[0].playing and not toy.chimes[1].playing, "no chime rings any more")
	check(panel.say_label.visible and panel.say_label.text == toy.lines.arrived_3, "the arrived_3 line is on screen: '%s'" % panel.say_label.text)
	await wait_until(func() -> bool: return false, int(toy.GATE_SLIDE_TIME * 60) + 30)
	check(absf(toy.gate.position.z - (gate_z + Layout.GATE_SLIDE.z)) < 0.01 and absf(toy.gate.position.x - (Layout.GATE_WALL_X + 0.35)) < 0.01, "the slab slid %.1f m to z = %.2f, clear of the wall's gap" % [Layout.GATE_SLIDE.length(), toy.gate.position.z])
	check(toy.gate.position.z + 1.6 < Layout.GATE_Z.x or toy.gate.position.z - 1.6 > Layout.GATE_Z.y, "the slab's 3.2 m no longer overlaps the gap z %.1f..%.1f" % [Layout.GATE_Z.x, Layout.GATE_Z.y])
	hit = ray_from(Vector3(9.0, 1.6, 0.0), toy.sources[2])
	check(hit.is_empty() or str(hit.get("collider").name).begins_with("Source"), "the line from the corridor side through the open gate to chime 3 is clear: %s" % describe(hit))
	check(not panel.say_label.visible or panel.say_label.text == toy.lines.arrived_3, "the arrived_3 line stays")

	# 6. The way back through the gate, which stays open.
	frames = await walk(GATE_BACK_ROUTE, "back out through the gate")
	check(player.position.x < Layout.GATE_WALL_X, "walked out through the gate to x = %.2f in %d frames" % [player.position.x, frames])
	check(harness.summary().contains("gap_used  gate out"), "action gap_used 'gate out'")
	check(toy.gate_open and toy.gate.position.z + 1.6 < Layout.GATE_Z.x, "the gate stays open")
	check(toy.done and toy.arrived == 3 and not toy.chimes[0].playing and not toy.chimes[1].playing and not toy.chimes[2].playing, "the toy is done: nothing rings")

	# 7. The whole: one chime at a time, each search longer than the last, the counts.
	check(most_chimes_at_once == 1, "at most one chime played in any of the %d frames watched (most at once: %d)" % [frames_watched, most_chimes_at_once])
	check(frames_1 < frames_2 and frames_2 < frames_3, "each scripted search took longer than the last: %d, %d, %d frames" % [frames_1, frames_2, frames_3])
	check(harness.summary().contains("  gap_used: 7"), "the harness counted 7 gap_used actions (obvious out/back, narrow out, yard in/out, pen in, gate out)")
	check(harness.summary().contains("  route: 4"), "the harness counted 4 route actions")
	check(harness.summary().contains("milestones: 7"), "7 milestones: left_courtyard, dead_end, arrived_1, arrived_2, gate_found, gate_opened, arrived_3")

	print("--- summary() ---\n%s\n--- end ---" % harness.summary())
	print("RESULT: %d failure(s)" % failures)
	# Quitting while a sound plays leaves its playback in the audio server
	# (reported as leaked at exit): stop every player and give the mix thread a moment.
	for p in toy.chimes + toy.chords:
		p.stop()
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
	var arrived_before: int = toy.arrived
	var arrival_at := -1   # the frame the toy counted an arrival, if it did
	while next < route.size() and frames < budget:
		var to := Vector3(route[next].x, 0.0, route[next].y) - player.position
		to.y = 0.0
		if to.length() < REACHED:
			next += 1
			continue
		player.auto_move = to.normalized()
		await get_tree().physics_frame
		frames += 1
		watch_chimes()
		if arrival_at < 0 and toy.arrived > arrived_before:
			arrival_at = frames
		if frames % 120 == 0:
			print("  frame %4d: at (%.2f, %.2f)" % [frames, player.position.x, player.position.z])
	player.auto_move = Vector3.ZERO
	await get_tree().physics_frame   # the toy reads the player's position a frame behind
	await get_tree().physics_frame
	watch_chimes()
	if arrival_at < 0 and toy.arrived > arrived_before:
		arrival_at = frames + 2
	tail_after_arrival = (frames + 2 - arrival_at) if arrival_at >= 0 else 0
	print("%s: %d of %d waypoints in %d frames (budget %d), ended at (%.2f, %.2f)" % [what, next, route.size(), frames, budget, player.position.x, player.position.z])
	check(next == route.size(), "%s: every waypoint reached" % what)
	return frames


## Walk in one direction for some frames; returns the furthest x reached.
func push(dir: Vector3, frames: int) -> float:
	var furthest: float = player.position.x
	player.auto_move = dir
	for i in frames:
		await get_tree().physics_frame
		furthest = maxf(furthest, player.position.x)
		watch_chimes()
	player.auto_move = Vector3.ZERO
	await get_tree().physics_frame
	print("pushed %s for %d frames: furthest x = %.2f, ended at (%.2f, %.2f)" % [dir, frames, furthest, player.position.x, player.position.z])
	return furthest


## Stand still until the condition holds or the frames run out; returns the frames waited.
func wait_until(cond: Callable, most: int) -> int:
	var n := 0
	player.auto_move = Vector3.ZERO
	while n < most and not cond.call():
		await get_tree().physics_frame
		n += 1
		watch_chimes()
	return n


## Note how many chime players are playing this frame.
func watch_chimes() -> void:
	var n := 0
	for c in toy.chimes:
		if c.playing:
			n += 1
	most_chimes_at_once = maxi(most_chimes_at_once, n)
	frames_watched += 1


## The ray from the player's eye to a source's box, through the physics world.
func ray_to(source: Node3D) -> Dictionary:
	return ray_from(player.global_position + Vector3(0, 1.6, 0), source)


func ray_from(from: Vector3, source: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, source.global_position)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


static func hits_wall(hit: Dictionary) -> bool:
	return not hit.is_empty() and str(hit.get("collider").name).begins_with("Wall")


static func describe(hit: Dictionary) -> String:
	if hit.is_empty():
		return "nothing hit"
	var p: Vector3 = hit.position
	return "hit '%s' at (%.1f, %.1f, %.1f)" % [hit.collider.name, p.x, p.y, p.z]
