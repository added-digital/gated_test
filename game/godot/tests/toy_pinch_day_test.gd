extends Node2D
## Scripted play of the day-4 build of toy 4, PINCH, headless: the day half
## and the sleep gauge. The walker is driven through the input actions and
## the keys (E, 1, 2, H through the input system), the dream through its
## API (jump_to_room, place_idea, grab, fall, lie_down). Sections:
## (6) the gauge on dream.tscn alone: 128 px for a limit of 8, three bands
## labelled from rooms.json, the band and the eased needle at effective 0,
## 3 (deep: up to 0.4 of the limit), 6 (light: up to 0.75) and 8 (waking),
## "ideas n / carry", H hides and shows it, the frame unchanged by it;
## then one run through pinch.tscn, five nights:
## (1) night 1: one idea grabbed, the limit by falls: a sudden waking that
## keeps it (a spoon was put on the table by hand before the night, so two
## ideas are kept); day 2: breakfast at the table with the three faces and
## their want lines from characters.json, 2 puts Sixteen Stairs in the
## hand, E at Bo: his not_mine line, his eyes shut, told_wrong; E at Jorun:
## his claims line, told:sixteen_stairs:jorun, a scaffold on the plot the
## same day; the clock stepped 30 s drops Tove's head (tilted, want line
## faded, cannot claim); walking to the bunk ends breakfast and the spoon
## becomes a lantern on its post; (3) E at Jorun: his tally:1 line, then
## his kept:spoon line, each once, text equal to the json; (2) night 2
## gentle and empty; day 3: Sixteen Stairs stands (built:sixteen_stairs,
## a lit window, the idea's name), lit_tiles 4, the mask one tile narrower
## at each end, Jorun in front of it with his moved line, the lantern
## still there; (4) Tove's request line after the wake line; E held 3 s at
## the stove shed with the walker standing still: has_pills; at the bunk
## the prompt offers a pill, 1 takes it, E sleeps: the dream's limit 10,
## the gauge 160 px tall, effective 8 does not wake; (5) day 4: breakfast
## places Bo's Big Needle with Bo; night 4 (slept_4) has the limit back at
## 8; day 5: the loft stands, Bo's "Hold still." line, carry_limit 3;
## night 5: a third grab allowed, three on the hat; (7) the summary lists
## the milestones. Prints PASS/FAIL per check and quits with 0 only if
## every check passes.

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
	check(dream.ideas_label.text == str(gauge_words.ideas).format({"n": 0, "limit": 2}), "beside it: '%s'" % dream.ideas_label.text)
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

	# ---------------------------------------------------------------- the toy, five nights
	toy = TOY.instantiate()
	add_child(toy)
	panel = toy.panel
	harness = toy.harness
	state = toy.get_state()
	var words: Dictionary = toy.words
	var village: Node2D = toy.village
	for i in 10:
		await get_tree().physics_frame
	check(village != null and not village.breakfast_on and village.panel == panel, "day 1: the village is up, no breakfast (nothing on the table), the controller's panel")
	check(village.people.size() == 3 and village.people.has("tove") and village.people.has("jorun") and village.people.has("bo"), "three people stand on the street")
	check(village.people.jorun.position.x == village.DOOR_X and village.people.bo.position.x == village.plot_rect("bos_loft").get_center().x and village.people.tove.position.x > village.STOVE.end.x, "Jorun by the door (x %.0f), Bo by his plot (x %.0f), Tove by the stove (x %.0f)" % [village.people.jorun.position.x, village.people.bo.position.x, village.people.tove.position.x])
	check(village.people.jorun.get_node("Name").text == str(jorun.name) and not village.people.jorun.get_node("Want").visible, "a name over Jorun's head, the want hidden until a talk")
	state.keep("spoon")   # the fixture: a spoon on the table from an earlier morning, so two ideas are kept after the sudden waking
	village.refresh()
	check(village.table_idea_ids() == ["spoon"] and state.has_flag("kept:spoon"), "(by hand: a spoon on the table, remembered as kept)")

	# (1) Night 1: one idea, then the limit; a sudden waking keeps it.
	var frames := await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < WALK_FRAMES and dream != null and harness.summary().contains("slept_1"), "night 1: asleep")
	hook(dream)
	check(dream.jump_to_room("bed"), "(jumped to the bed room)")
	dream.place_idea("sixteen_stairs", Vector2(300, 588))
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.grab() and dream.carried == ["sixteen_stairs"], "took Sixteen Stairs")
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	check(dream.effective() == 3 and dream.gauge_band() == "deep", "settled: effective 3, deep")
	for i in 5:
		dream.fall()
	check(dream.effective() == 8 and dream.closing, "five falls: the limit; the frame closes")
	frames = await wait_until(func() -> bool: return state.day == 2, 200)
	check(frames < 200 and state.tally == 1 and state.ideas_kept == ["spoon", "sixteen_stairs"] and not toy.picking, "woke suddenly with one idea: kept without a picker; tally 1, day 2, two on the table")
	Input.action_release("pinch")

	# Day 2: breakfast.
	village = await new_village()
	check(village != null and village.breakfast_on and village.breakfast_time < 0.5, "day 2: breakfast began with the morning (clock %.2f s)" % village.breakfast_time)
	check(is_equal_approx(village.walker.position.x, village.TABLE.get_center().x), "the walker was put at the table, x = %.0f" % village.walker.position.x)
	check(village.seats.size() == 3 and village.seats.has("tove") and village.seats.has("jorun") and village.seats.has("bo"), "three faces sit at the table")
	var seat_x: Array = [village.seats.tove.position.x, village.seats.jorun.position.x, village.seats.bo.position.x]
	check(is_equal_approx(seat_x[1], village.TABLE.get_center().x) and is_equal_approx(seat_x[0], seat_x[1] - village.SEAT_GAP) and is_equal_approx(seat_x[2], seat_x[1] + village.SEAT_GAP), "Tove, Jorun, Bo at x %.0f, %.0f, %.0f" % seat_x)
	var want_format: String = str(people_json.want_line)
	check(village.seats.jorun.get_node("Want").visible and village.seats.jorun.get_node("Want").text == want_format.format({"name": jorun.name, "want": jorun.want}), "Jorun's want line over his head: '%s'" % village.seats.jorun.get_node("Want").text)
	check(village.seats.bo.get_node("Want").text == want_format.format({"name": bo.name, "want": bo.want}) and village.seats.tove.get_node("Want").text == want_format.format({"name": tove.name, "want": tove.want}), "Bo's: '%s'; Tove's: '%s'" % [village.seats.bo.get_node("Want").text, village.seats.tove.get_node("Want").text])
	check(village.seat_state.values() == ["awake", "awake", "awake"] and village.seat_eyes_open("bo"), "every face awake, eyes open")
	check(not village.people.jorun.visible and not village.people.bo.visible, "the people are at the table, not on the street")
	check(village.hand_idea() == "spoon" and village.hand.get_child_count() == 1 and village.hand.get_child(0).get_meta("id") == "spoon", "the spoon is in the hand, drawn over the walker's head")
	check(panel.prompt_label.text == str(village_json.breakfast.offer_many).format({"idea": "A Spoon"}), "the hint reads '%s'" % panel.prompt_label.text)
	check(panel.say_label.text == str(words.wake_sudden_one), "the wake line is up: '%s'" % panel.say_label.text)
	await press_key(KEY_2)
	check(village.hand_idea() == "sixteen_stairs" and village.hand.get_child(0).get_meta("id") == "sixteen_stairs" and panel.prompt_label.text.contains("Sixteen Stairs"), "2: Sixteen Stairs in the hand")
	frames = await walk_walker_to(village, seat_x[2])
	check(frames < WALK_FRAMES and village.seat_in_reach() == "bo" and village.breakfast_on, "walked to Bo's seat in %d frames" % frames)
	await press_key(KEY_E)
	check(panel.say_label.text == str(bo.not_mine), "E at Bo: '%s'" % panel.say_label.text)
	check(village.seat_state.bo == "closed" and not village.seat_eyes_open("bo") and village.seats.bo.rotation == 0.0, "Bo's eyes are shut for the rest of breakfast (not dropped)")
	check(state.has_flag("told_wrong") and village_acts.has(["told_wrong", "sixteen_stairs:bo"]) and harness.summary().contains("told_wrong  sixteen_stairs:bo"), "the flag told_wrong is set and the harness recorded the action")
	check(state.ideas_kept == ["spoon", "sixteen_stairs"] and village.hand_idea() == "sixteen_stairs", "nothing changed hands")
	await press_key(KEY_E)
	check(panel.say_label.text == str(village_json.breakfast.asleep).format({"name": bo.name}) and state.ideas_kept.size() == 2, "E at Bo again: '%s'; a shut face cannot claim" % panel.say_label.text)
	frames = await walk_walker_to(village, seat_x[1])
	check(frames < WALK_FRAMES and village.seat_in_reach() == "jorun", "walked to Jorun's seat")
	await press_key(KEY_E)
	var stairs_line: String = str(village.idea_entry("sixteen_stairs").get("line", ""))
	check(panel.say_label.text == str(jorun.claims) and panel.say_label.text.contains("I dreamed that") and village.lines_waiting() == [stairs_line], "E at Jorun, his claim first: '%s'; the idea's own line waits behind it" % panel.say_label.text)
	check(state.ideas_claimed.get("sixteen_stairs", "") == "sixteen_stairs" and state.ideas_kept == ["spoon"] and village.table_idea_ids() == ["spoon"], "Sixteen Stairs is claimed for its plot; the spoon alone on the table")
	check(harness.summary().contains("told:sixteen_stairs:jorun") and village_acts.has(["told", "sixteen_stairs:jorun"]), "the harness recorded the milestone told:sixteen_stairs:jorun")
	check(village.breakfast_on and village.hand_idea() == "spoon" and panel.prompt_label.text == str(village_json.breakfast.offer).format({"idea": "A Spoon"}), "breakfast goes on: the spoon in the hand, '%s'" % panel.prompt_label.text)
	check(village.plot_state("sixteen_stairs") == "scaffold" and village.plot_node("sixteen_stairs").get_node("Name").text == str(village_json.markers.scaffold) and village.plot_node("sixteen_stairs").get_child_count() >= 8, "the plot shows a scaffold the same day, labelled '%s'" % village.plot_node("sixteen_stairs").get_node("Name").text)
	check(village.lit_tiles() == 3 and not state.ideas_built.has("sixteen_stairs"), "nothing stands yet: 3 tiles lit")
	frames = await wait_until(func() -> bool: return panel.say_label.text == stairs_line, 150)
	check(frames >= 80 and frames <= 100 and panel.say_label.text == stairs_line, "the idea's own line followed as a second line %d frames (1.5 s) later: '%s'" % [frames, panel.say_label.text])
	# The clock: one head every 30 s.
	check(village.heads_dropped == 0 and village.drop_order() == ["tove", "bo", "jorun"], "no head has dropped; the order will be Tove, Bo, Jorun")
	village.step_breakfast(30.0)
	check(village.heads_dropped == 1 and village.seat_state.tove == "dropped" and is_equal_approx(village.seats.tove.rotation, village.DROPPED_TILT) and is_equal_approx(village.seats.tove.get_node("Want").modulate.a, village.DROPPED_WANT_ALPHA), "30 s: Tove's head dropped: the capsule tilted, the want line faded")
	check(village.seat_state.jorun == "awake" and village.seats.jorun.rotation == 0.0 and village.breakfast_on, "Jorun is still up; breakfast goes on")
	frames = await walk_walker_to(village, seat_x[0])
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == str(village_json.breakfast.asleep).format({"name": tove.name}) and state.ideas_kept == ["spoon"] and state.small_things.is_empty(), "E at Tove: a dropped head cannot claim")
	# Walking away ends breakfast; the spoon becomes a lantern on its post.
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	check(frames < WALK_FRAMES and not village.breakfast_on and state.breakfast_done_day == 2, "walked to the bunk: breakfast is over")
	check(state.ideas_kept.is_empty() and state.small_things == ["spoon"] and village.table_idea_ids().is_empty(), "the spoon became a small thing; the table is bare")
	check(village.small_thing_ids() == ["spoon"] and village.small_things.get_child(0).get_meta("becomes") == "lantern_post", "it stands on the street as a lantern post")
	check(village.plot_node("lantern_post").get_meta("state") == "small_thing" and village.plot_node("lantern_post").get_node("Name").text == str(village_json.small_things.lantern_post), "the lantern post plot shows it, labelled '%s'" % village.plot_node("lantern_post").get_node("Name").text)
	check(village.seats.is_empty() and village.seats_node.get_child_count() == 0 and village.people.jorun.visible and village.people.bo.visible, "the faces are gone, the people are back on the street")
	check(panel.prompt_label.text == "" and village_acts.has(["breakfast", "skipped"]) and village_acts.has(["small_thing", "spoon"]), "the hint is gone; the harness recorded breakfast skipped and the small thing")
	check(village.lines_waiting().size() == 1 and village.lines_waiting()[0] == str(village_json.breakfast.over), "'%s' waits behind the line showing" % str(village_json.breakfast.over))

	# (3) Talk: Jorun's tally line, then his spoon line.
	frames = await walk_walker_to(village, village.DOOR_X)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.character_in_reach() == "jorun" and village.prompt_label.visible and village.prompt_label.text == str(words.talk_prompt), "at Jorun: the prompt reads '%s'" % village.prompt_label.text)
	var tally_line: String = line_of(jorun, "tally_1")
	check(village.line_for("jorun").id == "tally_1", "the line Jorun would give is tally_1 (tally %d)" % state.tally)
	await press_key(KEY_E)
	check(panel.say_label.text == tally_line and tally_line != "", "E at Jorun: '%s'" % panel.say_label.text)
	check(village.people.jorun.get_node("Want").visible and state.has_flag("talked:jorun") and state.has_flag("said:jorun:tally_1") and harness.summary().contains("talk:jorun"), "his want shows over his head; talked:jorun; the harness recorded talk:jorun")
	await press_key(KEY_E)
	check(panel.say_label.text == line_of(jorun, "spoon"), "E again: the spoon is remembered: '%s'" % panel.say_label.text)
	await press_key(KEY_E)
	check(panel.say_label.text == line_of(jorun, "told_wrong"), "and the wrong face this morning: '%s'" % panel.say_label.text)
	await press_key(KEY_E)
	check(panel.say_label.text == str(jorun.greeting), "then the greeting: '%s'" % panel.say_label.text)

	# (2) Night 2, gentle and empty; day 3: the building stands.
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(words.sleep_prompt), "at the bunk: '%s' (no pills yet)" % village.prompt_label.text)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and harness.summary().contains("slept_2"), "night 2")
	hook(dream)
	await sleep_in_bed(dream)
	check(state.day == 3 and wakes.size() == 1 and wakes[0][0] == false, "woke gently on day 3")
	village = await new_village()
	check(state.ideas_built.get("sixteen_stairs", "") == "sixteen_stairs" and state.ideas_claimed.is_empty() and state.has_flag("built:sixteen_stairs"), "Sixteen Stairs stands: ideas_built has it, the claim is gone, built:sixteen_stairs")
	check(harness.summary().contains("built:sixteen_stairs"), "the harness recorded the milestone built:sixteen_stairs")
	check(village.plot_state("sixteen_stairs") == "built" and village.plot_node("sixteen_stairs").get_node("Window").color == village.WINDOW_LIT and village.plot_node("sixteen_stairs").get_node("Name").text == toy.idea_name("sixteen_stairs"), "the plot shows the building with a lit window, named '%s'" % village.plot_node("sixteen_stairs").get_node("Name").text)
	check(village.lit_tiles() == 4 and is_equal_approx(village.mask_extent(), 1280.0) and is_equal_approx(village.mask_left.size.x, 1280.0) and is_equal_approx(village.mask_right.position.x, 3328.0), "4 tiles lit: the dark covers %.0f px at each end, one tile less than 1536" % village.mask_extent())
	check(is_equal_approx(village.people.jorun.position.x, village.plot_rect("sixteen_stairs").get_center().x) and village.stand_x("jorun") == 1660.0, "Jorun moved out: he stands in front of Sixteen Stairs, x = %.0f" % village.people.jorun.position.x)
	check(village.small_thing_ids() == ["spoon"] and village.plot_node("lantern_post").get_meta("state") == "small_thing", "the lantern is still on the street")
	check(not village.breakfast_on, "no breakfast: nothing on the table")

	# (4) The pills: Tove's request, the stove shed, the bunk.
	check(panel.say_label.text == str(words.wake_gentle) and village.lines_waiting().size() == 1 and village.lines_waiting()[0] == str(tove.request.text), "the wake line first; Tove's request waits behind it")
	check(state.has_flag("asked:pills") and not state.has_pills and harness.summary().contains("request  pills"), "asked:pills is set; no pills yet; the harness recorded the request")
	frames = await wait_until(func() -> bool: return panel.say_label.text == str(tove.request.text), 260)
	check(frames < 260 and frames > 100, "then Tove's line, %d frames on: '%s'" % [frames, panel.say_label.text])
	frames = await walk_walker_to(village, village.plot_rect("sixteen_stairs").get_center().x)
	check(frames < WALK_FRAMES and village.character_in_reach() == "jorun", "walked to Jorun at the stairs")
	await press_key(KEY_E)
	check(panel.say_label.text == line_of(jorun, "moved"), "his moved line: '%s'" % panel.say_label.text)
	frames = await walk_walker_to(village, village.plot_rect("stove_shed").get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.stove_in_range() and village.can_make() and village.prompt_label.text == str(words.make_prompt), "at the stove shed: '%s'" % village.prompt_label.text)
	Input.action_press("interact")
	for i in 2:
		await get_tree().physics_frame
	var stood_at: float = village.walker.position.x
	Input.action_press("move_right")   # pushing right while making: the walker must not move
	for i in 28:
		await get_tree().physics_frame
	check(village.making > 0.4 and village.making < 0.6 and village.walker.frozen and is_equal_approx(village.walker.position.x, stood_at) and village.prompt_label.text == str(words.making) and not state.has_pills, "half a second in: making, the walker standing still at x = %.0f, '%s'" % [village.walker.position.x, village.prompt_label.text])
	frames = await wait_until(func() -> bool: return state.has_pills, 200)
	Input.action_release("interact")
	Input.action_release("move_right")
	await get_tree().process_frame
	check(frames < 200 and frames + 30 >= 178 and state.has_pills and state.has_flag("made:pills") and not village.walker.frozen, "3 s held (%d frames): the pills are in the house" % (frames + 30))
	check(panel.say_label.text == str(words.made) and harness.summary().contains("made  pills"), "'%s'; the harness recorded made pills" % panel.say_label.text)
	frames = await walk_walker_to(village, village.people.tove.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(tove, "pills_made"), "Tove: '%s'" % panel.say_label.text)
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(words.sleep_prompt_pills) and not state.pill_tonight, "at the bunk: '%s'" % village.prompt_label.text)
	await press_key(KEY_1)
	await get_tree().process_frame
	check(state.pill_tonight and panel.say_label.text == str(words.pill_taken) and village.prompt_label.text == str(words.sleep_prompt), "1: a pill for tonight; '%s'; the prompt back to '%s'" % [panel.say_label.text, village.prompt_label.text])
	check(state.night_limit() == 10 and state.lucidity_limit == 8, "tonight's limit 10, the limit itself still 8")
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and harness.summary().contains("slept_3") and harness.summary().contains("sleep  pill"), "night 3, the harness noting the pill")
	hook(dream)
	check(dream.limit() == 10 and is_equal_approx(dream.gauge_height(), 160.0) and is_equal_approx(dream.gauge_bands.waking.position.y, -160.0), "the dream's limit is 10; the gauge's top is 10: 160 px")
	for i in 5:
		dream.fall()
	check(dream.effective() == 5 and is_equal_approx(dream.aperture(), 0.5) and dream.gauge_band() == "light" and not dream.closing, "five falls: effective 5 of 10, aperture 0.5, light")
	check(dream.jump_to_room("bed") and dream.room.exit != null, "(day 3: the bed is dealt early, with an exit; jumped there)")
	dream.place_idea("bos_big_needle", Vector2(300, 588))
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.grab() and dream.effective() == 9 and not dream.closing, "took Bo's Big Needle: effective 9 in hand, under 10")
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	for i in 25:
		await get_tree().physics_frame
	check(dream.effective() == 8 and not dream.closing and dream.gauge_band() == "waking" and is_equal_approx(dream.gauge_fraction(), 0.8), "effective 8 does not wake tonight: waking band, the needle at 0.8")
	await sleep_in_bed(dream)
	check(state.day == 4 and not state.pill_tonight and state.ideas_kept == ["bos_big_needle"] and state.night_limit() == 8, "day 4: the pill worn off (the limit 8 again), the needle on the table")

	# (5) Day 4: Bo claims his needle; night 4; day 5: the loft, the hat.
	village = await new_village()
	check(village.breakfast_on and village.hand_idea() == "bos_big_needle", "breakfast with the needle in the hand")
	frames = await walk_walker_to(village, village.seats.bo.position.x)
	await press_key(KEY_E)
	var needle_line: String = str(village.idea_entry("bos_big_needle").get("line", ""))
	check(frames < WALK_FRAMES and panel.say_label.text == str(bo.claims) and village.lines_waiting().size() >= 1 and village.lines_waiting()[0] == needle_line and state.ideas_claimed.get("bos_loft", "") == "bos_big_needle", "E at Bo, his claim first: '%s'; the idea's own line waits; claimed for his loft" % panel.say_label.text)
	check(not village.breakfast_on and state.breakfast_done_day == 4 and village_acts.has(["breakfast", "told"]) and village.plot_state("bos_loft") == "scaffold", "every idea placed: breakfast over, a scaffold on Bo's plot")
	check(harness.summary().contains("told:bos_big_needle:bo"), "told:bos_big_needle:bo recorded")
	frames = await wait_until(func() -> bool: return panel.say_label.text == needle_line, 150)
	check(frames >= 80 and frames <= 100, "the needle's own line followed %d frames (1.5 s) later: '%s'" % [frames, panel.say_label.text])
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(words.sleep_prompt_pills), "at the bunk the pill is offered again")
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and harness.summary().contains("slept_4") and dream.limit() == 8 and is_equal_approx(dream.gauge_height(), 128.0), "night 4 (slept_4): no pill, the limit back to 8, the gauge 128 px")
	hook(dream)
	check(dream.ideas_pool().size() == 3 and not dream.ideas_pool().has("spoon") and not dream.ideas_pool().has("sixteen_stairs") and not dream.ideas_pool().has("bos_big_needle"), "the pool is the three ideas not kept, claimed, built or small: %s" % [dream.ideas_pool()])
	check(dream.jump_to_room("bed"), "(the bed room)")
	await sleep_in_bed(dream)
	village = await new_village()
	check(state.day == 5 and state.ideas_built.get("bos_loft", "") == "bos_big_needle" and village.plot_state("bos_loft") == "built" and village.lit_tiles() == 5, "day 5: Bo's loft stands; 5 tiles lit")
	check(harness.summary().contains("built:bos_loft") and is_equal_approx(village.people.bo.position.x, village.plot_rect("bos_loft").get_center().x), "built:bos_loft; Bo in front of it")
	check(state.carry_limit == 3 and state.has_flag("asked:hat") and village.lines_waiting().size() == 1 and village.lines_waiting()[0] == str(bo.request.text), "Bo's request: '%s' waits behind the wake line; the carry limit is 3 at once" % str(bo.request.text))
	frames = await wait_until(func() -> bool: return panel.say_label.text == str(bo.request.text), 260)
	check(frames < 260, "Bo's line said %d frames on" % frames)
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and panel.say_label.text == line_of(bo, "moved"), "Bo: '%s'" % panel.say_label.text)
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < WALK_FRAMES and dream != null and harness.summary().contains("slept_5"), "night 5")
	hook(dream)
	check(dream.ideas_label.text == str(gauge_words.ideas).format({"n": 0, "limit": 3}), "the gauge reads '%s'" % dream.ideas_label.text)
	check(dream.jump_to_room("bed"), "(the bed room)")
	var three: Array = dream.ideas_pool()
	for i in 3:
		dream.place_idea(three[i], Vector2(300 + i * 100, 588))
	Input.action_press("pinch")
	await settle()
	for i in 3:
		frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
		check(frames < 300 and dream.grab() and dream.carried.size() == i + 1, "grab %d allowed: carried %d" % [i + 1, dream.carried.size()])
		dream.wonder("w%d_a" % i, "spot")
		dream.wonder("w%d_b" % i, "spot")
	check(dream.carried.size() == 3 and dream.dreamer.hat_count() == 3 and is_equal_approx(dream.dreamer.hat_height(), 72.0) and dream.ideas_label.text == str(gauge_words.ideas).format({"n": 3, "limit": 3}), "three under the taller hat, 72 px high; '%s'" % dream.ideas_label.text)
	check(not dream.closing and dream.effective() < 8, "still asleep (effective %d)" % dream.effective())
	Input.action_release("pinch")

	# (7) The summary.
	var summary: String = harness.summary()
	var listed := true
	for m in ["slept_1", "slept_2", "slept_3", "slept_4", "slept_5", "grabbed", "woke_sudden", "woke_gentle", "kept:sixteen_stairs", "kept:bos_big_needle", "told:sixteen_stairs:jorun", "told:bos_big_needle:bo", "built:sixteen_stairs", "built:bos_loft"]:
		listed = listed and summary.contains("  %s" % m)
	check(listed and state.ideas_built.size() == 2, "the summary lists the milestones, two buildings stand")
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
	dream.woke.connect(func(sudden: bool, carried: Array) -> void: wakes.append([sudden, carried]))


## The village of a new morning, its doings listened to, three frames in.
func new_village() -> Node2D:
	var village: Node2D = toy.village
	village.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))
	for i in 3:
		await get_tree().physics_frame
	return village


## Pinched, walk to the bed room's bed and lie down: a gentle waking.
func sleep_in_bed(dream: Node2D) -> void:
	if dream.current_room_id() != "bed":
		dream.jump_to_room("bed")
	Input.action_press("pinch")
	await settle()
	var frames := await hold_until("move_right", func() -> bool: return dream.bed_in_reach(), 400)
	check(frames < 400 and dream.lie_down(), "walked to the bed in %d frames and lay down" % frames)
	Input.action_release("pinch")
	await settle()


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
