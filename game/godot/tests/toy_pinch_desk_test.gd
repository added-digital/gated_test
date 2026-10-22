extends Node2D
## The Desk of toy 4b, PINCH (SPEC-2, day B), headless. The village
## (village.tscn alone on a prepared state, and pinch.tscn for the whole
## loop) is driven through the input actions and the keys (E, A, D, 1 2 3
## 4 5 through the input system); the Desk, the wall, the plots, the
## things, the lines and the harness are read back. Sections:
## (A) the morning after reaching the pills with two scraps the Desk
## starts: the walker at the table, a 3-slot outline with the shapes from
## branches.json, two cards, the light full and draining; the wake line
## first and the desk's line behind it; 1 picks a card, D moves the hand,
## E fits a matching card (the slot filled, the card gone, action fit); a
## wrong card costs exactly 5 s and stays (action fumble, the walker
## shakes); walking 140 px away ends it with what is fitted: 2 of 3 is a
## weak pill, pill_bonus 1, Bo's developed_weak line; (B) 1 of 3 is
## nothing: pill_bonus 0, only the fitted scrap used, the rest kept; the
## light alone ends it; (C) no idea and three scraps: the blank outline
## from scraps.json takes any shape; three fitted open the branch picker;
## 1 (Jorun) names room a on the wall (row_room_names), milestone
## desk_reveal:jorun; (D) the lantern: five fitted is full: state.lantern,
## every room of every shown branch named, the lantern lit by the Long
## House door (its lamp fading in over 1.5 s), Tove's developed line; 3 of
## 5 is weak: the picker, and only the chosen branch's rooms named; (E) in
## pinch.tscn, the whole loop: Bo's branch reached with three scraps; the
## next morning the Desk; all three fitted: the pill in full, pill_bonus
## 2, milestone desk_full:pills, the desk's line then the idea's own, the
## jar by the bunk, Bo's developed line; the bunk never offers a pill and
## breakfast never starts; the next night's limit is 10 and the gauge's
## top 10; (F) Jorun's building: four fitted (a leftover round from
## before) claims the plot: a scaffold with its crossbars one a second,
## milestone desk_full:sixteen_stairs; the next night his goal room holds
## two scraps where the idea was, the "already" line, no idea to reach;
## the self-pinch comes home; the morning after, Sixteen Stairs stands:
## built:sixteen_stairs, the window fading in, 4 tiles lit, Jorun in
## front of it; a weak building is drawn half the height; (G) the
## self-pinch counts pinched and still in a quiet spot (3 s: woke, no
## wonder) and the spot's wonder needs stillness asleep (3 s: the wonder);
## the dev bar says so. Prints PASS/FAIL per check and quits with 0 only
## if every check passes.

const TOY := preload("res://prototypes/pinch/pinch.tscn")
const VILLAGE := preload("res://prototypes/pinch/village.tscn")
const DREAM := preload("res://prototypes/pinch/dream.tscn")
const DESK_SCRIPT := preload("res://prototypes/pinch/desk.gd")
const VILLAGE_FILE := "res://prototypes/pinch/data/village.json"
const DEVBAR_FILE := "res://prototypes/pinch/data/devbar.json"
const BRANCHES_FILE := "res://prototypes/pinch/data/branches.json"
const SCRAPS_FILE := "res://prototypes/pinch/data/scraps.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const WALK_FRAMES := 1200   # 20 s at 60 Hz: the longest walk on the street is about 850 px
const SETTLE := 20

var failures := 0
var toy: Node = null
var village: Node2D = null
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var wakes: Array = []
var acts: Array = []
var village_acts: Array = []
var village_json: Dictionary
var devbar_json: Dictionary
var branches_json: Dictionary
var scraps_json: Dictionary
var people_json: Dictionary
var ideas_json: Array
var rooms_json: Dictionary


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	village_json = PinchState.load_json(VILLAGE_FILE)
	devbar_json = PinchState.load_json(DEVBAR_FILE)
	branches_json = PinchState.load_json(BRANCHES_FILE)
	scraps_json = PinchState.load_json(SCRAPS_FILE)
	people_json = PinchState.load_json(CHARACTERS_FILE)
	ideas_json = PinchState.load_json(IDEAS_FILE)
	rooms_json = PinchState.load_json(ROOMS_FILE)
	var dw: Dictionary = village_json.desk
	var sw: Dictionary = devbar_json.street
	var sep: String = str(devbar_json.separator)
	var bo: Dictionary = person("bo")
	var tove: Dictionary = person("tove")
	var jorun: Dictionary = person("jorun")
	check(branch("bo").slots == ["square", "long", "round"] and branch("jorun").slots.size() == 4 and branch("tove").slots.size() == 5, "branches.json: Bo's outline square, long, round; Jorun's four slots; Tove's five")
	check(scraps_json.outline.slots == ["any", "any", "any"] and str(scraps_json.outline.name) != "", "scraps.json: the blank outline, three slots of any shape, named '%s'" % scraps_json.outline.name)

	# ---------------------------------------------------------------- (A) the Desk's mechanics, the weak pill
	var morning := PinchState.new()
	morning.day = 2
	morning.set_flag("talked:bo")
	morning.target = "bo"
	morning.reach("bo", "pills")
	morning.scraps.assign(["square", "long"])
	village = await new_village(morning, str(village_json.wake_reached).format({"name": "The Pills"}))
	state = morning
	var desk: Node2D = village.desk
	check(village.desk_on and desk != null and desk.idea == "pills" and desk.outline_name == "The Pills", "the morning after reaching the pills with two scraps: the Desk is on, the pills on it")
	check(is_equal_approx(village.walker.position.x, village.TABLE.get_center().x) and desk.position == village.TABLE.position and not village.table_label.visible, "the walker was put at the table (x %.0f); the desk is drawn there, the table's word hidden" % village.walker.position.x)
	check(desk.slots == ["square", "long", "round"] and desk.filled == ["", "", ""] and desk.slot_nodes().size() == 3 and desk.slot_nodes()[0].get_meta("shape") == "square", "a 3-slot outline with the shapes from branches.json: %s, all empty" % [desk.slots])
	check(desk.cards == ["square", "long"] and desk.card_nodes().size() == 2 and desk.card_nodes()[1].get_meta("shape") == "long" and desk.card_nodes()[0].get_node("Number").text == "1", "two cards beside it, numbered: %s" % [desk.cards])
	check(desk.hand == 0 and desk.card == -1 and desk.picked_shape() == "", "the hand on the first slot, no card picked")
	check(desk.light_node != null and desk.WINDOW.y - desk.light_height() < 0.5 and is_equal_approx(desk.time_left(), 75.0 - desk.time) and desk.BLUE_HOUR == 75.0 and desk.light_label.text == str(dw.light), "the Long House window is full of light: %.0f px of %.0f; the blue hour is 75 s" % [desk.light_height(), desk.WINDOW.y])
	check(village.panel.say_label.text == str(village_json.wake_reached).format({"name": "The Pills"}) and village.lines_waiting() == [str(dw.begin).format({"name": "The Pills"})], "the wake line first; the desk's line waits behind it: '%s'" % village.lines_waiting()[0])
	check(village.devbar_text() == str(sw.desk_pick) and village.prompt_label.text == "", "the dev bar: '%s'; no prompt over the walker" % village.devbar_text())
	check(not ("breakfast_on" in village) and not village_acts.has(["breakfast", "start"]) and village_acts.has(["desk", "start"]), "breakfast never starts: the village has no breakfast; acted desk start")
	var light_before: float = desk.light_height()
	for i in 60:
		await get_tree().process_frame
	check(desk.light_height() < light_before and desk.time > 0.9 and desk.time < 1.3 and is_equal_approx(desk.light_height(), desk.WINDOW.y * (1.0 - desk.time / 75.0)), "a second on, the light has drained with the clock: %.2f px (%.2f s)" % [desk.light_height(), desk.time])
	# 1 picks the square card; E fits it into the square slot.
	await press_key(KEY_1)
	check(desk.card == 0 and desk.picked_shape() == "square" and desk.card_nodes()[0].position.y < desk.card_nodes()[1].position.y, "1: the square card is picked (raised)")
	check(village.devbar_text() == str(sw.desk).format({"card": shape_name("square")}), "the dev bar: '%s'" % village.devbar_text())
	await press_key(KEY_E)
	check(desk.filled == ["square", "", ""] and desk.cards == ["long"] and desk.card == -1 and desk.fits == 1, "E: the square fits the square slot: filled, the card used up: %s left" % [desk.cards])
	check(village_acts.has(["fit", "square"]) and desk.slot_nodes()[0].get_meta("filled") == "square" and desk.card_nodes().size() == 1, "acted fit:square; the slot is drawn filled, one card drawn")
	# D moves the hand; the long card on the round slot fumbles.
	await press_key(KEY_D)
	await press_key(KEY_D)
	check(desk.hand == 2 and desk.slots[2] == "round", "D D: the hand is on the third slot (round)")
	await press_key(KEY_D)
	check(desk.hand == 2, "D again: the hand stays at the outline's end")
	await press_key(KEY_1)
	check(desk.picked_shape() == "long", "1: the long card is picked")
	var time_before: float = desk.time
	var fumbles_before: int = desk.fumbles
	await press_key(KEY_E)
	check(desk.time - time_before >= 5.0 and desk.time - time_before < 5.15 and desk.fumbles == fumbles_before + 1 and desk.filled == ["square", "", ""] and desk.cards == ["long"], "E: a wrong shape: the clock jumped 5 s (%.2f), the slot stays empty, the card stays" % (desk.time - time_before))
	check(village_acts.has(["fumble", "long"]) and desk.shaking() and village.panel.say_label.text == str(dw.fumble), "acted fumble:long; the walker shakes; '%s'" % village.panel.say_label.text)
	var shook := false
	for i in 4:
		await get_tree().process_frame
		shook = shook or not is_equal_approx(village.walker_body.position.x, -14.0)
	check(shook, "the walker's body is drawn aside while it shakes")
	await settle()
	check(not desk.shaking() and is_equal_approx(village.walker_body.position.x, -14.0), "and still again")
	desk.pick_card(0)
	time_before = desk.time
	check(village.fit() == "fumble" and is_equal_approx(desk.time - time_before, 5.0), "(by call: a fumble costs exactly 5.0 s)")
	# A moves the hand back; the long card fits the long slot.
	await press_key(KEY_A)
	check(desk.hand == 1 and desk.slots[1] == "long", "A: the hand on the second slot (long)")
	await press_key(KEY_1)
	await press_key(KEY_E)
	check(desk.filled == ["square", "long", ""] and desk.cards.is_empty() and desk.filled_count() == 2 and not desk.complete(), "E: the long card fits: 2 of 3 filled, no card left")
	check(village.devbar_text() == str(sw.desk_pick), "with no card picked: '%s'" % village.devbar_text())
	# Walking away ends it with what is fitted: a weak pill.
	var frames := await walk_walker_to(village, village.TABLE.get_center().x + village.DESK_RANGE + 20.0)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and not village.desk_on and village.desk == null and village.table_label.visible and village_acts.has(["desk", "walked"]), "walked %.0f px away: the Desk is over (acted desk walked)" % village.DESK_RANGE)
	check(state.pill_bonus == 1 and state.night_limit() == 9 and state.has_flag("developed_weak:pills") and not state.has_flag("developed:pills") and village_acts.has(["desk_weak", "pills"]), "2 of 3: a weak pill: pill_bonus 1, the limit 9 from now on, developed_weak:pills, acted desk_weak:pills")
	check(state.ideas_kept.is_empty() and state.scraps.is_empty() and state.desk_done_day == 2, "the idea is used up; no scrap left; the Desk is done for the day")
	check(village.panel.say_label.text == str(dw.weak).format({"name": "The Pills"}), "'%s'" % village.panel.say_label.text)
	check(village.thing_node("pills") != null and village.thing_node("pills").get_node("Name").text == str(village_json.things.pills), "the jar is by the bunk, labelled '%s'" % village.thing_node("pills").get_node("Name").text)
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and village.panel.say_label.text == line_of(bo, "developed_weak"), "Bo: '%s'" % village.panel.say_label.text)
	await free_village()

	# ---------------------------------------------------------------- (B) 1 of 3 is nothing; the light ends it
	morning = PinchState.new()
	morning.day = 2
	morning.set_flag("talked:bo")
	morning.reach("bo", "pills")
	morning.scraps.assign(["round", "square", "round"])
	village = await new_village(morning)
	state = morning
	desk = village.desk
	check(village.desk_on and desk.cards == ["round", "square", "round"], "(the pills with three scraps, one square)")
	check(desk.pick_card(1) and village.fit() == "fit" and desk.filled == ["square", "", ""], "the square fitted")
	desk.tick(desk.BLUE_HOUR - desk.time - 0.5)
	await get_tree().process_frame
	check(village.desk_on and not desk.light_gone() and desk.light_height() > 0.0, "half a second of light left: still on")
	desk.tick(0.6)
	await get_tree().process_frame
	check(not village.desk_on and village_acts.has(["desk", "light"]) and village_acts.has(["desk_none", "pills"]), "the light went: the Desk is over (acted desk light, desk_none:pills)")
	check(state.pill_bonus == 0 and not state.has_flag("developed_weak:pills") and state.ideas_kept.is_empty() and state.scraps == ["round", "round"], "1 of 3: nothing; the idea gone with the one scrap used, the two rounds kept: %s" % [state.scraps])
	check(village.panel.say_label.text == str(dw.none).format({"name": "The Pills"}) and village.thing_node("pills") == null, "'%s'; no jar" % village.panel.say_label.text)
	await free_village()

	# ---------------------------------------------------------------- (C) scraps alone: the reveal
	morning = PinchState.new()
	morning.day = 3
	morning.set_flag("talked:jorun")
	morning.set_flag("talked:bo")
	morning.scraps.assign(["round", "round", "long"])
	village = await new_village(morning)
	state = morning
	desk = village.desk
	check(village.desk_on and desk.idea == "" and desk.outline_name == str(scraps_json.outline.name) and desk.slots == ["any", "any", "any"], "three scraps and no idea: the blank outline '%s', three slots of any shape" % desk.outline_name)
	check(village.lines_waiting() == [str(dw.begin_blank)] or village.panel.say_label.text == str(dw.begin_blank), "'%s'" % dw.begin_blank)
	check(village.wall.row_room_names("jorun") == ["", ""] and village.wall.row_room_names("bo") == ["", ""], "the wall's room boxes are blank")
	for i in 3:
		await press_key(KEY_1)
		await press_key(KEY_E)
		if i < 2:
			await press_key(KEY_D)
	check(not village.desk_on and village.picking_branch and village.panel.choice_box.visible and village.panel.choice_box.get_child_count() == 2, "three fitted (any shape): the Desk is over and the branch picker is up with Jorun and Bo")
	check(village.panel.say_label.text == str(dw.choose_branch) and village.devbar_text() == str(sw.desk_branch), "'%s'; the dev bar: '%s'" % [village.panel.say_label.text, village.devbar_text()])
	await press_key(KEY_1)
	await get_tree().process_frame
	check(not village.picking_branch and state.revealed.get("jorun", 0) == 1 and state.has_flag("revealed:jorun") and village_acts.has(["desk_reveal", "jorun"]), "1: Jorun's branch grows a room: revealed jorun 1, acted desk_reveal:jorun")
	check(village.wall.row_room_names("jorun") == [room_name("a"), ""] and village.wall.row_room_names("bo") == ["", ""] and village.wall.row_rooms("jorun") == ["a", "c"], "the wall names room a on Jorun's row: %s; Bo's still blank" % [village.wall.row_room_names("jorun")])
	var named_box: ColorRect = village.wall.rows.jorun.get_node("Room1")
	check(named_box.get_meta("known") and named_box.size == village.wall.NAMED_BOX and village.wall.rows.jorun.get_node("Room2").size == village.wall.BOX, "the named box is drawn wide, the blank one small")
	check(village.panel.say_label.text == str(dw.reveal).format({"name": jorun.name}) and state.scraps.is_empty(), "'%s'; the three scraps used" % village.panel.say_label.text)
	await free_village()

	# ---------------------------------------------------------------- (D) the lantern, full and weak
	morning = PinchState.new()
	morning.day = 3
	for who in ["tove", "jorun", "bo"]:
		morning.set_flag("talked:%s" % who)
	morning.reach("tove", "lantern")
	morning.scraps.assign(["long", "round", "square", "long", "round"])
	village = await new_village(morning)
	state = morning
	desk = village.desk
	check(village.desk_on and desk.slots == ["long", "round", "square", "long", "round"] and desk.cards.size() == 5, "the lantern on the desk: five slots, five cards")
	await fit_all(village)
	check(not village.desk_on and state.lantern and state.has_flag("developed:lantern") and village_acts.has(["desk_full", "lantern"]), "five fitted: the lantern in full: state.lantern, acted desk_full:lantern")
	var all_named := true
	for who in ["tove", "jorun", "bo"]:
		var ids: Array = branch(who).rooms
		var texts: Array = village.wall.row_room_names(who)
		for i in ids.size():
			all_named = all_named and texts[i] == room_name(ids[i])
	check(all_named and village.wall.row_room_names("bo") == [room_name("f"), room_name("d")], "every room of every branch is named on the wall: Bo's %s" % [village.wall.row_room_names("bo")])
	var lantern: Node2D = village.thing_node("lantern")
	check(lantern != null and lantern.position.x > village.DOOR_X and lantern.position.x < village.TABLE.position.x and lantern.get_node("Name").text == str(village_json.things.lantern), "a lantern stands just inside the Long House door at x %.0f (the door at %.0f, the table at %.0f), labelled '%s'" % [lantern.position.x, village.DOOR_X, village.TABLE.position.x, lantern.get_node("Name").text])
	check(village.lantern_alpha() < 0.1 and lantern.get_node("Lamp").modulate.a < 0.1, "its lamp is dark the moment it is developed (alpha %.2f)" % village.lantern_alpha())
	for i in 90:
		await get_tree().physics_frame
	check(is_equal_approx(village.lantern_alpha(), 1.0) and is_equal_approx(lantern.get_node("Lamp").modulate.a, 1.0), "90 frames on: lit, alpha 1.0 (the lit-window fade)")
	frames = await walk_walker_to(village, village.people.tove.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and village.panel.say_label.text == line_of(tove, "developed"), "Tove: '%s'" % village.panel.say_label.text)
	await free_village()
	morning = PinchState.new()
	morning.day = 3
	for who in ["tove", "jorun", "bo"]:
		morning.set_flag("talked:%s" % who)
	morning.reach("tove", "lantern")
	morning.scraps.assign(["long", "round", "square"])
	village = await new_village(morning)
	state = morning
	desk = village.desk
	await fit_all(village)
	check(village.desk_on and desk.filled_count() == 3, "(three of five fitted)")
	desk.tick(desk.BLUE_HOUR)
	await get_tree().process_frame
	check(not village.desk_on and village.picking_branch and village.panel.choice_box.get_child_count() == 3, "the light went: 3 of 5 is a weak lantern: the picker over the three branches")
	await press_key(KEY_3)
	await get_tree().process_frame
	check(not village.picking_branch and not state.lantern and state.has_flag("developed_weak:lantern") and state.revealed.get("bo", 0) == 2 and village_acts.has(["desk_weak", "lantern"]), "3: Bo's branch alone is named: revealed bo 2, developed_weak:lantern")
	check(village.wall.row_room_names("bo") == [room_name("f"), room_name("d")] and village.wall.row_room_names("jorun") == ["", ""] and village.wall.row_room_names("tove") == ["", ""] and village.thing_node("lantern") == null, "the wall names Bo's rooms only; no lantern on the street")
	await free_village()

	# ---------------------------------------------------------------- (E) the whole loop: Bo's pills, in full
	await new_toy()
	village = toy.village
	state.set_flag("talked:bo")
	state.target = "bo"
	village.refresh()
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(village_json.sleep_prompt) and village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep)]) and not village_json.has("sleep_prompt_pills"), "at the bunk: '%s', the dev bar '%s': no pill is offered" % [village.prompt_label.text, village.devbar_text()])
	await press_key(KEY_1)
	await get_tree().process_frame
	check(toy.dream == null and state.night_limit() == 8, "1 at the bunk does nothing")
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	hook_dream()
	check(dream != null and dream.rooms_tonight() == ["hub", "f", "d", "goal_bo"], "asleep: Bo's night")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == ["round"], "took the hub's round thought")
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null and dreamer.position.x > 600.0, 600)
	check(frames < 600 and dream.grab_scrap() and dream.scraps_carried == ["round", "square"], "and the square")
	dream.place_scrap("long", dreamer.position + Vector2(0, -48))
	await get_tree().physics_frame
	check(dream.grab_scrap() and dream.scraps_carried == ["round", "square", "long"] and dream.effective() == 6, "(a long one by hand: three at the hip, effective 6)")
	check(dream.jump_to_room("goal_bo") and dream.goal_idea == "pills", "(straight to Bo's room)")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.can_reach(), 600)
	check(frames < 600, "at the idea")
	await press_key(KEY_E)
	await settle()
	check(wakes.size() == 1 and wakes[0][0] == false and wakes[0][1] == ["round", "square", "long"] and state.day == 2 and state.ideas_kept == ["pills"] and state.scraps == ["round", "square", "long"], "E: reached; day 2 with the pills and the three thoughts")
	Input.action_release("pinch")
	village = toy.village
	desk = village.desk
	for i in 3:
		await get_tree().physics_frame
	check(village != null and village.desk_on and desk.idea == "pills" and desk.cards == ["round", "square", "long"] and desk.slots == ["square", "long", "round"], "the morning: the Desk with the pills and the three cards")
	check(toy.panel.say_label.text == str(village_json.wake_reached).format({"name": "The Pills"}), "the wake line: '%s'" % toy.panel.say_label.text)
	await press_key(KEY_2)
	await press_key(KEY_E)
	await press_key(KEY_D)
	await press_key(KEY_2)
	await press_key(KEY_E)
	await press_key(KEY_D)
	await press_key(KEY_1)
	await press_key(KEY_E)
	await get_tree().process_frame
	check(not village.desk_on and village_acts.has(["desk", "filled"]) and village_acts.has(["desk_full", "pills"]), "2 E, D 2 E, D 1 E: every slot filled: the Desk is over (acted desk filled, desk_full:pills)")
	check(state.pill_bonus == 2 and state.night_limit() == 10 and state.has_flag("developed:pills") and state.scraps.is_empty() and state.ideas_kept.is_empty(), "the pill in full: pill_bonus 2, the limit 10 from now on")
	check(toy.harness.summary().contains("  desk_full:pills") and toy.harness.summary().contains("fit  square") and toy.harness.summary().contains("desk  filled"), "the harness recorded the milestone desk_full:pills and the fits")
	var pills_line: String = str(idea_entry("pills").line)
	check(toy.panel.say_label.text == str(dw.full).format({"name": "The Pills"}) and village.lines_waiting() == [pills_line], "'%s'; the idea's own line waits behind it" % toy.panel.say_label.text)
	frames = await wait_until(func() -> bool: return toy.panel.say_label.text == pills_line, 150)
	check(frames >= 80 and frames <= 100, "it followed %d frames (1.5 s) later: '%s'" % [frames, toy.panel.say_label.text])
	check(village.thing_node("pills") != null and village.thing_node("pills").position.x > village.BUNK.position.x and village.thing_node("pills").position.x < village.BUNK.end.x, "the jar is on the bunk")
	frames = await walk_walker_to(village, village.people.bo.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and toy.panel.say_label.text == line_of(bo, "developed") and state.has_flag("said:bo:developed"), "Bo, the morning his thing is developed: '%s'" % toy.panel.say_label.text)
	await press_key(KEY_E)
	check(toy.panel.say_label.text == line_of(bo, "reached"), "E again, his reached line: '%s'" % toy.panel.say_label.text)
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.prompt_label.text == str(village_json.sleep_prompt) and village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep)]), "at the bunk with the pill developed: still '%s', no pill to take" % village.prompt_label.text)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and dream.limit() == 10 and is_equal_approx(dream.gauge_height(), 160.0) and is_equal_approx(dream.gauge_bands.waking.position.y, -160.0), "night 2: the limit 10, the gauge's top 10 (160 px)")
	check(dream.scraps_label.text == str(rooms_json.gauge.scraps).format({"n": 0, "limit": 3}), "the gauge reads '%s'" % dream.scraps_label.text)
	check(toy.harness.summary().contains("sleep\n") or not toy.harness.summary().contains("sleep  pill"), "the harness never noted a pill at the bunk")
	await free_toy()

	# ---------------------------------------------------------------- (F) Jorun's building; the reached branch
	await new_toy()
	village = toy.village
	state.set_flag("talked:jorun")
	state.target = "jorun"
	state.scraps.assign(["round"])   # a leftover from an earlier morning: the fourth card Jorun's outline needs
	village.refresh()
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	hook_dream()
	check(frames < WALK_FRAMES and dream != null and dream.jump_to_room("goal_jorun") and dream.goal_idea == "sixteen_stairs" and dream.ideas_in_room() == ["sixteen_stairs"], "(Jorun's night, straight to his room: the idea lies there)")
	Input.action_press("pinch")
	await settle()
	for shape in ["round", "square", "long"]:
		dream.place_scrap(shape, dreamer.position + Vector2(0, -48))
		await get_tree().physics_frame
		check(dream.grab_scrap(), "(took %s by hand)" % shape)
	frames = await hold_until("move_right", func() -> bool: return dream.can_reach(), 600)
	await press_key(KEY_E)
	await settle()
	check(frames < 600 and state.day == 2 and state.ideas_kept == ["sixteen_stairs"] and state.scraps == ["round", "round", "square", "long"], "reached Sixteen Stairs: day 2 with four scraps, the leftover first")
	Input.action_release("pinch")
	village = toy.village
	desk = village.desk
	for i in 3:
		await get_tree().physics_frame
	check(village.desk_on and desk.slots == ["round", "square", "long", "round"] and desk.cards.size() == 4, "the Desk: Jorun's four slots, four cards")
	await fit_all(village)
	check(not village.desk_on and village_acts.has(["desk_full", "sixteen_stairs"]) and toy.harness.summary().contains("  desk_full:sixteen_stairs"), "four fitted: Sixteen Stairs in full (milestone desk_full:sixteen_stairs)")
	check(state.ideas_claimed.get("sixteen_stairs", "") == "sixteen_stairs" and village.plot_state("sixteen_stairs") == "scaffold" and village.plot_node("sixteen_stairs").get_node("Name").text == str(village_json.markers.scaffold), "the plot shows a scaffold the same morning, labelled '%s'" % village.plot_node("sixteen_stairs").get_node("Name").text)
	check(village.crossbars_shown("sixteen_stairs") == 0 and village.lit_tiles() == 3, "no crossbar yet; 3 tiles lit")
	for i in 62:
		await get_tree().physics_frame
	var one: int = village.crossbars_shown("sixteen_stairs")
	for i in 60:
		await get_tree().physics_frame
	check(one == 1 and village.crossbars_shown("sixteen_stairs") == 2, "a second on, one crossbar; two seconds, two")
	frames = await walk_walker_to(village, village.people.jorun.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and toy.panel.say_label.text == line_of(jorun, "developed"), "Jorun: '%s'" % toy.panel.say_label.text)
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	hook_dream()
	check(frames < WALK_FRAMES and dream != null and state.target == "jorun" and dream.jump_to_room("goal_jorun"), "night 2, Jorun's branch again (reached): his room")
	check(dream.goal_who == "jorun" and dream.goal_idea == "" and dream.ideas_in_room().is_empty() and not dream.can_reach(), "no idea lies there this time")
	check(dream.scraps_in_room() == ["round", "square"] and dream.scraps_node.get_child_count() == 2 and dream.already_text() == str(rooms_json.words.already).format({"name": jorun.name}) and dream.room.has_node("Already"), "two thoughts hang where it was, and the line: '%s'" % dream.already_text())
	check(dream.room.sleeper() != null and state.reached.get("jorun", false) and state.has_flag("reached:jorun"), "Jorun still sleeps there; reached:jorun stays true")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 600)
	check(frames < 600 and dream.grab_scrap() and dream.scraps_carried.size() == 1, "took one of them")
	await settle()
	frames = await wait_until(func() -> bool: return toy.dream == null, 220)
	check(frames < 220 and wakes.size() == 1 and wakes[0][0] == false and state.day == 3 and state.tally == 0 and state.scraps.size() == 1, "held still: the self-pinch; day 3 with the thought, not on the tally")
	Input.action_release("pinch")
	village = toy.village
	for i in 3:
		await get_tree().physics_frame
	check(state.ideas_built.get("sixteen_stairs", "") == "sixteen_stairs" and state.has_flag("built:sixteen_stairs") and toy.harness.summary().contains("  built:sixteen_stairs"), "Sixteen Stairs stands: built:sixteen_stairs")
	check(village.plot_state("sixteen_stairs") == "built" and village.plot_node("sixteen_stairs").get_node("Name").text == "Sixteen Stairs" and village.lit_today == ["sixteen_stairs"], "the plot shows the building, named")
	check(village.window_alpha("sixteen_stairs") < 0.2, "its window is fading in (alpha %.2f)" % village.window_alpha("sixteen_stairs"))
	check(village.lit_tiles() == 4 and is_equal_approx(village.mask_extent(), 1280.0) and is_equal_approx(village.mask_left.size.x, 1280.0), "4 tiles lit: the dark covers %.0f px at each end" % village.mask_extent())
	check(is_equal_approx(village.people.jorun.position.x, village.plot_rect("sixteen_stairs").get_center().x), "Jorun moved out: in front of it at x %.0f" % village.people.jorun.position.x)
	check(village.wall.goal_text("jorun") == "Sixteen Stairs", "the wall keeps the idea's name: '%s'" % village.wall.goal_text("jorun"))
	check(not village.desk_on and state.scraps.size() == 1, "one scrap: no Desk this morning")
	frames = await walk_walker_to(village, village.people.jorun.position.x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and toy.panel.say_label.text == line_of(jorun, "reached"), "Jorun (his developed line said yesterday): '%s'" % toy.panel.say_label.text)
	await press_key(KEY_E)
	check(toy.panel.say_label.text == line_of(jorun, "moved"), "then his moved line: '%s'" % toy.panel.say_label.text)
	await free_toy()
	var weak_state := PinchState.new()
	weak_state.day = 3
	weak_state.claim("sixteen_stairs", "sixteen_stairs", true)
	weak_state.new_day()
	village = await new_village(weak_state)
	var plot_node: Node2D = village.plot_node("sixteen_stairs")
	var body: ColorRect = plot_node.get_child(0)
	check(village.plot_state("sixteen_stairs") == "small_building" and is_equal_approx(body.size.y, village.plot_rect("sixteen_stairs").size.y * 0.5) and is_equal_approx(body.position.y + body.size.y, village.plot_rect("sixteen_stairs").size.y) and plot_node.has_node("Window") and plot_node.get_node("Name").text == "Sixteen Stairs", "developed weak: a small building half the plot's height on the ground, a lit window, named")
	check(village.lit_tiles() == 4 and is_equal_approx(village.people.jorun.position.x, village.plot_rect("sixteen_stairs").get_center().x), "it stands: 4 tiles lit, Jorun in front of it")
	await free_village()

	# ---------------------------------------------------------------- (G) the self-pinch in a quiet spot; the wonder asleep
	await fresh_dream("bo", ["bo"])
	check(dream.jump_to_room("goal_bo"), "(Bo's room, with its quiet spot on the floor)")
	var spot: Area2D = dream.room.get_node("Wonders/Quiet")
	Input.action_press("pinch")
	dreamer.respawn(Vector2(spot.position.x + spot.size.x / 2.0, 572))
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor() and dream.spot_in_reach() == spot and dreamer.is_still(), "standing pinched and still in the spot")
	check(dream.devbar_text().contains(str(devbar_json.dream.self_pinch).format({"s": "%.1f" % (3.0 - dream.hold_seconds())})) and not dream.devbar_text().contains(str(devbar_json.dream.wonder)), "the dev bar counts the hold and offers no wonder: '%s'" % dream.devbar_text())
	frames = await wait_until(func() -> bool: return dream.hold_seconds() >= 2.9 - 0.001, 200)
	check(frames < 200 and not dream.woken and dream.wonders_seen.is_empty() and dream.lucidity == 0, "2.9 s: still asleep, no wonder")
	frames = await wait_until(func() -> bool: return dream.woken, 12)
	check(frames < 12 and dream.self_pinched() and wakes.size() == 1 and wakes[0][0] == false and dream.wonders_seen.is_empty(), "3.0 s: the self-pinch woke the dreamer from inside the spot; no wonder was had")
	Input.action_release("pinch")
	await fresh_dream("bo", ["bo"])
	check(dream.jump_to_room("goal_bo"), "(again)")
	spot = dream.room.get_node("Wonders/Quiet")
	dreamer.respawn(Vector2(spot.position.x + spot.size.x / 2.0, 560))
	await settle()
	check(not dreamer.pinched and dreamer.is_still() and dream.spot_in_reach() == spot and dream.devbar_text() == sep.join([str(devbar_json.dream.asleep), str(devbar_json.dream.wonder)]), "hovering asleep and still in the spot: '%s'" % dream.devbar_text())
	dream.fall()
	check(dream.lucidity == 1, "(a fall by hand: lucidity 1)")
	frames = await wait_until(func() -> bool: return dream.wonders_seen.has(spot.id), 200)
	check(frames >= 150 and frames < 200 and dream.lucidity == 0 and not dream.woken and is_zero_approx(dream.hold_seconds()), "3 s still asleep: the wonder (lucidity 0), %d frames on; no hold counted" % frames)
	await free_dream()

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# --- helpers -------------------------------------------------------------------

func branch(who: String) -> Dictionary:
	for b in branches_json.branches:
		if b.who == who:
			return b
	return {}


func person(who: String) -> Dictionary:
	for c in people_json.characters:
		if c.id == who:
			return c
	return {}


func idea_entry(id: String) -> Dictionary:
	for idea in ideas_json:
		if idea.id == id:
			return idea
	return {}


func room_name(id: String) -> String:
	for entry in rooms_json.rooms:
		if entry.id == id:
			return str(entry.name)
	return id


## The text of one of a character's memory lines, by its id.
func line_of(c: Dictionary, id: String) -> String:
	for line in c.get("lines", []):
		if line.get("id", "") == id:
			return str(line.text)
	return ""


func shape_name(shape: String) -> String:
	for entry in scraps_json.shapes:
		if entry.id == shape:
			return str(entry.name)
	return shape


## Every card into the first slot it fits, through the keys: 1 picks the
## first card that matches the slot under the hand, E fits it, D moves on.
func fit_all(v: Node2D) -> void:
	var d: Node2D = v.desk
	while v.desk_on and d.filled_count() < d.slots.size():
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
		if v.desk_on and d.hand < d.slots.size() - 1:
			await press_key(KEY_D)


## A village alone on `with_state` (its own panel), with a wake line, four frames in.
func new_village(with_state: PinchState, wake_line := "") -> Node2D:
	var v: Node2D = VILLAGE.instantiate()
	v.state = with_state
	v.wake_line = wake_line
	village_acts = []
	v.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))
	add_child(v)
	for i in 4:
		await get_tree().physics_frame
	return v


func free_village() -> void:
	for action in ["move_left", "move_right", "interact"]:
		Input.action_release(action)
	if village != null and is_instance_valid(village) and village.get_parent() == self:
		remove_child(village)
		village.queue_free()
	village = null
	await get_tree().physics_frame


## A new pinch.tscn on day 1, listened to, ten frames in.
func new_toy() -> void:
	toy = TOY.instantiate()
	toy.child_entered_tree.connect(_watch_village)
	add_child(toy)
	state = toy.get_state()
	village_acts = []
	wakes = []
	acts = []
	for i in 10:
		await get_tree().physics_frame


## Every village entering the toy is listened to.
func _watch_village(node: Node) -> void:
	if node.name == "Village":
		node.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))


func free_toy() -> void:
	for action in ["pinch", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	remove_child(toy)
	toy.queue_free()
	toy = null
	dream = null
	village = null
	await get_tree().physics_frame


## Listen to the controller's dream.
func hook_dream() -> void:
	wakes = []
	acts = []
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps.duplicate()]))
	dream.acted.connect(func(kind: String, detail: String) -> void: acts.append([kind, detail]))


## dream.tscn alone on a fresh day-1 state with `target` and the talked-to villagers.
func fresh_dream(target: String, talked: Array) -> void:
	await free_dream()
	state = PinchState.new()
	state.target = target
	for who in talked:
		state.set_flag("talked:%s" % who)
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	dreamer = dream.dreamer
	hook_dream()
	await get_tree().physics_frame


func free_dream() -> void:
	for action in ["pinch", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	if dream != null and is_instance_valid(dream) and dream.get_parent() == self:
		remove_child(dream)
		dream.queue_free()
	dream = null
	await get_tree().physics_frame


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
func walk_walker_to(v: Node2D, x: float, near := 8.0) -> int:
	var frames := 0
	while absf(v.walker.position.x - x) > near and frames < WALK_FRAMES:
		Input.action_press("move_right" if v.walker.position.x < x else "move_left")
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
