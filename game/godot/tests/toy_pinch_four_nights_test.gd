extends Node2D
## Four full nights of toy 4b, PINCH (prototypes/pinch/pinch.tscn),
## headless, the whole second loop (SPEC-2, day B): the driver
## (tests/pinch_driver.gd) plays the dream, this script plays the day. Day
## 1 talks to Jorun, Bo and Tove (their branches on the wall) and chooses
## Bo's dream at the wall. Night 1 competent down Bo's branch: the pills
## reached with three thoughts; morning 2: the Desk, the three fitted into
## Bo's outline: the pill in full (pill_bonus 2, the limit 10 from now
## on). Night 2 Jorun's, with H pressed once (the gauge off for this night
## and the next, remembered in the state): Sixteen Stairs reached; morning
## 3: the Desk, four fitted (one is a leftover thought placed by hand
## before the night: the driver is not steered by shape and the hub always
## gives a round and a square, so a four-slot outline never fills from one
## night's three): the building in full, a scaffold whose crossbars appear
## one a second. Night 3 Tove's: the lantern reached; morning 4: Sixteen
## Stairs stands (its lit window fading in, 4 tiles lit, Jorun in front of
## it) and the Desk fills the lantern's five slots (three thoughts topped
## up by hand the same way): the lantern in full, every room named on the
## wall, the lantern lit by the door. Night 4 Bo's again: his branch was
## reached, so his room holds two thoughts and no idea; the driver takes
## what it can and pinches itself awake. Morning 5: thoughts alone fit the
## blank outline and reveal one more room on Jorun's branch. At the end:
## slept_1..4, Sixteen Stairs standing, pill_bonus 2, the lantern
## revealed, the milestones listed (reached:<who> for all three,
## desk_full for all three ideas, built:sixteen_stairs, self_pinch,
## desk_reveal:jorun), the log on disk. Prints the four nights' table and
## the harness summary, PASS/FAIL per check, and quits with 0 only if
## every check passes.

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
var crossbars_checked := false


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
	check(village.wall.shown_branches() == ["tove", "jorun", "bo"] and village.available_branches() == ["tove", "jorun", "bo"], "the three branches are on the wall: %s" % [village.wall.shown_branches()])
	await choose(village, "bo")

	# Night 1: competent, down Bo's branch.
	var dream: Node2D = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_1") and dream.limit() == 8, "night 1: asleep (slept_1), the limit 8")
	check(dream.gauge_visible and state.gauge_visible, "the gauge is on")
	rows.append(await play(dream, "competent", 1))
	check(rows[0].end == "reached" and state.reached.get("bo", false) and state.ideas_kept == ["pills"] and state.scraps.size() == 3, "the pills reached with %d thoughts: %s" % [state.scraps.size(), state.scraps])
	village = await morning(2)

	# Day 2: the Desk: the pills in full.
	await do_desk(village, "pills", "full")
	check(state.pill_bonus == 2 and state.night_limit() == 10 and harness.summary().contains("  desk_full:pills"), "the pill in full: pill_bonus 2, the limit 10 from now on (desk_full:pills)")
	check(village.thing_node("pills") != null and state.scraps.is_empty(), "the jar is by the bunk; no thought left over")
	state.scraps.append("round")   # a leftover from an earlier morning, by hand: Jorun's outline has four slots and a night brings three thoughts
	await choose(village, "jorun")

	# Night 2: competent, H once, down Jorun's branch.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_2") and dream.limit() == 10 and is_equal_approx(dream.gauge_height(), 160.0), "night 2: asleep (slept_2), the limit 10, the gauge 160 px")
	await press_key(KEY_H)
	check(not dream.gauge_visible and not dream.gauge.visible and not state.gauge_visible, "H: the gauge is off, and the state remembers")
	rows.append(await play(dream, "competent", 2))
	check(rows[1].end == "reached" and state.ideas_kept == ["sixteen_stairs"] and state.scraps.size() == 4 and state.scraps[0] == "round", "Sixteen Stairs reached; four thoughts home, the leftover first: %s" % [state.scraps])
	village = await morning(3)

	# Day 3: the Desk: Sixteen Stairs in full: a scaffold.
	await do_desk(village, "sixteen_stairs", "full")
	check(state.ideas_claimed.get("sixteen_stairs", "") == "sixteen_stairs" and village.plot_state("sixteen_stairs") == "scaffold" and harness.summary().contains("  desk_full:sixteen_stairs"), "the building in full: a scaffold on the plot (desk_full:sixteen_stairs)")
	await check_crossbars(village, "sixteen_stairs")
	for shape in ["long", "long", "round"]:   # by hand: the lantern's five slots want two longs and two rounds; Tove's branch gives a round and two squares
		state.scraps.append(shape)
	check(state.scraps.size() == 3, "(three thoughts placed by hand as leftovers for the lantern's outline)")
	await choose(village, "tove")

	# Night 3: competent, the gauge still off; Tove's branch.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_3") and dream.limit() == 10, "night 3: asleep (slept_3), the limit still 10 (the pill is permanent)")
	check(not dream.gauge_visible and not dream.gauge.visible, "the gauge stays off the next night without a key pressed")
	rows.append(await play(dream, "competent", 3))
	check(rows[2].end == "reached" and state.ideas_kept == ["lantern"] and state.scraps.size() == 6, "the lantern reached; six thoughts home: %s" % [state.scraps])
	village = await morning(4)

	# Day 4: Sixteen Stairs stands; the Desk: the lantern in full.
	check(state.ideas_built.get("sixteen_stairs", "") == "sixteen_stairs" and village.plot_state("sixteen_stairs") == "built" and village.lit_tiles() == 4 and harness.summary().contains("  built:sixteen_stairs"), "day 4: Sixteen Stairs stands, 4 tiles lit (built:sixteen_stairs)")
	check(is_equal_approx(village.people.jorun.position.x, village.plot_rect("sixteen_stairs").get_center().x), "Jorun in front of it")
	await do_desk(village, "lantern", "full")
	check(state.lantern and harness.summary().contains("  desk_full:lantern") and village.thing_node("lantern") != null, "the lantern in full: state.lantern, the lantern by the door (desk_full:lantern)")
	var all_named := true
	for who in ["tove", "jorun", "bo"]:
		for text in village.wall.row_room_names(who):
			all_named = all_named and text != ""
	check(all_named, "every room of every branch is named on the wall: Jorun's %s" % [village.wall.row_room_names("jorun")])
	check(state.scraps.size() == 1, "one thought left over: %s" % [state.scraps])
	await choose(village, "bo")

	# Night 4: competent, Bo's branch again, already reached.
	dream = await go_to_bed(village)
	check(dream != null and harness.summary().contains("slept_4") and dream.limit() == 10, "night 4: asleep (slept_4), the limit 10")
	rows.append(await play(dream, "competent", 4))
	check(rows[3].end == "self" and state.ideas_kept.is_empty() and state.scraps.size() >= 3 and harness.summary().contains("  self_pinch"), "Bo's room held no idea the second time: pinched awake with %d thoughts (self_pinch)" % state.scraps.size())
	village = await morning(5)

	# Day 5: thoughts alone reveal a room.
	check(village.desk_on and village.desk.idea == "" and village.desk.slots == ["any", "any", "any"], "day 5: the Desk with the blank outline")
	await do_desk(village, "", "reveal")
	check(village.picking_branch, "three fitted: the branch picker")
	var index: int = village.available_branches().find("jorun")
	await press_key(KEY_1 + index)
	await get_tree().process_frame
	check(not village.picking_branch and state.revealed.get("jorun", 0) == 1 and harness.summary().contains("  desk_reveal:jorun"), "%d: Jorun's branch grows a room (desk_reveal:jorun)" % (index + 1))

	# The end of the four nights.
	var summary: String = harness.summary()
	check(summary.contains("  slept_4"), "slept_4 is recorded")
	check(state.ideas_built.has("sixteen_stairs") and village.plot_state("sixteen_stairs") == "built", "Sixteen Stairs stands")
	check(state.pill_bonus == 2 and state.night_limit() == 10, "pill_bonus 2")
	check(state.lantern and state.has_flag("developed:lantern"), "the lantern revealed (developed in full)")
	check(state.reached.size() == 3 and summary.count("  reached:") == 3, "all three ideas were reached: %s" % [state.reached.keys()])
	check(village.lit_tiles() == 4 and state.lit_tiles() == 3 + state.ideas_built.size(), "lit_tiles %d (3 + one per building)" % village.lit_tiles())
	var listed := true
	for m in ["slept_1", "slept_2", "slept_3", "slept_4", "reached:bo", "reached:jorun", "reached:tove", "kept:pills", "desk_full:pills", "desk_full:sixteen_stairs", "desk_full:lantern", "built:sixteen_stairs", "self_pinch", "desk_reveal:jorun", "grabbed_scrap", "woke_gentle"]:
		listed = listed and summary.contains("  %s" % m)
	check(listed, "the summary lists the milestones")
	check(not summary.contains("woke_sudden") and state.tally == 0, "no sudden waking: the tally is 0")
	check(summary.contains("fit  ") and not summary.contains("sleep  pill") and not summary.contains("breakfast"), "the summary lists fits, no pill at the bunk, no breakfast")
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
	driver.attach(dream, play_mode)
	var row: Dictionary = await driver.play_night()
	row["night"] = night
	row["mode"] = play_mode
	row["limit"] = limit
	check(row.end != "stuck", "night %d %s: %s in %s, lucidity %d, effective %d of %d, %d thought(s), %.1f s; %s" % [night, play_mode, row.end, row.rooms, row.lucidity, row.effective, row.limit, row.scraps, row.seconds, driver.did])
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
## the first slot it fits through the keys (1 2 3 4 5 6 pick, E fit, D
## on), until every slot is filled; `grade` is what that should develop.
func do_desk(village: Node2D, idea: String, grade: String) -> void:
	var desk: Node2D = village.desk
	check(village.desk_on and desk != null and desk.idea == idea and is_equal_approx(village.walker.position.x, village.TABLE.get_center().x), "the Desk: %s on it, %s; the walker at the table" % [desk.outline_name if desk else "", desk.cards if desk else []])
	var total: int = desk.slots.size() if desk != null else 0   # read now: the Desk node goes when it ends
	var fitted := 0
	while village.desk_on and desk.filled_count() < total:
		var slot: String = desk.slots[desk.hand]
		var pick := -1
		for i in desk.cards.size():
			if slot == "any" or desk.cards[i] == slot:
				pick = i
				break
		if pick < 0:
			break
		await press_key(KEY_1 + pick)
		await press_key(KEY_E)
		fitted += 1
		if village.desk_on and desk.hand < total - 1:
			await press_key(KEY_D)
	await get_tree().process_frame
	check(not village.desk_on and village_acts.has(["desk", "filled"]) and fitted == total, "every slot filled by the keys (%d): the Desk is over" % fitted)
	if grade == "reveal":
		return
	check(village_acts.has(["desk_%s" % grade, idea]) and state.has_flag(("developed:%s" if grade == "full" else "developed_weak:%s") % idea), "%s developed %s" % [idea, grade])
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
	print("--- four nights (pinch.tscn, the state carried on, one chosen branch each) ---")
	print("%-5s %-9s %-5s %-24s %-6s %-4s %-5s %-5s %-7s %-9s %-5s %-8s" % ["night", "mode", "limit", "rooms", "scraps", "set", "fall", "fail", "wonder", "lucidity", "eff", "end"] + " home  seconds")
	for row in rows:
		var a: Dictionary = row.acts
		print("%-5d %-9s %-5d %-24s %-6d %-4d %-5d %-5d %-7d %-9d %-5d %-8s %-8d %.1f" % [row.night, row.mode, row.limit, ",".join(row.rooms), a.get("grab_scrap", 0), a.get("set_down_scrap", 0), a.get("fall", 0), a.get("fail", 0), a.get("wonder", 0), row.lucidity, row.effective, row.end, row.scraps, row.seconds])
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
