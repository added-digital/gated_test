extends Node2D
## Scripted play of the day half of toy 4b, PINCH, headless, and the sleep
## gauge. The walker is driven through the input actions and the keys (E,
## 1 2 3, D, H through the input system), the dream through its API
## (jump_to_room, redeal, place_scrap, grab_scrap, fall, lie_down).
## Sections: (6) the gauge on dream.tscn alone: 128 px for a limit of 8,
## three bands labelled from rooms.json, the band and the eased needle at
## effective 0, 3 (deep: up to 0.4 of the limit), 6 (light: up to 0.75)
## and 8 (waking), "thoughts n / carry", H hides and shows it, the frame
## unchanged by it; then one run through pinch.tscn, four nights: (1)
## night 1: one thought grabbed in the bed room (dealt by hand), the limit
## by falls: a sudden waking that keeps it without a picker (one thing),
## the wake line for a thought; day 2: no Desk for one thought; (3) E at
## Jorun: his tally:1 line, once, then the greeting; (2) night 2 gentle
## and empty (the bed, by hand), the dream chosen at the wall first; day
## 3: (4) Tove's request after the wake line: the pills are in Bo's dream
## (asked:pills), her line repeats until Bo's idea is reached; Bo talked
## to, his dream chosen; night 3: Bo's room, three thoughts by hand, the
## idea reached; day 4: the Desk with the pills, three fitted: the pill
## in full (pill_bonus 2), Tove's and Bo's lines for it, the jar by the
## bunk; night 4: the bunk offers no pill, the dream's limit is 10, the
## gauge 160 px tall, effective 8 does not wake (the waking band, the
## needle at 0.8); day 5: the limit is still 10 (the pill is permanent);
## (7) the summary lists the milestones. Day B: breakfast, the stove shed,
## the pill at the bunk and the taller hat are gone, so the day-4 sections
## that played them (breakfast, making, Bo's loft, carry 3) are replaced
## by the Desk's pill; ideas.json holds the three branch ideas. Prints
## PASS/FAIL per check and quits with 0 only if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const TOY := preload("res://prototypes/pinch/pinch.tscn")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const VILLAGE_FILE := "res://prototypes/pinch/data/village.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const WALK_FRAMES := 900   # 15 s at 60 Hz: the longest walk here is under 800 px
const SETTLE := 20

var failures := 0
var toy: Node
var panel: CanvasLayer
var harness: Node
var state: PinchState
var rooms_json: Dictionary
var village_json: Dictionary
var people_json: Dictionary
var wakes: Array = []
var village_acts: Array = []   # [kind, detail] per village acted signal


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	rooms_json = PinchState.load_json(ROOMS_FILE)
	village_json = PinchState.load_json(VILLAGE_FILE)
	people_json = PinchState.load_json(CHARACTERS_FILE)
	var gauge_words: Dictionary = rooms_json.gauge
	var tove: Dictionary = person("tove")
	var jorun: Dictionary = person("jorun")
	var bo: Dictionary = person("bo")

	# ---------------------------------------------------------------- (6) the gauge, on the dream alone
	var alone := PinchState.new()
	var dream: Node2D = DREAM.instantiate()
	dream.state = alone
	add_child(dream)
	await get_tree().physics_frame
	check(dream.limit() == 8 and dream.gauge != null and dream.gauge.visible and dream.gauge_visible, "a plain night: the limit 8, the gauge up and on by default")
	check(dream.gauge.get_parent() is CanvasLayer and dream.gauge.get_parent().layer > dream.frame_top.get_parent().layer and dream.gauge.get_parent().layer < 10, "the gauge sits on its own layer (%d) over the frame's (%d), under the text panel" % [dream.gauge.get_parent().layer, dream.frame_top.get_parent().layer])
	check(is_equal_approx(dream.gauge_height(), 128.0), "the bar is 16 px per point: %.0f px tall" % dream.gauge_height())
	var deep: ColorRect = dream.gauge_bands.deep
	var light: ColorRect = dream.gauge_bands.light
	var waking: ColorRect = dream.gauge_bands.waking
	check(is_equal_approx(deep.size.y, 51.2) and is_equal_approx(light.size.y, 44.8) and is_equal_approx(waking.size.y, 32.0), "the bands: deep %.1f px (0 to 0.4), light %.1f (to 0.75), waking %.1f (the rest)" % [deep.size.y, light.size.y, waking.size.y])
	check(is_equal_approx(deep.position.y + deep.size.y, 0.0) and is_equal_approx(light.position.y + light.size.y, deep.position.y) and is_equal_approx(waking.position.y + waking.size.y, light.position.y), "stacked from the bar's bottom up: deep, light, waking")
	check(dream.gauge_labels.deep.text == str(gauge_words.deep) and dream.gauge_labels.light.text == str(gauge_words.light) and dream.gauge_labels.waking.text == str(gauge_words.waking), "labelled '%s', '%s', '%s' from rooms.json" % [dream.gauge_labels.deep.text, dream.gauge_labels.light.text, dream.gauge_labels.waking.text])
	check(dream.scraps_label.text == str(gauge_words.scraps).format({"n": 0, "limit": 3}) and not gauge_words.has("ideas"), "beside it: '%s' (thoughts, not ideas: day B)" % dream.scraps_label.text)
	check(dream.effective() == 0 and dream.gauge_band() == "deep" and is_zero_approx(dream.gauge_fraction()) and is_equal_approx(dream.gauge_needle.position.y, -1.5), "effective 0: deep, the needle at the bottom")
	for i in 3:
		dream.fall()
	check(dream.effective() == 3 and dream.gauge_band() == "deep", "effective 3: still deep (3 <= 8 * 0.4 = 3.2: the deep/light boundary is at 0.4 of the limit, inclusive)")
	var needle_10 := 0.0
	for i in 10:
		await get_tree().physics_frame
	needle_10 = dream.gauge_fraction()
	for i in 20:
		await get_tree().physics_frame
	check(needle_10 > 0.0 and needle_10 < 0.375 and is_equal_approx(dream.gauge_fraction(), 0.375), "the needle eased like the frame: %.3f after 10 frames, 3/8 after 30" % needle_10)
	check(is_equal_approx(dream.gauge_needle.position.y, -0.375 * 128.0 - 1.5), "drawn at 3/8 of the bar: y = %.1f" % dream.gauge_needle.position.y)
	for i in 3:
		dream.fall()
	for i in 30:
		await get_tree().physics_frame
	check(dream.effective() == 6 and dream.gauge_band() == "light" and is_equal_approx(dream.gauge_fraction(), 0.75), "effective 6: light (6 <= 8 * 0.75), the needle at 0.75")
	var frame_before: Rect2 = dream.frame_open
	await press_key(KEY_H)
	check(not dream.gauge_visible and not dream.gauge.visible, "H hid the gauge")
	check(dream.frame_open == frame_before and dream.frame_top.visible, "the frame stays")
	await press_key(KEY_H)
	check(dream.gauge_visible and dream.gauge.visible, "H again showed it")
	for i in 2:
		dream.fall()
	for i in 30:
		await get_tree().physics_frame
	check(dream.effective() == 8 and dream.gauge_band() == "waking" and is_equal_approx(dream.gauge_fraction(), 1.0) and dream.closing, "effective 8: waking, the needle at the top, the frame closing")
	remove_child(dream)
	dream.queue_free()
	await get_tree().physics_frame

	# ---------------------------------------------------------------- the toy, four nights
	toy = TOY.instantiate()
	add_child(toy)
	panel = toy.panel
	harness = toy.harness
	state = toy.get_state()
	var words: Dictionary = toy.words
	var village: Node2D = toy.village
	for i in 10:
		await get_tree().physics_frame
	check(village != null and not village.desk_on and village.panel == panel, "day 1: the village is up, no Desk (nothing to work on), the controller's panel")
	check(village.people.size() == 3 and village.people.has("tove") and village.people.has("jorun") and village.people.has("bo"), "three people stand on the street")
	check(village.people.jorun.position.x == village.DOOR_X and village.people.bo.position.x == village.plot_rect("bos_loft").get_center().x and village.people.tove.position.x > village.STOVE.end.x, "Jorun by the door (x %.0f), Bo by his plot (x %.0f), Tove by the stove (x %.0f)" % [village.people.jorun.position.x, village.people.bo.position.x, village.people.tove.position.x])
	check(village.people.jorun.get_node("Name").text == str(jorun.name) and not village.people.jorun.has_node("Want") and not people_json.has("want_line"), "a name over Jorun's head, and no want line (day B: gone with breakfast)")

	# (1) Night 1: one thought, then the limit; a sudden waking keeps it.
	var frames := await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < WALK_FRAMES and dream != null and harness.summary().contains("slept_1"), "night 1: asleep")
	hook(dream)
	check(bed_room(dream), "(the bed room, dealt by hand)")
	dream.place_scrap("round", Vector2(300, 556))
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == ["round"], "took a round thought")
	check(dream.effective() == 2 and dream.gauge_band() == "deep" and dream.scraps_label.text == str(gauge_words.scraps).format({"n": 1, "limit": 3}), "effective 2, deep; the gauge reads '%s'" % dream.scraps_label.text)
	for i in 6:
		dream.fall()
	check(dream.effective() == 8 and dream.closing, "six falls: the limit; the frame closes")
	frames = await wait_until(func() -> bool: return state.day == 2, 200)
	check(frames < 200 and state.tally == 1 and state.scraps == ["round"] and not toy.picking, "woke suddenly with one thought: kept without a picker; tally 1, day 2")
	Input.action_release("pinch")

	# Day 2: no Desk; Jorun's tally line.
	village = await new_village()
	check(village != null and not village.desk_on and state.desk_done_day == 0, "day 2: one thought is no Desk")
	check(panel.say_label.text == str(words.wake_sudden_scrap), "the wake line is up: '%s'" % panel.say_label.text)
	# (3) Talk: Jorun's tally line, then the greeting.
	frames = await walk_walker_to(village, village.DOOR_X)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.character_in_reach() == "jorun" and village.prompt_label.visible and village.prompt_label.text == str(words.talk_prompt), "at Jorun: the prompt reads '%s'" % village.prompt_label.text)
	var tally_line: String = line_of(jorun, "tally_1")
	check(village.line_for("jorun").id == "tally_1", "the line Jorun would give is tally_1 (tally %d)" % state.tally)
	await press_key(KEY_E)
	check(panel.say_label.text == tally_line and tally_line != "", "E at Jorun: '%s'" % panel.say_label.text)
	check(state.has_flag("talked:jorun") and state.has_flag("said:jorun:tally_1") and harness.summary().contains("talk:jorun") and village.wall.shown_branches() == ["jorun"], "talked:jorun; the harness recorded talk:jorun; his branch is on the wall")
	await press_key(KEY_E)
	check(panel.say_label.text == str(jorun.greeting), "E again: the greeting: '%s'" % panel.say_label.text)

	# (2) Night 2, gentle and empty; the dream chosen at the wall first.
	frames = await walk_walker_to(village, village.WALL_X)
	await press_key(KEY_E)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.picking_target and panel.choice_box.get_child_count() == 1, "SPEC-2: E at the wall: the picker with Jorun's branch alone")
	await press_key(KEY_1)
	await get_tree().process_frame
	check(state.target == "jorun" and not village.picking_target, "1: tonight is Jorun's dream")
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(words.sleep_prompt), "at the bunk: '%s'" % village.prompt_label.text)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and harness.summary().contains("slept_2"), "night 2")
	hook(dream)
	await sleep_in_bed(dream)
	check(state.day == 3 and wakes.size() == 1 and wakes[0][0] == false, "woke gently on day 3")
	village = await new_village()
	check(not village.desk_on and state.scraps == ["round"], "no Desk: still the one thought")

	# (4) The pills: Tove's request sends you to Bo's dream.
	check(panel.say_label.text == str(words.wake_gentle) and village.lines_waiting().size() == 1 and village.lines_waiting()[0] == str(tove.request.text), "the wake line first; Tove's request waits behind it")
	check(state.has_flag("asked:pills") and harness.summary().contains("request  pills") and str(tove.request.text).contains(bo.name), "asked:pills is set; the harness recorded the request; the line names Bo")
	frames = await wait_until(func() -> bool: return panel.say_label.text == str(tove.request.text), 260)
	check(frames < 260 and frames > 100, "then Tove's line, %d frames on: '%s'" % [frames, panel.say_label.text])
	check(not village.has_method("can_make") and not village.has_method("make_pills") and not village.has_method("take_pill") and not words.has("make_prompt"), "no stove shed to make at, no pill to take at the bunk (day B)")
	frames = await walk_walker_to(village, village.people.tove.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(tove, "pills_again"), "Tove: '%s'" % panel.say_label.text)
	await press_key(KEY_E)
	check(panel.say_label.text == line_of(tove, "pills_again"), "E again: she repeats it until Bo's idea is reached")
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == str(bo.greeting) and state.has_flag("talked:bo") and village.wall.shown_branches() == ["tove", "jorun", "bo"], "Bo: the greeting; his branch is on the wall under Tove's and Jorun's (Tove was talked to for the pills)")
	frames = await walk_walker_to(village, village.WALL_X)
	await press_key(KEY_E)
	await get_tree().process_frame
	var bo_index: int = village.available_branches().find("bo")
	check(frames < WALK_FRAMES and village.picking_target and bo_index == 2, "E at the wall: Bo is choice %d" % (bo_index + 1))
	await press_key(KEY_1 + bo_index)
	await get_tree().process_frame
	check(state.target == "bo", "tonight is Bo's dream")
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < WALK_FRAMES and dream != null and harness.summary().contains("slept_3") and dream.jump_to_room("goal_bo"), "night 3: Bo's room")
	hook(dream)
	Input.action_press("pinch")
	await settle()
	for shape in ["square", "long", "round"]:
		dream.place_scrap(shape, dream.dreamer.position + Vector2(0, -48))
		await get_tree().physics_frame
		check(dream.grab_scrap(), "(took %s by hand)" % shape)
	frames = await hold_until("move_right", func() -> bool: return dream.can_reach(), 600)
	check(frames < 600 and dream.reach(), "reached the pills")
	await settle()
	Input.action_release("pinch")
	check(state.day == 4 and wakes.size() == 1 and wakes[0][0] == false and state.ideas_kept == ["pills"] and state.scraps == ["round", "square", "long", "round"], "day 4 with the pills and four thoughts (the one from night 1 first)")

	# Day 4: the Desk: the pill in full.
	village = await new_village()
	check(village.desk_on and village.desk.idea == "pills" and village.desk.cards == ["round", "square", "long", "round"], "the Desk with the pills and the four cards")
	await fit_all(village)
	check(not village.desk_on and state.pill_bonus == 2 and state.night_limit() == 10 and state.lucidity_limit == 8 and village_acts.has(["desk_full", "pills"]), "three fitted: the pill in full: pill_bonus 2, the limit 10 from now on, the limit itself still 8")
	check(state.scraps == ["round"] and state.ideas_kept.is_empty() and harness.summary().contains("  desk_full:pills"), "one thought left over; the harness recorded desk_full:pills")
	check(village.thing_node("pills") != null, "the jar is by the bunk")
	frames = await walk_walker_to(village, village.people.tove.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(tove, "pills_developed"), "Tove: '%s'" % panel.say_label.text)
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(bo, "developed"), "Bo: '%s'" % panel.say_label.text)
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(words.sleep_prompt) and not words.has("sleep_prompt_pills"), "at the bunk: '%s': no pill to take" % village.prompt_label.text)
	await press_key(KEY_1)
	await get_tree().process_frame
	check(toy.dream == null and state.night_limit() == 10, "1 does nothing at the bunk")
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and harness.summary().contains("slept_4") and not harness.summary().contains("sleep  pill"), "night 4, the harness noting no pill")
	hook(dream)
	check(dream.limit() == 10 and is_equal_approx(dream.gauge_height(), 160.0) and is_equal_approx(dream.gauge_bands.waking.position.y, -160.0), "the dream's limit is 10; the gauge's top is 10: 160 px")
	for i in 5:
		dream.fall()
	check(dream.effective() == 5 and is_equal_approx(dream.aperture(), 0.5) and dream.gauge_band() == "light" and not dream.closing, "five falls: effective 5 of 10, aperture 0.5, light")
	check(bed_room(dream) and dream.room.exit == null, "(the bed room by hand, no exit: SPEC-2 deals no early bed)")
	for i in 3:
		dream.fall()
	for i in 30:
		await get_tree().physics_frame
	check(dream.effective() == 8 and not dream.closing and dream.gauge_band() == "waking" and is_equal_approx(dream.gauge_fraction(), 0.8), "effective 8 does not wake tonight: waking band, the needle at 0.8")
	await sleep_in_bed(dream)
	check(state.day == 5 and state.pill_bonus == 2 and state.night_limit() == 10, "day 5: the pill holds (the limit 10 again tonight)")
	village = await new_village()
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(bo, "reached"), "Bo, his developed line said: '%s'" % panel.say_label.text)

	# (7) The summary.
	var summary: String = harness.summary()
	var listed := true
	for m in ["slept_1", "slept_2", "slept_3", "slept_4", "grabbed_scrap", "woke_sudden", "woke_gentle", "reached:bo", "kept:pills", "desk_full:pills"]:
		listed = listed and summary.contains("  %s" % m)
	check(listed and not summary.contains("breakfast") and not summary.contains("told"), "the summary lists the milestones; no breakfast, no telling")
	print("--- summary() ---\n%s\n--- end ---" % summary)
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# --- helpers -------------------------------------------------------------------

func person(who: String) -> Dictionary:
	for c in people_json.characters:
		if c.id == who:
			return c
	return {}


## The text of one of a character's memory lines, by its id.
func line_of(c: Dictionary, id: String) -> String:
	for line in c.get("lines", []):
		if line.get("id", "") == id:
			return str(line.text)
	return ""


## Listen to a dream's wakings.
func hook(dream: Node2D) -> void:
	wakes = []
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps]))


## The village of a new morning, its doings listened to, three frames in.
func new_village() -> Node2D:
	var village: Node2D = toy.village
	village.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))
	for i in 3:
		await get_tree().physics_frame
	return village


## The bed room, dealt by hand (SPEC-2: the night no longer deals it); true once in it.
func bed_room(dream: Node2D) -> bool:
	if dream.current_room_id() != "bed":
		dream.redeal(["bed"] as Array[String], false)
	return dream.current_room_id() == "bed"


## Pinched, walk to the bed room's bed and lie down: a gentle waking.
func sleep_in_bed(dream: Node2D) -> void:
	bed_room(dream)
	Input.action_press("pinch")
	await settle()
	var frames := await hold_until("move_right", func() -> bool: return dream.bed_in_reach(), 400)
	check(frames < 400 and dream.lie_down(), "walked to the bed in %d frames and lay down" % frames)
	Input.action_release("pinch")
	await settle()


## Every card into the first slot it fits, through the keys: 1 2 3 4 picks
## the first card that matches the slot under the hand, E fits it, D moves on.
func fit_all(v: Node2D) -> void:
	var d: Node2D = v.desk
	var total: int = d.slots.size()
	while v.desk_on and d.filled_count() < total:
		var slot: String = d.slots[d.hand]
		var pick := -1
		for i in d.cards.size():
			if slot == "any" or d.cards[i] == slot:
				pick = i
				break
		if pick < 0:
			break
		await press_key(KEY_1 + pick)
		await press_key(KEY_E)
		if v.desk_on and d.hand < total - 1:
			await press_key(KEY_D)
	await get_tree().process_frame


func settle() -> void:
	for i in SETTLE:
		await get_tree().physics_frame


## Frames until the condition holds, or the budget runs out.
func wait_until(cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		await get_tree().physics_frame
		frames += 1
	return frames


## Hold one action until the condition holds, or the budget runs out.
func hold_until(action: String, cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		Input.action_press(action)
		await get_tree().physics_frame
		frames += 1
	Input.action_release(action)
	await get_tree().physics_frame
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
