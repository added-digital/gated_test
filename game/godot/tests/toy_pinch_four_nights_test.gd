extends Node2D
## Four full nights of toy 4, PINCH (prototypes/pinch/pinch.tscn), headless,
## played like a person who is learning (day 5): the driver
## (tests/pinch_driver.gd) plays the dream, this script plays the day.
## Night 1 clumsy (one fall per room, a wrong pinch, a set-down: the frame
## shuts early and the picker keeps one); night 2 competent, with H
## pressed once (the gauge off for this night and the next, remembered in
## the state); the morning Tove asks, the pills are made at the stove shed
## (E held 3 s); one pill is taken at the bunk on night 3 (the limit 10);
## nights 3 and 4 competent, preferring the two ideas that build; every
## breakfast sat through, each idea offered to the face whose it is, the
## leftovers walked away from. On the way the feel is read: at a claim the
## face nods (6 px) and the idea's rect slides to it; a scaffold's
## crossbars appear one per second; the morning a building stands its lit
## window is at alpha 0 when the village appears and 1.0 after 90 frames.
## At the end: slept_4 recorded, at least two buildings standing,
## lit_tiles >= 5, the harness summary lists slept_1..4, a told:<idea>:<who>,
## a built:<plot>, the pills made, one pill taken, the log on disk. Prints
## the four nights' table and the harness summary, PASS/FAIL per check, and
## quits with 0 only if every check passes.

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
var claim_feel_checked := false
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
	var plots: Dictionary = toy.words.get("plots", {})
	for idea in toy.ideas:
		var becomes := str(idea.get("becomes", ""))
		if plots.has(becomes) and becomes != "lantern_post":
			driver.wants.append(str(idea.get("id", "")))
	check(driver.wants.size() == 2, "the two ideas that build: %s" % [driver.wants])
	for i in 10:
		await get_tree().physics_frame
	var village: Node2D = toy.village
	check(village != null and state.day == 1, "day 1, the street")

	# Night 1: clumsy.
	var dream: Node2D = await go_to_bed(village, false)
	check(dream != null and harness.summary().contains("slept_1"), "night 1: asleep (slept_1)")
	check(dream.gauge_visible and state.gauge_visible, "the gauge is on")
	rows.append(await play(dream, "clumsy", 1))
	village = await morning(2)

	# Day 2: breakfast.
	await do_breakfast(village)
	check(state.ideas_kept.is_empty(), "day 2: the table is bare after breakfast")

	# Night 2: competent, H once.
	dream = await go_to_bed(village, false)
	check(dream != null and harness.summary().contains("slept_2"), "night 2: asleep (slept_2)")
	await press_key(KEY_H)
	check(not dream.gauge_visible and not dream.gauge.visible and not state.gauge_visible, "H: the gauge is off, and the state remembers")
	rows.append(await play(dream, "competent", 2))
	village = await morning(3)

	# Day 3: breakfast, then Tove's request: the pills.
	check(state.has_flag("asked:pills") and not state.has_pills, "day 3: Tove asked for the pills (asked:pills)")
	await do_breakfast(village)
	var frames := await walk_walker_to(village, village.plot_rect("stove_shed").get_center().x)
	check(frames < WALK_FRAMES and village.can_make(), "at the stove shed")
	Input.action_press("interact")
	frames = await wait_until(func() -> bool: return state.has_pills, 240)
	Input.action_release("interact")
	await get_tree().process_frame
	check(frames < 240 and state.has_pills and harness.summary().contains("made  pills"), "E held %d frames: the pills are made" % frames)

	# Night 3: a pill; the gauge still off.
	dream = await go_to_bed(village, true)
	check(dream != null and harness.summary().contains("slept_3") and state.pill_tonight and dream.limit() == 10, "night 3: a pill taken, the limit 10 (slept_3)")
	check(not dream.gauge_visible and not dream.gauge.visible, "the gauge stays off the next night without a key pressed")
	rows.append(await play(dream, "competent", 3))
	village = await morning(4)
	check(state.night_limit() == 8, "day 4: the pill has worn off")
	await do_breakfast(village)

	# Night 4: competent.
	dream = await go_to_bed(village, false)
	check(dream != null and harness.summary().contains("slept_4") and dream.limit() == 8, "night 4: asleep (slept_4), the limit 8")
	rows.append(await play(dream, "competent", 4))
	village = await morning(5)
	await do_breakfast(village)

	# The end of the four nights.
	var summary: String = harness.summary()
	check(summary.contains("  slept_4"), "slept_4 is recorded")
	check(state.ideas_built.size() >= 2, "at least two buildings stand: %s" % [state.ideas_built])
	check(village.lit_tiles() >= 5 and state.lit_tiles() == 3 + state.ideas_built.size(), "lit_tiles %d (3 + one per building)" % village.lit_tiles())
	var listed := true
	for m in ["slept_1", "slept_2", "slept_3", "slept_4"]:
		listed = listed and summary.contains("  %s" % m)
	check(listed, "the summary lists slept_1..4")
	check(summary.contains("  told:") and summary.contains("  built:"), "the summary lists a told:<idea>:<who> and a built:<plot>")
	check(summary.contains("made  pills") and summary.count("sleep  pill") == 1, "the pills were made and one was taken")
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


## Walk to the bunk (1 for a pill first, if asked) and E; the dream.
func go_to_bed(village: Node2D, pill: bool) -> Node2D:
	var frames := await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.bunk_in_range(), "at the bunk in %d frames" % frames)
	if pill:
		check(village.prompt_label.text == str(toy.words.sleep_prompt_pills), "the prompt offers a pill: '%s'" % village.prompt_label.text)
		await press_key(KEY_1)
		await get_tree().process_frame
		check(state.pill_tonight, "1: a pill for tonight")
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
	check(row.end != "stuck", "night %d %s: %s in %s, lucidity %d, effective %d of %d, %d carried, %.1f s; %s" % [night, play_mode, row.end, row.rooms, row.lucidity, row.effective, row.limit, row.carried, row.seconds, driver.did])
	return row


## After the night: the picker if two or more were carried (keep a wanted
## idea when there is one), then the village of day `day`; the morning a
## building stands, its window fades in.
func morning(day: int) -> Node2D:
	await settle()
	if toy.picking:
		var names: Array = []
		for button in panel.choice_box.get_children():
			names.append(button.text)
		var pick := 0
		for i in names.size():
			for id in driver.wants:
				if names[i].ends_with(toy.idea_name(id)):
					pick = i
		await press_key(KEY_1 + pick)
		check(not toy.picking, "the picker: kept choice %d of %s" % [pick + 1, names])
	var frames := await wait_until(func() -> bool: return state.day == day and toy.village != null, 300)
	var village: Node2D = toy.village
	check(frames < 300 and village != null, "day %d: the village is back (%d idea(s) on the table: %s)" % [day, state.ideas_kept.size(), state.ideas_kept])
	if not village.lit_today.is_empty():
		var plot: String = village.lit_today[0]
		check(windows_at_start.has(plot) and is_zero_approx(windows_at_start[plot]), "%s stands this morning: its lit window was at alpha %.3f the instant the village appeared" % [plot, windows_at_start.get(plot, -1.0)])
		for i in 90:
			await get_tree().physics_frame
		var alpha: float = village.plot_node(plot).get_node("Window").modulate.a
		check(is_equal_approx(alpha, 1.0) and is_equal_approx(village.window_alpha(plot), 1.0), "90 frames on: the window is lit, alpha %.3f" % alpha)
	return village


## Breakfast: each kept idea in the hand (1, 2, 3), E at the face whose it
## is; an idea that is nobody's stays on the table; whatever is left is
## walked away from (to the bunk) and becomes a small thing.
func do_breakfast(village: Node2D) -> void:
	if state.ideas_kept.is_empty():
		check(not village.breakfast_on, "nothing on the table: no breakfast")
		return
	check(village.breakfast_on and village.seats.size() == 3, "breakfast: %s on the table, three faces" % [state.ideas_kept])
	for id in state.ideas_kept.duplicate():
		var who := str(village.idea_entry(id).get("whose", ""))
		if who == "" or not village.breakfast_on:
			continue
		var index: int = state.ideas_kept.find(id)
		await press_key(KEY_1 + index)
		check(village.hand_idea() == id, "%d: %s in the hand" % [index + 1, id])
		var frames := await walk_walker_to(village, village.seats[who].position.x)
		check(frames < WALK_FRAMES and village.seat_in_reach() == who, "at %s's seat" % who)
		var claims_before: int = state.ideas_claimed.size()
		var seat: Node2D = village.seats[who]   # the faces leave the table when the last idea is claimed, once the feel is done
		await press_key(KEY_E)
		check(not state.ideas_kept.has(id) and village_acts.has(["told", "%s:%s" % [id, who]]), "E: %s claimed %s" % [who, id])
		if not claim_feel_checked:
			claim_feel_checked = true
			await check_claim_feel(village, who, id, seat)
		if state.ideas_claimed.size() > claims_before and not crossbars_checked:
			crossbars_checked = true
			await check_crossbars(village, str(village.idea_entry(id).get("becomes", "")))
	if village.breakfast_on:
		var left: Array = state.ideas_kept.duplicate()
		await walk_walker_to(village, village.BUNK.get_center().x)
		check(not village.breakfast_on and state.breakfast_done_day == state.day, "walked away from the table: %s became small things" % [left])
	else:
		await walk_walker_to(village, village.BUNK.get_center().x)


## At a claim: the face nods (6 px down and back over 10 frames) and the
## idea's rect slides from the hand to the face over 0.4 s, then goes.
func check_claim_feel(village: Node2D, who: String, id: String, seat: Node2D) -> void:
	var face: Node2D = seat.get_node("Face")
	check(is_instance_valid(seat) and seat.get_parent() == village.seats_node, "%s's face is still at the table for the feel (breakfast %s)" % [who, "on" if village.breakfast_on else "over"])
	check(village.face_dip(who) > 0.0 and face.position.y > 0.0, "the claim: %s's face dips (%.1f px)" % [who, face.position.y])
	check(village.slides_in_flight() == 1 and village.slides_node.get_child_count() == 1 and village.slides_node.get_child(0).get_meta("id") == id, "the idea's rect is sliding to the face")
	var piece: Node2D = village.slides_node.get_child(0)
	var head: Vector2 = seat.position + Vector2(0, -village.CAPSULE.y)
	var start_distance: float = piece.position.distance_to(head)
	var deepest := 0.0
	for i in 5:
		await get_tree().physics_frame
		deepest = maxf(deepest, face.position.y)
	check(deepest >= village.NOD_PX * 0.9 and piece.position.distance_to(head) < start_distance, "5 frames on: the dip reached %.1f px, the rect is closer to the face (%.0f px, was %.0f)" % [deepest, piece.position.distance_to(head), start_distance])
	for i in village.NOD_FRAMES:
		await get_tree().physics_frame
	check(is_zero_approx(village.face_dip(who)) and is_zero_approx(face.position.y), "the nod is over, the face back up")
	for i in int(village.SLIDE * 60.0):
		await get_tree().physics_frame
	check(village.slides_in_flight() == 0 and village.slides_node.get_child_count() == 0, "the rect reached the face and is gone")
	await get_tree().physics_frame
	check(village.breakfast_on == (not state.ideas_kept.is_empty()) and (village.breakfast_on or village.seats_node.get_child_count() == 0), "then the faces leave the table if breakfast is over (%s)" % ("on" if village.breakfast_on else "over"))


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
	print("--- four nights (pinch.tscn, the state carried on) ---")
	print("%-5s %-9s %-5s %-30s %-5s %-4s %-5s %-5s %-7s %-9s %-5s %-5s" % ["night", "mode", "limit", "rooms", "grab", "set", "fall", "fail", "wonder", "lucidity", "eff", "end"] + " carried  seconds")
	for row in rows:
		var a: Dictionary = row.acts
		print("%-5d %-9s %-5d %-30s %-5d %-4d %-5d %-5d %-7d %-9d %-5d %-5s %-8d %.1f" % [row.night, row.mode, row.limit, ",".join(row.rooms), a.get("grab", 0), a.get("set_down", 0), a.get("fall", 0), a.get("fail", 0), a.get("wonder", 0), row.lucidity, row.effective, row.end, row.carried, row.seconds])
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
