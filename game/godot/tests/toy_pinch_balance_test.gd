extends Node2D
## The balance of toy 4b, PINCH (day 5; SPEC-2 day C), measured, not
## guessed, headless. The driver (tests/pinch_driver.gd) plays dream.tscn
## alone. Sections: (A) room f, the sixth room, played competently inside
## 20 s: the quiet spot by the door (day C: moved out of the draft, so its
## wonder can be had, and is), the draft up through the soft room, the
## pinch over the shelf, the thoughts hung there, the draft again and the
## pinch over the perch; the perch 112 px above the shelf (one step too
## high); its words from rooms.json; (B) the feel, drawn only: the body
## squashes 1.2 x 0.8 for 6 frames after a pinched landing and is back
## after, stretches at a jump, a thought taken sits at the hip, the
## blink's three phases (shut in 4 frames, held until one second,
## reopened over 12 with the dreamer back at the door dropping in 8 px),
## the soft shapes dim within two steps of the limit, H's choice is
## remembered in the state; (C) THE NIGHTS: the competent and the clumsy
## driver on the three branches (night 1 Jorun's, 2 Bo's, 3 Tove's: the
## hub, two rooms, the goal room, six scraps), limit 8, carry 3, with the
## scraps actually taken on the way, one row each: the scraps home (their
## shapes), the wonders, lucidity and effective at the end, how the night
## ended (reached, self-pinch, woke), the seconds; then the clumsy driver
## at 10 (the pill's night), measured too; (D) THE DESK'S ARITHMETIC, with
## carry 3 and six scraps a night: by the pure sums, how many mornings an
## outline of 3, 4 or 5 slots takes when every card matches (one card per
## slot, three a morning); and MEASURED, each branch played competently
## with ONE state carried across its mornings (the thoughts home fitted
## where their shapes match, the leftovers kept up to six, the deal of
## the next night favouring the outline's missing shapes, day C) until
## the outline is complete or three mornings have passed. Only the
## invariants are asserted: a competent night reaches the idea on 3 of 3
## branches; a clumsy night wakes suddenly or pinches itself awake on at
## least 1; no night was stuck; every outline completes within 3 competent
## mornings. Prints the tables, PASS/FAIL per check, and quits with 0 only
## if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const DRIVER := preload("res://tests/pinch_driver.gd")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const BRANCHES_FILE := "res://prototypes/pinch/data/branches.json"
const SOLVE_FRAMES := 1200   # 20 s at 60 Hz: room f must be solved inside this
const MORNINGS := 3          # an outline must complete within this many competent mornings
const TARGETS: Array[String] = ["jorun", "bo", "tove"]   # night 1, 2, 3: one branch each

var failures := 0
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var driver: Node
var branches: Array = []
var rows: Array[Dictionary] = []        # the nights
var mornings: Array[Dictionary] = []    # the Desk's arithmetic, measured
var reached_idea := ""                  # what the dream reported reached this night


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var rooms_json: Dictionary = PinchState.load_json(ROOMS_FILE)
	branches = (PinchState.load_json(BRANCHES_FILE) as Dictionary).get("branches", [])
	driver = DRIVER.new()
	driver.name = "Driver"
	add_child(driver)

	# ---------------------------------------------------------------- (A) room f
	await fresh(1)
	dream.redeal(["f", "bed"] as Array[String])   # SPEC-2: by hand, with its scraps (all six land in f: the bed holds none)
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
	check(dream.scraps_in_room().size() == 6 and dream.ideas_in_room().is_empty() and dream.scraps_node.get_child(0).position.y < shelf.position.y, "six thoughts hang in it, two over the shelf; no idea (day B)")
	var spot_rect := Rect2(spot.position, spot.size)   # read now: the room goes when the driver leaves it
	var draft_rect := Rect2(draft.position, draft.size)
	var door_at: Vector2 = dream.room.door.position
	check(not draft_rect.intersects(spot_rect) and spot_rect.has_point(door_at) and spot_rect.intersects(dreamer.rect()), "the quiet spot (%s) sits outside the draft (%s), by the door, around the body hovering there (day C)" % [spot_rect, draft_rect])
	driver.attach(dream, "competent")
	var started: int = Engine.get_physics_frames()
	await driver.play_room("f")
	var f_frames: int = Engine.get_physics_frames() - started
	check(dream.current_room_id() == "bed" and dream.room_index == 1, "the driver left room f by the perch's exit: the bed room is in play (%s)" % [driver.did])
	check(f_frames < SOLVE_FRAMES, "room f solved competently in %d frames (%.1f s)" % [f_frames, f_frames / 60.0])
	var taken: int = dream.scraps_carried.size()
	check(driver.acts.get("wonder", 0) == 1 and driver.did.size() > 0 and driver.did[0] == "enter f", "the quiet spot's wonder was had, by the door, before anything else (day C: Bo's branch yields three wonders again)")
	check(taken >= 1 and taken <= 3 and driver.acts.get("grab_scrap", 0) == taken and dream.lucidity == taken and dream.effective() == 2 * taken, "took %d thought(s) (+1 each) after the wonder (which found lucidity at 0, its floor): lucidity %d, effective %d" % [taken, dream.lucidity, dream.effective()])
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
	# The squash, the stretch, the hip.
	await fresh(1)
	dream.redeal(["tutorial", "bed"] as Array[String], false)
	dream.place_scrap("round", Vector2(60, 556))   # a thought by hand at hand height, in reach of the door
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
	# The hip (day B: no hat, no bounce).
	await settle()
	check(dreamer.hip_count() == 0 and not dreamer.has_node("Hat"), "the hip is empty; there is no hat")
	check(dream.scrap_in_reach() != null and dream.grab_scrap(), "took the thought")
	check(dreamer.hip_count() == 1 and dreamer.hip.get_child(0).size == dreamer.HIP_PIECE, "one piece at the hip the moment it is taken")
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
			await fresh(night, TARGETS[night - 1])
			rows.append(await play_night(night, play_mode, 8))
	for night in [1, 2, 3]:
		await fresh(night, TARGETS[night - 1])
		rows.append(await play_night(night, "clumsy", 10))

	# ---------------------------------------------------------------- (D) the Desk's arithmetic
	# By the pure sums: every card matching, three a morning.
	var sums: Array[String] = []
	for branch in branches:
		var slots: int = branch.get("slots", []).size()
		sums.append("%s %d slots: %d morning(s)" % [branch.get("who", ""), slots, ceili(float(slots) / float(PinchState.CARRY_SCRAPS))])
	check(sums == ["tove 5 slots: 2 morning(s)", "jorun 4 slots: 2 morning(s)", "bo 3 slots: 1 morning(s)"], "with every shape matching and carry 3: %s" % [sums])
	# Measured: each branch, one state carried across its mornings.
	var completed := {}
	for branch in branches:
		var who := str(branch.get("who", ""))
		var idea := str(branch.get("idea", ""))
		var slots: Array = branch.get("slots", [])
		await fresh(1, who)
		var carried_state := state
		var night := 0
		while night < MORNINGS:
			night += 1
			if night > 1:
				await fresh(night, who, carried_state)
			var row: Dictionary = await play_night(night, "competent", 8, "mornings")
			rows.append(row)
			var result := desk_morning(idea, slots)
			result["night"] = night
			result["who"] = who
			result["home"] = row.home
			mornings.append(result)
			check(row.end != "stuck", "%s, morning %d: %s home, %d fitted: %s %d / %d, %s left%s" % [who, night + 1, row.home, result.fitted, idea, result.filled, result.total, result.leftovers, "; COMPLETE" if result.complete else ""])
			if result.complete:
				completed[who] = night
				break
	print_tables()
	var competent_reached := 0
	var clumsy_out := 0
	var stuck := 0
	for row in rows:
		if row.end == "stuck":
			stuck += 1
		if row.limit != 8 or row.section != "nights":
			continue
		if row.mode == "competent" and row.end == "reached":
			competent_reached += 1
		if row.mode == "clumsy" and (row.end == "woke" or row.end == "self"):
			clumsy_out += 1
	check(stuck == 0, "no night was stuck (%d)" % stuck)
	check(competent_reached == 3, "a competent night reached the idea on %d of the 3 branches" % competent_reached)
	check(clumsy_out >= 1, "a clumsy night woke suddenly or pinched itself awake %d time(s) of 3" % clumsy_out)
	var within := true
	for branch in branches:
		within = within and completed.has(str(branch.get("who", "")))
	check(within and completed.size() == 3, "every outline completes within %d competent mornings: %s" % [MORNINGS, completed])

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## One night of dream.tscn alone on `day` with the dream already dealt
## (fresh), the given limit, played in `play_mode`; the scraps brought
## home go into the state as the controller would put them (every one on
## a gentle waking, one on a sudden one), and the idea reached is marked;
## the row for the table (`section`: "nights" for (C), "mornings" for (D)).
func play_night(day: int, play_mode: String, limit: int, section := "nights") -> Dictionary:
	state.lucidity_limit = limit
	var target: String = state.target
	reached_idea = ""
	dream.reached.connect(func(who: String, idea: String) -> void: reached_idea = idea; state.reach(who, idea))
	driver.attach(dream, play_mode)
	var row: Dictionary = await driver.play_night()
	var carried: Array = driver.woke[1] if driver.woke.size() > 1 else []
	var home: Array[String] = []
	if row.end == "woke":
		if not carried.is_empty():
			home.append(str(carried[0]))   # the picker: the first
	else:
		for shape in carried:
			home.append(str(shape))
	for shape in home:
		state.keep_scrap(shape)
	row["night"] = day
	row["mode"] = play_mode
	row["limit"] = limit
	row["branch"] = target
	row["home"] = home
	row["section"] = section
	row["did"] = driver.did.duplicate()
	check(row.end != "stuck", "night %d %s (%s, limit %d): %s in %s, home %s, lucidity %d, effective %d, %.1f s; %s" % [day, play_mode, target, limit, row.end, row.rooms, home, row.lucidity, row.effective, row.seconds, row.did])
	return row


## The morning's Desk by arithmetic (the village's rule, without the
## clock): every card home into the first empty slot of its shape, the
## leftovers kept (up to the state's cap), the thing developed when the
## last slot fills. Returns {fitted, filled, total, leftovers, complete}.
func desk_morning(idea: String, slots: Array) -> Dictionary:
	var filled: Array[String] = state.outline_filled(idea, slots.size())
	var leftovers: Array[String] = []
	var fitted := 0
	for shape in state.scraps:
		var at := -1
		for i in slots.size():
			if filled[i] == "" and (str(slots[i]) == "any" or str(slots[i]) == shape):
				at = i
				break
		if at >= 0:
			state.fill_slot(idea, at, shape)
			fitted += 1
		else:
			leftovers.append(shape)
	state.scraps.assign(leftovers.slice(0, PinchState.KEEP_SCRAPS))
	var complete := state.outline_count(idea) == slots.size()
	if complete:
		state.develop(idea)
	return {"fitted": fitted, "filled": state.outline_count(idea) if not complete else slots.size(), "total": slots.size(), "leftovers": state.scraps.duplicate(), "complete": complete}


## The tables: the nights, then the Desk's mornings.
func print_tables() -> void:
	print("--- balance (dream.tscn alone, limit 8 unless said, carry 3, six thoughts a night) ---")
	print("%-5s %-6s %-9s %-5s %-24s %-18s %-4s %-5s %-5s %-7s %-9s %-5s %-8s %s" % ["night", "branch", "mode", "limit", "rooms", "home", "set", "fall", "fail", "wonder", "lucidity", "eff", "end", "seconds"])
	for row in rows:
		var a: Dictionary = row.acts
		print("%-5d %-6s %-9s %-5d %-24s %-18s %-4d %-5d %-5d %-7d %-9d %-5d %-8s %.1f" % [row.night, row.branch, row.mode, row.limit, ",".join(row.rooms), ",".join(row.home), a.get("set_down_scrap", 0), a.get("fall", 0), a.get("fail", 0), a.get("wonder", 0), row.lucidity, row.effective, row.end, row.seconds])
	print("--- the Desk's arithmetic (one state per branch, competent, the deal favouring what is missing from the second night on) ---")
	print("%-6s %-7s %-18s %-6s %-9s %-12s %s" % ["branch", "morning", "home", "fitted", "outline", "left over", "complete"])
	for m in mornings:
		print("%-6s %-7d %-18s %-6d %-9s %-12s %s" % [m.who, int(m.night) + 1, ",".join(m.home), m.fitted, "%d / %d" % [m.filled, m.total], ",".join(m.leftovers), "yes" if m.complete else "no"])
	print("--- end ---")


## A new dream on `day` with a fresh state (SPEC-2: with `target` as
## tonight's dream and every villager talked to), or on `carried` (the
## state of the mornings before, its day moved on); the old dream gone.
func fresh(day: int, target := "", carried: PinchState = null) -> void:
	if dream != null:
		remove_child(dream)
		dream.queue_free()
		await get_tree().physics_frame
	for action in ["pinch", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	if carried != null:
		state = carried
		state.day = day
		state.scraps_carried.clear()
	else:
		state = PinchState.new()
		state.day = day
		for who in TARGETS:
			state.set_flag("talked:%s" % who)
	state.target = target
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
