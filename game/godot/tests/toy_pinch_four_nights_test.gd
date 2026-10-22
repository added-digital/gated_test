extends Node2D
## Four full nights of toy 4b, PINCH (prototypes/pinch/pinch.tscn),
## headless, the whole second loop (SPEC-2, day C), WITHOUT A THOUGHT
## PLACED BY HAND: the driver (tests/pinch_driver.gd) plays the dream,
## this script plays the day, and every card on the Desk came up from a
## night. Day 1 talks to Jorun, Bo and Tove (their branches on the wall)
## and chooses Bo's dream at the wall (the chosen row brightens, the
## others dim; a question mark's box pulses). Night 1 competent down Bo's
## branch: the pills reached with three thoughts; morning 2: the Desk
## fills 3 of 3: the pill in full (pill_bonus 2, the limit 10 from now
## on), the outline flashing under the thing's name, then the desk goes.
## Night 2 Jorun's, with H pressed once (the gauge off for this night and
## the next, remembered in the state): Sixteen Stairs reached with three;
## morning 3: the Desk fills 3 of 4 and the walker walks away: the
## outline WAITS (nothing is lost; the wall says 3 / 4). Night 3 Tove's:
## the lantern reached with three (round, square, square: the plain
## deal); morning 4: the Desk shows Jorun's outline first (the oldest),
## its last slot takes the round: the building in full, a scaffold whose
## crossbars appear one a second; the two squares are kept. Night 4 Tove's
## again: her branch was reached, so the deal favours the lantern's
## missing shapes and her room holds two thoughts and no idea; the driver
## takes what it can and pinches itself awake. Morning 5: Sixteen Stairs
## stands (its lit window fading in, 4 tiles lit, Jorun in front of it)
## and the Desk lays the lantern's outline with the five cards home: four
## of five fit, the outline waits. At the end: slept_1..4, Sixteen Stairs
## standing, pill_bonus 2, the lantern's outline started (4 / 5 on the
## wall), the milestones listed (reached:<who> for all three,
## desk_full:pills, desk_full:sixteen_stairs, built:sixteen_stairs,
## self_pinch), the log on disk. Prints the four nights' table and the
## harness summary, PASS/FAIL per check, and quits with 0 only if every
## check passes.

const TOY := preload("res://prototypes/pinch/pinch.tscn")
const DRIVER := preload("res://tests/pinch_driver.gd")
const WALK_FRAMES := 900   # 15 s at 60 Hz: the longest walk on the street is under 1000 px

var failures := 0
var toy: Node
var panel: CanvasLayer
var harness: Node
var state: PinchState
var driver: Node
var rows: Array[Dictionary] = []
var village_acts: Array = []
var windows_at_start := {}   # plot -> the lit window's alpha the instant the village appeared
var hand_placed := 0         # thoughts placed by hand: none, ever


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	toy = TOY.instantiate()
	toy.child_entered_tree.connect(_watch_village)
	add_child(toy)
	panel = toy.panel
	harness = toy.harness
	state = toy.get_state()
	driver = DRIVER.new()
	driver.name = "Driver"
	add_child(driver)
	for i in 10:
		await get_tree().physics_frame
	var village: Node2D = toy.village
	check(village != null and state.day == 1, "day 1, the street")
	village.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))
	for who in ["jorun", "bo", "tove"]:
		await talk_to(village, who)
	var wall: Node2D = village.wall
	check(wall.shown_branches() == ["tove", "jorun", "bo"] and village.available_branches() == ["tove", "jorun", "bo"], "the three branches are on the wall: %s" % [wall.shown_branches()])
	check(is_equal_approx(wall.row_brightness("bo"), wall.ROW_REST) and is_equal_approx(wall.row_brightness("jorun"), wall.ROW_REST) and is_equal_approx(wall.row_brightness("tove"), wall.ROW_REST), "no target yet: every row rests at %.2f" % wall.ROW_REST)
	var lo := 2.0
	var hi := 0.0
	for i in 160:   # more than one swing (2.5 s)
		await get_tree().physics_frame
		lo = minf(lo, wall.goal_pulse_scale("jorun"))
		hi = maxf(hi, wall.goal_pulse_scale("jorun"))
	check(lo < 1.0 - wall.PULSE * 0.9 and hi > 1.0 + wall.PULSE * 0.9 and is_equal_approx(wall.rows.jorun.get_node("Goal").scale.x, wall.goal_pulse_scale("jorun")), "a question mark's box pulses slowly: scale %.3f..%.3f over 160 frames" % [lo, hi])
	await choose(village, "bo")
	check(is_equal_approx(wall.row_brightness_target("bo"), 1.0) and is_equal_approx(wall.row_brightness_target("jorun"), wall.ROW_DIM) and wall.row_brightness("bo") > wall.ROW_REST and wall.row_brightness("jorun") < wall.ROW_REST, "the chosen row is brightening (%.2f) and the others dimming (%.2f)" % [wall.row_brightness("bo"), wall.row_brightness("jorun")])
	for i in 30:
		await get_tree().physics_frame
	check(is_equal_approx(wall.row_brightness("bo"), 1.0) and is_equal_approx(wall.row_brightness("jorun"), wall.ROW_DIM) and is_equal_approx(wall.row_brightness("tove"), wall.ROW_DIM) and wall.rows.bo.modulate == Color(1, 1, 1, 1) and wall.rows.tove.modulate.r < 0.6, "0.5 s on: Bo's row at full, Jorun's and Tove's at %.2f" % wall.ROW_DIM)

	# Night 1: competent, down Bo's branch.
	var dream: Node2D = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_1") and dream.limit() == 8, "night 1: asleep (slept_1), the limit 8")
	check(dream.gauge_visible and state.gauge_visible, "the gauge is on")
	rows.append(await play(dream, "competent", 1))
	check(rows[0].end == "reached" and state.reached.get("bo", false) and state.ideas_kept == ["pills"] and state.scraps == ["round", "square", "long"], "the pills reached with three thoughts: %s" % [state.scraps])
	village = await morning(2)

	# Day 2: the Desk: the pills in full; the developed show.
	await do_desk(village, "pills", "full")
	check(state.pill_bonus == 2 and state.night_limit() == 10 and harness.summary().contains("  desk_full:pills"), "the pill in full: pill_bonus 2, the limit 10 from now on (desk_full:pills)")
	check(village.thing_node("pills") != null and state.scraps.is_empty() and state.ideas_kept.is_empty(), "the jar is by the bunk; no thought left over; the desk is clear")
	check(village.desk != null and village.desk.developing(), "the desk stays drawn for its developed show")
	var frames := await wait_until(func() -> bool: return village.desk != null and village.desk.developed_name() != "", 30)
	check(frames < 30 and village.desk.developed_name() == "The Pills", "the card landed: '%s' over the outline" % village.desk.developed_name())
	frames = await wait_until(func() -> bool: return village.desk == null, 120)
	check(frames < 120 and frames > 60, "the desk went %d frames later (1.5 s)" % frames)
	check(village.wall.goal_text("bo") == "The Pills" and village.wall.progress_text("bo") == "", "the wall names the pills, no progress: developed")
	await choose(village, "jorun")

	# Night 2: competent, H once, down Jorun's branch.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_2") and dream.limit() == 10 and is_equal_approx(dream.gauge_height(), 160.0), "night 2: asleep (slept_2), the limit 10, the gauge 160 px")
	await press_key(KEY_H)
	check(not dream.gauge_visible and not dream.gauge.visible and not state.gauge_visible, "H: the gauge is off, and the state remembers")
	rows.append(await play(dream, "competent", 2))
	check(rows[1].end == "reached" and state.ideas_kept == ["sixteen_stairs"] and state.scraps.size() == 3, "Sixteen Stairs reached; three thoughts home: %s" % [state.scraps])
	village = await morning(3)

	# Day 3: the Desk: 3 of 4; the outline waits.
	await do_desk(village, "sixteen_stairs", "kept")
	check(state.outline_count("sixteen_stairs") == 3 and state.ideas_kept == ["sixteen_stairs"] and state.scraps.is_empty() and harness.summary().contains("desk_kept  sixteen_stairs:3/4"), "3 of 4 fitted and the walker walked away: the outline waits with its three (desk_kept sixteen_stairs:3/4)")
	check(village.plot_state("sixteen_stairs") == "empty" and not state.has_flag("developed:sixteen_stairs") and village.wall.progress_text("jorun") == "3 / 4", "no scaffold yet; the wall says '%s'" % village.wall.progress_text("jorun"))
	await choose(village, "tove")

	# Night 3: competent, the gauge still off; Tove's branch: the lantern.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_3") and dream.limit() == 10, "night 3: asleep (slept_3), the limit still 10 (the pill is permanent)")
	check(not dream.gauge_visible and not dream.gauge.visible, "the gauge stays off the next night without a key pressed")
	check(dream.tonight_scraps.hub == ["round", "square"] and dream.missing_shapes("tove").is_empty(), "Tove's branch not reached yet: the plain deal (the hub's round and square)")
	rows.append(await play(dream, "competent", 3))
	check(rows[2].end == "reached" and state.ideas_kept == ["sixteen_stairs", "lantern"] and state.scraps == ["round", "square", "square"], "the lantern reached; three thoughts home: %s; two outlines on the desk, Jorun's first" % [state.scraps])
	village = await morning(4)

	# Day 4: the Desk: Jorun's outline first (the oldest); the round completes it.
	check(village.desk_on and village.desk.idea == "sixteen_stairs" and village.desk.filled == ["round", "square", "long", ""] and village.desk.hand == 3 and village.desk.cards == ["round", "square", "square"], "day 4: the Desk shows Jorun's outline with yesterday's three, the hand on the last slot")
	await do_desk(village, "sixteen_stairs", "full")
	check(state.ideas_claimed.get("sixteen_stairs", "") == "sixteen_stairs" and village.plot_state("sixteen_stairs") == "scaffold" and harness.summary().contains("  desk_full:sixteen_stairs"), "the building in full: a scaffold on the plot (desk_full:sixteen_stairs)")
	check(state.scraps == ["square", "square"] and state.ideas_kept == ["lantern"] and village.wall.progress_text("jorun") == "" and village.wall.progress_text("tove") == "0 / 5", "the two squares kept; the lantern's outline next (the wall: '%s')" % village.wall.progress_text("tove"))
	await check_crossbars(village, "sixteen_stairs")
	await choose(village, "tove")

	# Night 4: competent, Tove's branch again, already reached: the favoured deal, the self-pinch.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_4") and dream.limit() == 10, "night 4: asleep (slept_4), the limit 10")
	check(dream.missing_shapes("tove") == ["long", "round", "square", "long", "round"] and dream.tonight_scraps.hub == ["long", "round"] and dream.tonight_scraps.e == ["round", "long"], "her branch reached and its outline waiting: the deal favours the lantern's missing shapes: %s" % [dream.tonight_scraps])
	rows.append(await play(dream, "competent", 4))
	check(rows[3].end == "self" and state.ideas_kept == ["lantern"] and state.scraps == ["square", "square", "long", "round", "round"] and harness.summary().contains("  self_pinch"), "Tove's room held no idea the second time: pinched awake with three more thoughts (self_pinch): %s" % [state.scraps])
	village = await morning(5)

	# Day 5: Sixteen Stairs stands; the Desk: the lantern's outline, four of five.
	check(state.ideas_built.get("sixteen_stairs", "") == "sixteen_stairs" and village.plot_state("sixteen_stairs") == "built" and village.lit_tiles() == 4 and harness.summary().contains("  built:sixteen_stairs"), "day 5: Sixteen Stairs stands, 4 tiles lit (built:sixteen_stairs)")
	check(is_equal_approx(village.people.jorun.position.x, village.plot_rect("sixteen_stairs").get_center().x), "Jorun in front of it")
	check(village.desk_on and village.desk.idea == "lantern" and village.desk.filled == ["", "", "", "", ""] and village.desk.cards.size() == 5, "the Desk lays the lantern's outline, five empty slots, the five cards")
	await do_desk(village, "lantern", "kept")
	check(state.outline_count("lantern") == 4 and state.outlines.lantern == ["long", "round", "square", "", "round"] and state.scraps == ["square"] and village.wall.progress_text("tove") == "4 / 5", "four of five fit (a long is missing): the lantern's outline waits at '%s', one square kept" % village.wall.progress_text("tove"))

	# The end of the four nights.
	var summary: String = harness.summary()
	check(summary.contains("  slept_4"), "slept_4 is recorded")
	check(state.ideas_built.has("sixteen_stairs") and village.plot_state("sixteen_stairs") == "built", "Sixteen Stairs stands")
	check(state.pill_bonus == 2 and state.night_limit() == 10, "pill_bonus 2")
	check(state.ideas_kept == ["lantern"] and state.outline_count("lantern") >= 1 and not state.lantern, "the lantern's outline is started on the desk (%d of 5), not developed yet" % state.outline_count("lantern"))
	check(state.reached.size() == 3 and summary.count("  reached:") == 3, "all three ideas were reached: %s" % [state.reached.keys()])
	check(village.lit_tiles() == 4 and state.lit_tiles() == 3 + state.ideas_built.size(), "lit_tiles %d (3 + one per building)" % village.lit_tiles())
	var listed := true
	for m in ["slept_1", "slept_2", "slept_3", "slept_4", "reached:bo", "reached:jorun", "reached:tove", "kept:pills", "kept:sixteen_stairs", "kept:lantern", "desk_full:pills", "desk_full:sixteen_stairs", "built:sixteen_stairs", "self_pinch", "grabbed_scrap", "woke_gentle"]:
		listed = listed and summary.contains("  %s" % m)
	check(listed, "the summary lists the milestones")
	check(not summary.contains("woke_sudden") and state.tally == 0, "no sudden waking: the tally is 0")
	check(summary.contains("fit  ") and summary.contains("desk_kept  ") and not summary.contains("desk_weak") and not summary.contains("breakfast"), "the summary lists fits and the kept outlines, no weak grade, no breakfast")
	check(hand_placed == 0, "no thought was placed by hand: every card came up from a night")
	check(harness.log_path != "" and FileAccess.file_exists(harness.log_path), "the harness log is on disk: %s" % ProjectSettings.globalize_path(harness.log_path))
	print_table()
	print("--- summary() ---\n%s\n--- end ---" % summary)
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# --- the day ---------------------------------------------------------------------

## A village entering the toy: the instant it is ready, the lit windows'
## alphas of the plots that stand since this morning.
func _watch_village(node: Node) -> void:
	if node.name != "Village":
		return
	node.ready.connect(func() -> void:
		windows_at_start = {}
		for plot in node.lit_today:
			var plot_node: Node2D = node.plot_node(plot)
			if plot_node != null and plot_node.has_node("Window"):
				windows_at_start[plot] = plot_node.get_node("Window").modulate.a
		node.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail])))


## Walk to the bunk and E; the dream.
func go_to_bed(village: Node2D) -> Node2D:
	var frames := await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.bunk_in_range() and village.prompt_label.text == str(toy.words.sleep_prompt), "at the bunk in %d frames: '%s'" % [frames, village.prompt_label.text])
	await press_key(KEY_E)
	await settle()
	return toy.dream


## The driver plays the night; the row for the table.
func play(dream: Node2D, play_mode: String, night: int) -> Dictionary:
	var limit: int = dream.limit()   # read now: the controller frees the dream at the waking
	var target: String = state.target
	driver.attach(dream, play_mode)
	var row: Dictionary = await driver.play_night()
	row["night"] = night
	row["mode"] = play_mode
	row["limit"] = limit
	row["branch"] = target
	row["home"] = state.scraps.duplicate()
	check(row.end != "stuck", "night %d %s (%s): %s in %s, lucidity %d, effective %d of %d, %d thought(s), %.1f s; %s" % [night, play_mode, target, row.end, row.rooms, row.lucidity, row.effective, row.limit, row.scraps, row.seconds, driver.did])
	return row


## E by a villager: their branch goes on the wall (SPEC-2).
func talk_to(village: Node2D, who: String) -> void:
	var frames := await walk_walker_to(village, village.people[who].position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and state.has_flag("talked:%s" % who) and village.wall.shown_branches().has(who), "talked to %s: their branch is on the wall" % who)


## E at the wall, then the number of `who` among the branches offered: tonight's dream (SPEC-2).
func choose(village: Node2D, who: String) -> void:
	var frames := await walk_walker_to(village, village.WALL_X)
	await press_key(KEY_E)
	await get_tree().process_frame
	var index: int = village.available_branches().find(who)
	check(frames < WALK_FRAMES and village.picking_target and index >= 0, "E at the wall: the picker is up, %s is choice %d" % [who, index + 1])
	await press_key(KEY_1 + index)
	await get_tree().process_frame
	check(state.target == who and not village.picking_target and village.wall.tonight_text() != "", "%d: tonight is %s's dream ('%s')" % [index + 1, who, village.wall.tonight_text()])


## After the night: the picker if two or more were carried (keep the
## first), then the village of day `day`; the morning a building stands,
## its window fades in.
func morning(day: int) -> Node2D:
	await settle()
	if toy.picking:
		await press_key(KEY_1)
		check(not toy.picking, "the picker: kept the first")
	var frames := await wait_until(func() -> bool: return state.day == day and toy.village != null, 300)
	var village: Node2D = toy.village
	check(frames < 300 and village != null, "day %d: the village is back (on the desk: %s; thoughts: %s)" % [day, state.ideas_kept, state.scraps])
	if not village.lit_today.is_empty():
		var plot: String = village.lit_today[0]
		check(windows_at_start.has(plot) and is_zero_approx(windows_at_start[plot]), "%s stands this morning: its lit window was at alpha %.3f the instant the village appeared" % [plot, windows_at_start.get(plot, -1.0)])
		for i in 90:
			await get_tree().physics_frame
		var alpha: float = village.plot_node(plot).get_node("Window").modulate.a
		check(is_equal_approx(alpha, 1.0) and is_equal_approx(village.window_alpha(plot), 1.0), "90 frames on: the window is lit, alpha %.3f" % alpha)
	return village


## The Desk: `idea` on it (or "" for the blank outline), every card into
## a slot it fits through the keys (1 2 3 4 5 6 pick, E fit, D on; a slot
## no card fits is passed over), until every slot is filled ("full": the
## thing developed) or no card fits what is left ("kept": the walker walks
## away, the outline waits).
func do_desk(village: Node2D, idea: String, grade: String) -> void:
	var desk: Node2D = village.desk
	check(village.desk_on and desk != null and desk.idea == idea and is_equal_approx(village.walker.position.x, village.TABLE.get_center().x), "the Desk: %s on it, %s; the walker at the table" % [desk.outline_name if desk else "", desk.cards if desk else []])
	var total: int = desk.slots.size() if desk != null else 0   # read now: the Desk node goes when it ends
	var fitted := 0
	var passed := 0
	while village.desk_on and desk.filled_count() < total and passed < total:
		var slot: String = desk.slots[desk.hand]
		var pick := -1
		if desk.filled[desk.hand] == "":
			for i in desk.cards.size():
				if slot == "any" or desk.cards[i] == slot:
					pick = i
					break
		if pick >= 0:
			await press_key(KEY_1 + pick)
			await press_key(KEY_E)
			fitted += 1
			passed = 0
		else:
			passed += 1
		if village.desk_on and desk.filled_count() < total:
			if desk.hand < total - 1:
				await press_key(KEY_D)
			else:
				for i in total - 1:
					await press_key(KEY_A)
	await get_tree().process_frame
	if grade == "full":
		check(not village.desk_on and village_acts.has(["desk", "filled"]) and fitted > 0 and village_acts.has(["desk_full", idea]) and state.has_flag("developed:%s" % idea), "%d fitted by the keys: every slot: the Desk is over, %s developed in full" % [fitted, idea])
	else:
		check(village.desk_on and fitted > 0 and not desk.complete(), "%d fitted by the keys, the rest do not fit: the outline is not complete" % fitted)
		var frames := await walk_walker_to(village, village.TABLE.get_center().x + village.DESK_RANGE + 20.0)
		await get_tree().process_frame
		check(frames < WALK_FRAMES and not village.desk_on and village_acts.has(["desk", "walked"]) and not village_acts.has(["desk_full", idea]), "walked away: the Desk is over, nothing developed")
	village_acts = []


## A scaffold claimed just now: no crossbar yet, one more every second.
func check_crossbars(village: Node2D, plot: String) -> void:
	check(village.plot_state(plot) == "scaffold" and village.crossbars_shown(plot) == 0, "%s: a scaffold, no crossbar yet" % plot)
	var bars := 0
	for child in village.plot_node(plot).get_children():
		if child.has_meta("bar"):
			bars += 1
	for i in 62:
		await get_tree().physics_frame
	var one: int = village.crossbars_shown(plot)
	for i in 60:
		await get_tree().physics_frame
	var two: int = village.crossbars_shown(plot)
	var visible := 0
	for child in village.plot_node(plot).get_children():
		if child.has_meta("bar") and child.visible:
			visible += 1
	check(bars == 3 and one == 1 and two == 2 and visible == 2, "a second on, one crossbar; two seconds, two of %d (drawn %d)" % [bars, visible])


## The table: one row per night.
func print_table() -> void:
	print("--- four nights (pinch.tscn, the state carried on, one chosen branch each, no thought placed by hand) ---")
	print("%-5s %-6s %-9s %-5s %-24s %-6s %-4s %-5s %-5s %-7s %-9s %-5s %-8s %-24s %s" % ["night", "branch", "mode", "limit", "rooms", "scraps", "set", "fall", "fail", "wonder", "lucidity", "eff", "end", "home (the desk's cards)", "seconds"])
	for row in rows:
		var a: Dictionary = row.acts
		print("%-5d %-6s %-9s %-5d %-24s %-6d %-4d %-5d %-5d %-7d %-9d %-5d %-8s %-24s %.1f" % [row.night, row.branch, row.mode, row.limit, ",".join(row.rooms), a.get("grab_scrap", 0), a.get("set_down_scrap", 0), a.get("fall", 0), a.get("fail", 0), a.get("wonder", 0), row.lucidity, row.effective, row.end, ",".join(row.home), row.seconds])
	print("--- end ---")


# --- helpers -------------------------------------------------------------------

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


## Walk the walker to within `near` px of x, or until the frames run out.
func walk_walker_to(village: Node2D, x: float, near := 8.0) -> int:
	var frames := 0
	while absf(village.walker.position.x - x) > near and frames < WALK_FRAMES:
		Input.action_press("move_right" if village.walker.position.x < x else "move_left")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_right")
	Input.action_release("move_left")
	await get_tree().physics_frame
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
