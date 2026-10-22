extends Node2D
## Scripted play of toy 4, PINCH (prototypes/pinch/pinch.tscn), headless,
## day 1 of the build (the loop). The walker and the dreamer are driven
## through the input actions (Input.action_press), E and the number keys
## through the input system. The run: a clean start on day 1; walk to the
## bunk and sleep (slept_1, the dream is up); hold PINCH, grab two
## thoughts, force the block, hard falls cross the limit (lucidity 1, 2,
## 3, 4, 5, 6 against the acts table, the aperture matching effective / 8)
## and wake suddenly; the picker keeps the second thought (tally 1, day 2,
## one mark on the wall); sleep again, grab one thought, lie in the bed
## and wake gently (day 3, nothing lost); the dark mask covers the same 3
## tiles each day. The block and bed live in the first loop's bed room,
## which the second loop's dealer never deals (SPEC-2), so each night this
## test deals it by hand (redeal) and places the night's thoughts there by
## hand (place_scrap). Day B: ideas are never carried (the hat and grab()
## are gone), so the two ideas of the first loop's night are two scraps
## now, grabbed for +1 each (not +2, and no hand that counts double):
## the numbers below are the scrap's table; ideas.json holds the three
## branch ideas. The frame follows the dreamer and eases (check_frame
## reads the shown aperture); at the limit the frame is shut 0.8 s before
## woke fires, so the test waits for it. Prints PASS/FAIL per check and
## quits with 0 only if every check passes.

const TOY := preload("res://prototypes/pinch/pinch.tscn")
const WALK_FRAMES := 900   # 15 s at 60 Hz: the longest walk here is under 400 px
const SETTLE := 20         # frames for a body to land (a pinched drop from the hover takes 10) and the input to flush

var toy: Node
var panel: CanvasLayer
var harness: Node
var state: PinchState
var failures := 0
var wakes: Array = []   # [sudden, scraps] per woke signal seen


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	toy = TOY.instantiate()
	add_child(toy)
	panel = toy.panel
	harness = toy.harness
	state = toy.get_state()
	var words: Dictionary = toy.words
	var ideas: Array = toy.ideas
	var first := "round"
	var second := "square"

	# (a) Smoke: 60 frames clean, the village up on day 1.
	for i in 60:
		await get_tree().physics_frame
	check(harness.toy_name == "pinch", "the harness was started as 'pinch' (%s)" % harness.toy_name)
	check(ideas.size() == 3, "ideas.json holds 3 ideas (%d; day B: the three branch ideas, the first loop's five gone)" % ideas.size())
	check(state.day == 1 and state.lucidity_limit == 8 and state.carry_scraps == 3 and state.tally == 0 and state.pill_bonus == 0, "the state starts on day 1, limit 8, carry 3 thoughts, tally 0, no pill")
	var village: Node2D = toy.village
	check(village != null and toy.dream == null and village.get_parent() == toy and village.name == "Village", "the village is the active scene on day 1")
	check(village.day_label.text == str(words.day_label).format({"day": 1}), "the day label reads '%s'" % village.day_label.text)
	check(village.tally_wall.text == "", "the tally wall is blank on day 1")
	check(village.walker.is_on_floor() and absf(village.walker.position.y - (village.GROUND_Y - 28.0)) < 1.0, "the walker stands on the ground line, y = %.1f" % village.walker.position.y)
	check(village.street.get_child_count() >= 6, "the street holds the buildings, the plots and their labels (%d nodes)" % village.street.get_child_count())
	check_mask(village, 1)

	# (b) Walk to the bunk and sleep.
	check(not village.bunk_in_range() and not village.prompt_label.visible, "at the start the bunk is out of range and no prompt shows")
	var frames := await walk_walker_to_bunk(village)
	check(frames < WALK_FRAMES and village.bunk_in_range(), "the walker reached the bunk in %d frames, x = %.1f" % [frames, village.walker.position.x])
	await get_tree().process_frame
	check(village.prompt_label.visible and village.prompt_label.text == words.sleep_prompt, "the prompt above the walker says '%s'" % village.prompt_label.text)
	await press_key(KEY_E)
	await settle()
	check(toy.village == null and not is_instance_valid(village), "E at the bunk put the village away")
	var dream: Node2D = toy.dream
	check(dream != null and dream.get_parent() == toy and dream.name == "Dream", "the dream is the active scene")
	check(harness.summary().contains("slept_1"), "the harness recorded the milestone slept_1")
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps, dream.frame_open.size]))
	dream.redeal(["bed"] as Array[String], false)   # SPEC-2: the branch dealer deals no bed room; dealt by hand here, without scraps
	check(dream.current_room_id() == "bed", "the bed room dealt by hand, where the block and bed live (the night itself never deals it)")
	dream.place_scrap(first, Vector2(460, 540))   # the night's two thoughts, placed by hand at hand height
	dream.place_scrap(second, Vector2(640, 540))

	# (c) Lucidity, by the acts table.
	check(dream.lucidity == 0 and dream.effective() == 0, "lucidity starts at 0, effective 0")
	check(is_equal_approx(dream.aperture(), 1.0), "the aperture starts at 1.0 (%.3f)" % dream.aperture())
	check_frame(dream)
	check(dream.scraps_node.get_child_count() == 2 and dream.scraps_in_room() == [first, second] and dream.ideas_in_room().is_empty(), "two thoughts hang in the room, the first '%s'; no idea" % first)
	check(not dream.dreamer.pinched and not dream.dreamer.is_on_floor(), "asleep: not pinched, hovering off the floor at y = %.1f" % dream.dreamer.position.y)
	check(not dream.grab_scrap(), "grab_scrap() does nothing while asleep")
	Input.action_press("pinch")
	await settle()
	check(dream.dreamer.pinched and dream.dreamer.is_on_floor(), "pinched: gravity put the dreamer on the floor, y = %.1f" % dream.dreamer.position.y)
	check(dream.lucidity == 0, "holding pinch is free: lucidity still 0")
	frames = await walk_dreamer_until(dream, func() -> bool: return dream.scrap_in_reach() != null)
	check(frames < WALK_FRAMES, "walked to the first thought in %d frames, x = %.1f" % [frames, dream.dreamer.position.x])
	check(dream.grab_scrap(), "grab_scrap() took the first thought")
	check(dream.lucidity == 1 and dream.effective() == 2, "grab: lucidity 1, effective 1 + 1 carried = 2 (%d, %d); no hand that counts double" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 1.0 - 2.0 / 8.0), "aperture 1 - 2/8 = %.3f" % dream.aperture())
	await settle()
	check_frame(dream)
	check(dream.scraps_carried == [first] and state.scraps_carried == [first], "'%s' is carried, and the state knows" % first)
	check(dream.scraps_node.get_child_count() == 1 and dream.dreamer.hip_count() == 1 and not dream.dreamer.has_node("Hat"), "the thought left the room and one piece sits at the hip (no hat: ideas are never carried)")
	check(harness.summary().contains("grabbed_scrap"), "the harness recorded the milestone grabbed_scrap")
	frames = await walk_dreamer_until(dream, func() -> bool: return dream.scrap_in_reach() != null)
	check(frames < WALK_FRAMES and dream.grab_scrap(), "walked to the second thought in %d frames and grab_scrap() took it" % frames)
	check(dream.lucidity == 2 and dream.effective() == 4, "second grab: lucidity 2, effective 4 (%d, %d)" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 0.5), "aperture 1 - 4/8 = %.3f" % dream.aperture())
	await settle()
	check_frame(dream)
	check(dream.scraps_carried.size() == 2 and dream.dreamer.hip_count() == 2 and dream.scraps_node.get_child_count() == 0, "two thoughts at the hip, none left in the room")
	frames = await walk_dreamer_until(dream, func() -> bool: return dream.block_in_reach())
	var block_x: float = dream.block.position.x
	check(frames < WALK_FRAMES and dream.force(), "walked to the block in %d frames and force() pushed it" % frames)
	check(dream.block.position.x == block_x + dream.PUSH, "the block slid %.0f px right" % dream.PUSH)
	check(dream.lucidity == 3 and dream.effective() == 5, "force: lucidity 3, effective 5 (%d, %d)" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 0.375), "aperture 1 - 5/8 = %.3f" % dream.aperture())
	await settle()
	check_frame(dream)
	check(not dream.force() and dream.lucidity == 3, "a second force() on the same block does nothing: still 3")
	check(wakes.is_empty() and toy.dream == dream, "effective 5 is under the limit of 8: still dreaming")
	dream.fall()
	dream.fall()
	check(dream.lucidity == 5 and dream.effective() == 7 and is_equal_approx(dream.aperture(), 0.125) and not dream.closing, "two falls: lucidity 5, effective 7, aperture 1 - 7/8 = %.3f; still dreaming" % dream.aperture())
	dream.fall()
	check(dream.lucidity == 6 and dream.effective() == 8, "a third fall: lucidity 6, effective 8 (%d, %d)" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 0.0) and dream.closing and wakes.is_empty(), "the aperture is 0: the frame is closing, not yet woken")
	frames = await wait_until(func() -> bool: return not wakes.is_empty(), 180)
	check(frames >= 48 and frames < 180 and wakes.size() == 1 and wakes[0][0] == true and wakes[0][1] == [first, second], "effective 8 >= 8 woke the dreamer suddenly with 2 thoughts carried, %d frames after the fall (the frame shuts first)" % frames)
	check(wakes[0][2] == Vector2.ZERO, "the frame closed to nothing")

	# (d) The keep-one picker.
	check(toy.dream == null and toy.picking, "the controller put the dream away and the picker is up")
	check(panel.say_label.text == words.wake_sudden, "the panel says '%s'" % panel.say_label.text)
	check(panel.choice_box.visible and panel.choice_box.get_child_count() == 2, "two choices are up (%d)" % panel.choice_box.get_child_count())
	check(panel.choice_box.get_child(1).text.ends_with(toy.scrap_name(second)), "the second choice is '%s'" % panel.choice_box.get_child(1).text)
	check(harness.summary().contains("woke_sudden"), "the harness recorded woke_sudden")
	await press_key(KEY_2)
	await settle()
	check(state.scraps == [second], "exactly one thought kept, the second: %s" % str(state.scraps))
	check(state.scraps_carried.is_empty(), "nothing carried after waking")
	check(state.tally == 1 and state.day == 2, "tally 1, day 2 (%d, %d)" % [state.tally, state.day])
	check(harness.summary().contains("keep_scrap  %s" % second) and harness.summary().contains("lost  scrap:%s" % first), "the harness recorded keep_scrap %s and lost scrap:%s" % [second, first])
	village = toy.village
	check(village != null and toy.dream == null and not toy.picking and not panel.choice_box.visible, "the village is back and the picker is gone")
	check(village.day_label.text == str(words.day_label).format({"day": 2}), "the day label reads '%s'" % village.day_label.text)
	check(village.tally_wall.text == words.tally_mark, "the tally wall shows one mark: '%s'" % village.tally_wall.text)
	check(not village.desk_on, "one thought alone: no Desk this morning")
	check_mask(village, 2)

	# (e) Sleep again; grab one thought; the bed wakes gently with everything.
	Input.action_release("pinch")
	frames = await walk_walker_to_bunk(village)
	check(frames < WALK_FRAMES and village.bunk_in_range(), "day 2: back at the bunk in %d frames" % frames)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and toy.village == null and harness.summary().contains("slept_2"), "asleep again: the dream is up and slept_2 recorded")
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps, dream.frame_open.size]))
	dream.redeal(["bed"] as Array[String], false)
	check(dream.current_room_id() == "bed", "night 2 in the bed room as well (dealt by hand)")
	dream.place_scrap(first, Vector2(460, 540))
	Input.action_press("pinch")
	await settle()
	frames = await walk_dreamer_until(dream, func() -> bool: return dream.scrap_in_reach() != null)
	check(frames < WALK_FRAMES and dream.grab_scrap() and dream.scraps_carried == [first], "night 2: grabbed '%s' (lucidity %d, effective %d)" % [first, dream.lucidity, dream.effective()])
	frames = await walk_dreamer_until(dream, func() -> bool: return dream.bed_in_reach())
	check(frames < WALK_FRAMES, "walked to the bed in %d frames, x = %.1f" % [frames, dream.dreamer.position.x])
	await press_key(KEY_E)
	await settle()
	check(wakes.size() == 2 and wakes[1][0] == false and wakes[1][1] == [first], "E on the bed woke the dreamer gently with 1 thought carried")
	check(state.day == 3 and state.tally == 1, "day 3, the tally still 1 (%d, %d)" % [state.day, state.tally])
	check(state.scraps == [second, first], "nothing lost: both thoughts are kept for the Desk: %s" % str(state.scraps))
	check(harness.summary().contains("woke_gentle") and harness.summary().contains("keep_scrap  %s" % first), "the harness recorded woke_gentle and keep_scrap %s" % first)
	check(panel.say_label.text == words.wake_gentle, "the panel says '%s'" % panel.say_label.text)
	village = toy.village
	check(village != null and toy.dream == null, "the village is back on day 3")
	check(village.day_label.text == str(words.day_label).format({"day": 3}) and village.tally_wall.text == words.tally_mark, "day label '%s', one mark on the wall" % village.day_label.text)
	check(not village.desk_on, "two thoughts: still no Desk (three are worth one)")

	# (f) The dark mask: 3 tiles each day while nothing stands.
	check_mask(village, 3)
	Input.action_release("pinch")

	print("--- summary() ---\n%s\n--- end ---" % harness.summary())
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## The dark covers everything beyond 3 lit tiles each side of the street's middle.
func check_mask(village: Node2D, day: int) -> void:
	var lit: float = 3.0 * PinchState.TILE
	var extent: float = village.STREET_WIDTH / 2.0 - lit
	check(village.lit_tiles() == 3 and is_equal_approx(village.mask_extent(), extent), "day %d: 3 tiles lit, the dark covers %.0f px at each end" % [day, village.mask_extent()])
	check(village.mask_left.position.x == 0.0 and is_equal_approx(village.mask_left.size.x, extent), "day %d: the left mask spans 0..%.0f" % [day, village.mask_left.size.x])
	check(is_equal_approx(village.mask_right.position.x, village.STREET_WIDTH / 2.0 + lit) and is_equal_approx(village.mask_right.position.x + village.mask_right.size.x, village.STREET_WIDTH), "day %d: the right mask spans %.0f..%.0f" % [day, village.mask_right.position.x, village.mask_right.position.x + village.mask_right.size.x])


## The four frame rects leave a hole of the shown aperture * screen, centred
## on the dreamer and clamped inside the screen, rounded to whole pixels,
## the side rects reaching FRAME_OVERLAP px into the top and bottom ones.
func check_frame(dream: Node2D) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var expected: Vector2 = (screen * dream.shown_aperture()).round()
	var corner: Vector2 = (dream.dreamer_screen_position() - expected / 2.0).clamp(Vector2.ZERO, screen - expected).round()
	var hole: Rect2 = dream.frame_open
	var top: ColorRect = dream.frame_top
	var left: ColorRect = dream.frame_left
	var ok := hole.size.is_equal_approx(expected) and hole.position.is_equal_approx(corner)
	ok = ok and top.size.is_equal_approx(Vector2(screen.x, hole.position.y)) and left.size.is_equal_approx(Vector2(hole.position.x, hole.size.y + 2.0 * dream.FRAME_OVERLAP))
	check(ok, "the frame leaves %.0f x %.0f of %.0f x %.0f open at %s (shown %.3f, aperture %.3f)" % [hole.size.x, hole.size.y, screen.x, screen.y, hole.position, dream.shown_aperture(), dream.aperture()])


## Frames until the condition holds, or the budget runs out.
func wait_until(cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		await get_tree().physics_frame
		frames += 1
	return frames


func settle() -> void:
	for i in SETTLE:
		await get_tree().physics_frame


## Hold move_right or move_left until the bunk is in range, or the frames run out.
func walk_walker_to_bunk(village: Node2D) -> int:
	var frames := 0
	var target: float = village.BUNK.get_center().x
	while not village.bunk_in_range() and frames < WALK_FRAMES:
		Input.action_press("move_right" if village.walker.position.x < target else "move_left")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_right")
	Input.action_release("move_left")
	await get_tree().physics_frame
	return frames


## Hold move_right until the condition holds, or the frames run out.
func walk_dreamer_until(dream: Node2D, cond: Callable) -> int:
	var frames := 0
	while not cond.call() and frames < WALK_FRAMES:
		Input.action_press("move_right")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_right")
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
