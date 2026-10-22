extends Node2D
## The balance of toy 4, PINCH (day 5), measured, not guessed, headless.
## The driver (tests/pinch_driver.gd) plays dream.tscn alone, with a fresh
## state each night. Sections: (A) room f, the sixth room, played
## competently inside 20 s: the draft up through the soft room, the pinch
## over the shelf, the idea, the quiet spot, the draft again and the pinch
## over the perch; the perch 112 px above the shelf (one step too high);
## its words from rooms.json; (B) the feel, drawn only: the body squashes
## 1.2 x 0.8 for 6 frames after a pinched landing and is back after,
## stretches at a jump, the hat stack bounces when an idea joins it, the
## blink's three phases (shut in 4 frames, held until one second, reopened
## over 12 with the dreamer back at the door dropping in 8 px), the soft
## shapes dim within two steps of the limit, H's choice is remembered in
## the state; (C) a COMPETENT night and a CLUMSY night on nights 1, 2 and
## 3 with the limit 8 and carry 2, one row each: the acts, lucidity and
## effective at the end, how the night ended, the ideas brought home, the
## seconds; then one notch either way, measured too (clumsy at 9,
## competent at 7). Only the invariants are asserted: a competent night
## reaches the bed with 2 ideas on at least 2 of the 3 nights; a clumsy
## night wakes suddenly at least once; no night was stuck. SPEC-2 (day A):
## the branch dealer replaced the deck, so (A) and (B) deal their rooms by
## hand (no scraps) with the idea placed where the dealer laid it, and the
## nights of (C) are the three branches (night 1 Jorun's, 2 Bo's, 3
## Tove's: the hub, two rooms, the goal room, six scraps); the invariants
## read "reached" (the idea, with every scrap) where they read "bed". The
## table has a scraps column. Prints the table, PASS/FAIL per check, and
## quits with 0 only if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const DRIVER := preload("res://tests/pinch_driver.gd")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const SOLVE_FRAMES := 1200   # 20 s at 60 Hz: room f must be solved inside this

var failures := 0
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var driver: Node
var rows: Array[Dictionary] = []


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var rooms_json: Dictionary = PinchState.load_json(ROOMS_FILE)
	driver = DRIVER.new()
	driver.name = "Driver"
	add_child(driver)

	# ---------------------------------------------------------------- (A) room f
	await fresh(1)
	dream.redeal(["f", "bed"] as Array[String], false)   # SPEC-2: by hand, no scraps; the idea placed by hand below
	var f_words: Dictionary = dream.room_words("f")
	check(dream.current_room_id() == "f" and dream.room.id == "f" and f_words.get("name", "") != "" and f_words.get("hint", "") != "", "room f is dealt: '%s'" % f_words.get("name", ""))
	check(dream.room_label.text == str(rooms_json.label).format({"name": f_words.name, "hint": f_words.hint}), "its label reads from rooms.json")
	var shelf: StaticBody2D = dream.room.get_node("Crisp/Shelf")
	var perch: StaticBody2D = dream.room.get_node("Crisp/Perch")
	var draft: Area2D = dream.room.get_node("Currents/Draft")
	var spot: Area2D = dream.room.get_node("Wonders/Quiet")
	var chamber: StaticBody2D = dream.room.get_node("Soft/ChamberLeft")
	check(is_equal_approx(shelf.position.y - perch.position.y, 112.0) and perch.position.x >= shelf.position.x + shelf.size.x, "the perch is 112 px above the shelf (one step too high for a jump) and past its end")
	check(shelf.label.text == str(rooms_json.words.shelf) and perch.label.text == str(rooms_json.words.perch) and draft.label.text == str(rooms_json.words.draft), "the shelf, the perch and the draft are labelled from rooms.json: '%s', '%s', '%s'" % [shelf.label.text, perch.label.text, draft.label.text])
	check(draft.is_in_group("current") and draft.velocity.y < 0.0 and draft.velocity.x > 0.0 and chamber.soft and chamber.is_in_group("soft") and spot.kind == "spot" and spot.id == "f_spot", "a rising draft, a soft chamber, a quiet spot")
	var f_idea: String = dream.ideas_pool()[0]
	dream.place_idea(f_idea, dream.room.idea_spots()[0])
	check(dream.ideas_in_room() == [f_idea] and dream.ideas_node.get_child(0).position.y < shelf.position.y, "its idea %s lies on the shelf (placed by hand on the room's spot)" % f_idea)
	driver.attach(dream, "competent")
	var started: int = Engine.get_physics_frames()
	await driver.play_room("f")
	var f_frames: int = Engine.get_physics_frames() - started
	check(dream.current_room_id() == "bed" and dream.room_index == 1, "the driver left room f by the perch's exit: the bed room is in play (%s)" % [driver.did])
	check(f_frames < SOLVE_FRAMES, "room f solved competently in %d frames (%.1f s)" % [f_frames, f_frames / 60.0])
	check(dream.carried == [f_idea] and driver.acts.get("wonder", 0) == 1 and dream.lucidity == 1 and dream.effective() == 2, "took %s (+2), the quiet spot (-1): lucidity 1, effective 2 (%d, %d)" % [f_idea, dream.lucidity, dream.effective()])
	check(dream.hard_falls == 0 and dream.blinks == 0 and driver.acts.get("fall", 0) == 0 and driver.acts.get("fail", 0) == 0, "no hard fall, no failed screen on the way")
	# A jump from the shelf alone does not reach the perch; the draft does.
	dream.redeal(["f", "bed"] as Array[String], false)
	perch = dream.room.get_node("Crisp/Perch")   # the room was dealt afresh
	dreamer.respawn(Vector2(760, 272))   # standing on the shelf
	Input.action_press("pinch")
	await settle()
	var top_y: float = dreamer.position.y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 60:
		await get_tree().physics_frame
		top_y = minf(top_y, dreamer.position.y)
		if i > 5 and dreamer.is_on_floor():
			break
	check(top_y > perch.position.y - 28.0 + 8.0 and is_equal_approx(dreamer.position.y, 272.0), "a jump from the shelf peaks at y = %.1f: the perch (standing y %.0f) is out of reach by %.0f px" % [top_y, perch.position.y - 28.0, top_y - (perch.position.y - 28.0)])
	Input.action_release("pinch")

	# ---------------------------------------------------------------- (B) the feel
	# The dream thins within two steps of the limit.
	await fresh(1)
	dream.redeal(["tutorial", "bed"] as Array[String], false)   # SPEC-2: the tutorial by hand (the night opens on the hub)
	var pillar: StaticBody2D = dream.room.get_node("Soft/Pillar")
	check(pillar.modulate == Color.WHITE and not dream.thin() and dream.effective() == 0, "effective 0: the soft pillar is drawn plain")
	for i in 5:
		dream.fall()
	check(dream.effective() == 5 and not dream.thin() and pillar.modulate == Color.WHITE, "effective 5 of 8: still plain")
	dream.fall()
	check(dream.effective() == 6 and dream.thin() and pillar.modulate == dream.THIN, "effective 6, two steps from shut: the soft pillar dims to %s" % [pillar.modulate])
	check(dream.wonder("thin_test", "spot") and dream.effective() == 5 and pillar.modulate == Color.WHITE, "a wonder: plain again")
	# The squash, the stretch, the hat.
	await fresh(1)
	dream.redeal(["tutorial", "bed"] as Array[String], false)
	dream.place_idea(dream.ideas_pool()[0], Vector2(60, 588))   # the tutorial's idea, by hand, in reach of the door
	check(dreamer.body_scale() == Vector2.ONE and not dreamer.is_on_floor(), "at the door, hovering: the body is drawn 1 x 1")
	Input.action_press("pinch")
	var frames := await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	check(frames < 60 and dreamer.body_scale() == dreamer.SQUASH, "the pinched landing squashed the body to %s on the frame it landed" % [dreamer.body_scale()])
	var squashed := 1
	while dreamer.body_scale() == dreamer.SQUASH and squashed < 20:
		await get_tree().physics_frame
		if dreamer.body_scale() == dreamer.SQUASH:
			squashed += 1
	check(squashed == dreamer.SQUASH_FRAMES and dreamer.body_scale() == Vector2.ONE, "squashed for %d frames, then back to 1 x 1" % squashed)
	check(is_equal_approx(dreamer.body.pivot_offset.y, dreamer.BODY_SIZE.y), "the body scales about its feet (pivot at y %.0f)" % dreamer.body.pivot_offset.y)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	check(dreamer.body_scale() == dreamer.STRETCH and not dreamer.is_on_floor(), "the jump stretched it to %s" % [dreamer.body_scale()])
	for i in 6:
		await get_tree().physics_frame
	check(dreamer.body_scale() == Vector2.ONE and not dreamer.is_on_floor(), "6 frames on, in the air: 1 x 1 again")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	check(frames < 60 and dreamer.body_scale() == dreamer.SQUASH and dream.lucidity == 0, "landed from the jump: the squash again, free")
	# The hat's settle bounce.
	await settle()
	check(is_zero_approx(dreamer.hat_bounce()) and is_equal_approx(dreamer.hat.position.y, dreamer.body.position.y), "the empty hat sits on the head")
	check(dream.idea_in_reach() != null and dream.grab(), "took the tutorial's idea")
	check(dreamer.hat_bounce() > 0.0 and dreamer.hat.position.y > dreamer.body.position.y, "the stack dipped %.1f px the moment the idea joined it" % dreamer.hat_bounce())
	var deepest := 0.0
	for i in dreamer.HAT_BOUNCE_FRAMES + 1:
		deepest = maxf(deepest, dreamer.hat_bounce())
		await get_tree().physics_frame
	check(deepest > dreamer.HAT_BOUNCE * 0.9 and is_zero_approx(dreamer.hat_bounce()) and is_equal_approx(dreamer.hat.position.y, dreamer.body.position.y), "it dipped %.1f px at most and settled %d frames on" % [deepest, dreamer.HAT_BOUNCE_FRAMES + 1])
	# The blink's three phases.
	var door: Vector2 = dream.room.door.position
	var shown_before: float = dream.shown_aperture()
	var lucidity_before: int = dream.lucidity
	dream.fail("test")
	check(dream.blinking and dream.blink_phase() == "shutting" and is_equal_approx(dream.shown_aperture(), shown_before) and not dreamer.visible and dreamer.frozen, "a failed screen: the blink begins shutting from what was shown, %.3f; the dreamer gone" % shown_before)
	var shuts: Array[float] = []
	for i in dream.BLINK_SHUT_FRAMES:
		await get_tree().physics_frame
		shuts.append(dream.shown_aperture())
	check(shuts.size() == 4 and shuts[0] < shown_before and shuts[1] < shuts[0] and shuts[2] < shuts[1] and is_zero_approx(shuts[3]) and dream.blink_phase() == "shut", "shut in 4 frames: %s, then held" % [shuts])
	check(dream.frame_open.size == Vector2.ZERO and not dreamer.visible, "the frame shows nothing, the dreamer is still gone")
	var held := 0
	while dream.blink_phase() == "shut" and held < 100:
		await get_tree().physics_frame
		held += 1
	check(held + dream.BLINK_SHUT_FRAMES == 60 and dream.blink_phase() == "reopening" and not dream.blinking, "held %d frames: one second after the fail the frame reopens (%s)" % [held, dream.blink_phase()])
	check(dreamer.visible and not dreamer.frozen and dreamer.position == door and dreamer.drop_in() > 0.0, "the dreamer is back at the door, drawn %.1f px up, dropping in" % dreamer.drop_in())
	var opens: Array[float] = []
	for i in dream.BLINK_OPEN_FRAMES:
		await get_tree().physics_frame
		opens.append(dream.shown_aperture())
	check(opens.size() == 12 and opens[0] > 0.0 and opens[5] > opens[0] and opens[11] > opens[5] and is_equal_approx(opens[11], dream.aperture()) and dream.blink_phase() == "", "reopened over 12 frames to the aperture %.3f: %.3f, %.3f ... %.3f" % [dream.aperture(), opens[0], opens[5], opens[11]])
	check(is_zero_approx(dreamer.drop_in()) and dream.lucidity == lucidity_before + 1, "the drop-in is done; the failed screen cost +1 (lucidity %d)" % dream.lucidity)
	Input.action_release("pinch")
	# H is remembered in the state.
	check(state.gauge_visible and dream.gauge_visible and dream.gauge.visible, "the gauge is on; the state says so")
	await press_key(KEY_H)
	check(not state.gauge_visible and not dream.gauge.visible, "H: off, and the state remembers")
	var kept_state := state
	remove_child(dream)
	dream.queue_free()
	await get_tree().physics_frame
	dream = DREAM.instantiate()
	dream.state = kept_state
	add_child(dream)
	await get_tree().physics_frame
	check(not dream.gauge_visible and not dream.gauge.visible, "the next night starts with the gauge off")
	dream.toggle_gauge()
	check(kept_state.gauge_visible and dream.gauge.visible, "H again: on, and remembered")

	# ---------------------------------------------------------------- (C) the nights: the three branches
	for night in [1, 2, 3]:
		for play_mode in ["competent", "clumsy"]:
			rows.append(await play_night(night, play_mode, 8))
	for night in [1, 2, 3]:
		rows.append(await play_night(night, "clumsy", 9))
	for night in [1, 2, 3]:
		rows.append(await play_night(night, "competent", 7))
	print_table()
	var competent_home := 0
	var clumsy_woke := 0
	var stuck := 0
	for row in rows:
		if row.end == "stuck":
			stuck += 1
		if row.limit != 8:
			continue
		if row.mode == "competent" and row.end == "reached" and row.kept >= 2:
			competent_home += 1
		if row.mode == "clumsy" and row.end == "woke":
			clumsy_woke += 1
	check(stuck == 0, "no night was stuck (%d)" % stuck)
	check(competent_home >= 2, "a competent night reached the idea with at least one scrap on %d of the 3 branches" % competent_home)
	check(clumsy_woke >= 1, "a clumsy night woke suddenly %d time(s) of 3" % clumsy_woke)

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


const TARGETS: Array[String] = ["jorun", "bo", "tove"]   # night 1, 2, 3: one branch each


## One night of dream.tscn alone on `day` (the target TARGETS[day - 1],
## every villager talked to), the given limit and carry 2, played in
## `play_mode`; the row for the table.
func play_night(day: int, play_mode: String, limit: int) -> Dictionary:
	await fresh(day, TARGETS[(day - 1) % TARGETS.size()])
	state.lucidity_limit = limit
	state.carry_limit = 2
	driver.attach(dream, play_mode)
	var row: Dictionary = await driver.play_night()
	row["night"] = day
	row["mode"] = play_mode
	row["limit"] = limit
	row["did"] = driver.did.duplicate()
	check(row.end != "stuck", "night %d %s (limit %d): %s in %s, lucidity %d, effective %d, %d thing(s) home, %.1f s; %s" % [day, play_mode, limit, row.end, row.rooms, row.lucidity, row.effective, row.kept, row.seconds, row.did])
	return row


## The table: one row per night played.
func print_table() -> void:
	print("--- balance (dream.tscn alone, a fresh state each night, one branch per night, carry 2, scraps 3) ---")
	print("%-5s %-9s %-5s %-24s %-5s %-6s %-4s %-6s %-5s %-5s %-7s %-9s %-5s %-8s" % ["night", "mode", "limit", "rooms", "grab", "scraps", "set", "force", "fall", "fail", "wonder", "lucidity", "eff", "end"] + " home  seconds")
	for row in rows:
		var a: Dictionary = row.acts
		print("%-5d %-9s %-5d %-24s %-5d %-6d %-4d %-6d %-5d %-5d %-7d %-9d %-5d %-8s %-5d %.1f" % [row.night, row.mode, row.limit, ",".join(row.rooms), a.get("grab", 0), a.get("grab_scrap", 0), a.get("set_down", 0) + a.get("set_down_scrap", 0), a.get("force", 0), a.get("fall", 0), a.get("fail", 0), a.get("wonder", 0), row.lucidity, row.effective, row.end, row.kept, row.seconds])
	print("--- end ---")


## A new dream on `day` with a fresh state (SPEC-2: with `target` as
## tonight's dream and every villager talked to); the old one gone.
func fresh(day: int, target := "") -> void:
	if dream != null:
		remove_child(dream)
		dream.queue_free()
		await get_tree().physics_frame
	for action in ["pinch", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	state = PinchState.new()
	state.day = day
	state.target = target
	for who in TARGETS:
		state.set_flag("talked:%s" % who)
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	dreamer = dream.dreamer
	await get_tree().physics_frame


func settle() -> void:
	for i in 20:
		await get_tree().physics_frame


## Frames until the condition holds, or the budget runs out.
func wait_until(cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		await get_tree().physics_frame
		frames += 1
	return frames


## Press and release a key through the input system, as a player would.
func press_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
