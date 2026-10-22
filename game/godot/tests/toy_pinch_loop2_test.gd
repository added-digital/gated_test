extends Node2D
## The second loop of toy 4, PINCH (SPEC-2, day A), headless. The walker
## and the dreamer are driven through the input actions and the keys (E,
## Q, 1 2 3 through the input system); the wall, the dealer, the scraps,
## the goal rooms, the self-pinch and the wakings are read back. Sections:
## (A) the wall in pinch.tscn: only the hub and "talk to someone first"
## before any talk, a row per talked-to villager after (Jorun, then Bo),
## each a line of room boxes ending in a question mark; the bunk refuses
## sleep without a target with the json line; E at the wall opens the
## picker, 2 picks Bo, the wall says "Tonight: Bo's dream"; (B) the night:
## rooms_tonight() == [hub, f, d, goal_bo]; the hub's two signs name Bo
## (right) and Jorun (left) from rooms.json; six scraps dealt over the hub
## and the branch rooms, none in the goal room, the shapes cycling; a
## scrap is a crisp 24 x 16 box hung 64 px over its spot, named; walking
## into the Jorun exit deals room a, the target becomes jorun, the room's
## label says whose dream, its exit carries the branch; (C) scraps on
## dream.tscn alone: E grabs one for +1 (not +2) to the hip, not the hat;
## carry 3 refuses a fourth; effective = lucidity + scraps carried; Q sets
## one down as a 24 x 16 standable step (+1), re-grabbable; (D) the goal
## room: the villager asleep (a capsule twice the dreamer, named, snoring),
## the idea beside them that cannot be grabbed, one wonder spot, no exit;
## E at the idea while pinched emits reached and woke(false, the scraps)
## at once; (E) in pinch.tscn: reaching ends the night gently with the
## idea in ideas_kept and the scraps in state.scraps, milestones
## reached:bo and woke_gentle, the tally untouched; the next morning the
## wall names Bo's idea and still shows Jorun's question mark, and the
## Desk is on with the idea and the scraps (day B); (F) the self-pinch:
## the frame flickers from 1.0 s into the hold, 2.9 s still does nothing,
## moving at 2.0 s resets the hold, 3.0 s wakes gently with every scrap
## and no idea, milestone self_pinch, not on the tally; (G) forced waking
## with three scraps shows the picker and keeps one; the rest fade over
## the bunk. Day B: woke's second argument is the scraps carried (ideas
## are never carried, so the hat and grab() are gone: the checks that
## read them now read the hip and the absence of a grab); the morning
## after a reach runs the Desk where breakfast ran on day A. Prints
## PASS/FAIL per check and quits with 0 only if every check passes.

const TOY := preload("res://prototypes/pinch/pinch.tscn")
const DREAM := preload("res://prototypes/pinch/dream.tscn")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const VILLAGE_FILE := "res://prototypes/pinch/data/village.json"
const DEVBAR_FILE := "res://prototypes/pinch/data/devbar.json"
const BRANCHES_FILE := "res://prototypes/pinch/data/branches.json"
const SCRAPS_FILE := "res://prototypes/pinch/data/scraps.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const WALK_FRAMES := 1200   # 20 s at 60 Hz: the longest walk on the street is about 850 px
const SETTLE := 20

var failures := 0
var toy: Node = null
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var wakes: Array = []
var reaches: Array = []
var acts: Array = []
var village_acts: Array = []
var rooms_json: Dictionary
var village_json: Dictionary
var devbar_json: Dictionary
var branches_json: Dictionary
var scraps_json: Dictionary
var people_json: Dictionary


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	rooms_json = PinchState.load_json(ROOMS_FILE)
	village_json = PinchState.load_json(VILLAGE_FILE)
	devbar_json = PinchState.load_json(DEVBAR_FILE)
	branches_json = PinchState.load_json(BRANCHES_FILE)
	scraps_json = PinchState.load_json(SCRAPS_FILE)
	people_json = PinchState.load_json(CHARACTERS_FILE)
	var words: Dictionary = rooms_json.words
	var wall_words: Dictionary = village_json.wall
	var dw: Dictionary = devbar_json.dream
	var sw: Dictionary = devbar_json.street
	var sep: String = str(devbar_json.separator)
	var shapes: Array = scraps_json.shapes
	check(branches_json.branches.size() == 3 and shapes.size() == 3 and int(scraps_json.per_night) == 6, "branches.json holds three branches; scraps.json three shapes and 6 per night")
	check(branch("jorun").rooms == ["a", "c"] and branch("bo").rooms == ["f", "d"] and branch("tove").rooms == ["b", "e"], "the branches: Jorun a then c, Bo f then d, Tove b then e")
	check(branch("jorun").idea == "sixteen_stairs" and branch("bo").idea == "pills" and branch("tove").idea == "lantern" and branch("bo").goal == "goal_bo", "their ideas: Sixteen Stairs, the pills, the lantern; Bo's goal room goal_bo")

	# ---------------------------------------------------------------- (A) the wall
	await new_toy()
	var village: Node2D = toy.village
	var wall: Node2D = village.wall
	check(wall != null and wall.hub_shown() and wall.shown_branches().is_empty() and wall.note_text() == str(wall_words.talk_first), "day 1, nobody talked to: the wall shows the hub alone and '%s'" % wall.note_text())
	check(wall.tonight_text() == "" and state.target == "", "no target yet")
	var frames := await walk_walker_to(village, village.DOOR_X)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and state.has_flag("talked:jorun") and wall.shown_branches() == ["jorun"], "E at Jorun: talked:jorun, his branch is on the wall: %s" % [wall.shown_branches()])
	check(wall.row_rooms("jorun") == ["a", "c"] and wall.goal_text("jorun") == str(wall_words.unknown) and wall.note_text() == "", "a line of room boxes a, c ending in '%s'; the note is gone" % wall.goal_text("jorun"))
	frames = await walk_walker_to(village, village.plot_rect("bos_loft").get_center().x)
	await press_key(KEY_E)
	check(frames < WALK_FRAMES and state.has_flag("talked:bo") and wall.shown_branches() == ["jorun", "bo"] and wall.row_rooms("bo") == ["f", "d"], "E at Bo: his branch too, under Jorun's: %s" % [wall.shown_branches()])
	check(not state.has_flag("talked:tove") and not wall.shown_branches().has("tove"), "Tove not talked to: no row for her")
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.bunk_in_range() and not village.sleep_allowed() and village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep_refused)]), "at the bunk with branches but no target: '%s'" % village.devbar_text())
	await press_key(KEY_E)
	await settle()
	check(toy.dream == null and toy.village == village and toy.panel.say_label.text == str(wall_words.choose_first) and village_acts.has(["refused", "no_target"]), "E: sleep refused, '%s'" % toy.panel.say_label.text)
	frames = await walk_walker_to(village, village.WALL_X)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.wall_in_range() and not village.bunk_in_range() and village.character_in_reach() == "" and village.devbar_text() == sep.join([str(sw.walk), str(sw.wall)]) and village.prompt_label.text == str(village_json.wall_prompt), "at the wall: '%s', the prompt '%s'" % [village.devbar_text(), village.prompt_label.text])
	await press_key(KEY_E)
	await get_tree().process_frame
	check(village.picking_target and toy.panel.choice_box.visible and toy.panel.choice_box.get_child_count() == 2 and toy.panel.choice_box.get_child(0).text.ends_with(person("jorun").name) and toy.panel.choice_box.get_child(1).text.ends_with(person("bo").name), "E opens the picker: two choices, Jorun and Bo")
	check(toy.panel.say_label.text == str(wall_words.choose) and village.devbar_text() == str(sw.wall_pick), "'%s'; the dev bar says '%s'" % [toy.panel.say_label.text, village.devbar_text()])
	await press_key(KEY_2)
	await get_tree().process_frame
	check(not village.picking_target and state.target == "bo" and not toy.panel.choice_box.visible, "2: the target is Bo")
	var tonight_line: String = str(wall_words.tonight).format({"name": person("bo").name})
	check(wall.tonight_text() == tonight_line and toy.panel.say_label.text == str(wall_words.chosen).format({"name": person("bo").name}) and village_acts.has(["target", "bo"]), "the wall says '%s'; '%s'" % [wall.tonight_text(), toy.panel.say_label.text])
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.sleep_allowed() and village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep)]), "back at the bunk: '%s'" % village.devbar_text())
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and toy.village == null and toy.harness.summary().contains("slept_1"), "E: asleep")
	dreamer = dream.dreamer

	# ---------------------------------------------------------------- (B) the night: the hub, the signs, the scraps
	check(dream.rooms_tonight() == ["hub", "f", "d", "goal_bo"] and dream.current_room_id() == "hub" and dream.room.id == "hub", "tonight: %s, the hub first" % [dream.rooms_tonight()])
	check(dream.deal_branch("jorun") == ["hub", "a", "c", "goal_jorun"] and dream.deal_branch("tove") == ["hub", "b", "e", "goal_tove"] and dream.deal_branch("") == ["hub"], "deal_branch: Jorun's and Tove's in their fixed order; no target: the hub alone")
	var hub_words: Dictionary = dream.room_words("hub")
	check(dream.room_label.text == str(rooms_json.label).format({"name": hub_words.name}) and dream.hint_text() == str(hub_words.hint), "the hub's label '%s' (nobody's dream) and hint" % dream.room_label.text)
	check(dream.room.exits().size() == 2 and dream.hub_signs() == {"left": "jorun", "right": "bo"}, "two exits: the left leads to Jorun's branch, the right to Bo's: %s" % [dream.hub_signs()])
	var sign_right: String = str(words.sign_right).format({"name": person("bo").name})
	var sign_left: String = str(words.sign_left).format({"name": person("jorun").name})
	check(dream.sign_texts() == {"left": sign_left, "right": sign_right}, "the signs read '%s' and '%s' from rooms.json" % [dream.sign_texts().left, dream.sign_texts().right])
	var left_zone: Area2D = dream.room.get_node("ExitLeft")
	check(left_zone.label != null and left_zone.label.text == sign_left and left_zone.get_meta("branch") == "jorun" and left_zone.position.x < 100.0 and dream.room.get_node("ExitRight").position.x > 1000.0, "the left exit wears its sign at the room's left edge, its branch in its metadata")
	check(dream.devbar_text().contains(str(dw.signs).format({"left": sign_left, "right": sign_right})), "the dev bar lists the signs: '%s'" % dream.devbar_text())
	# The scraps.
	var dealt: Dictionary = dream.tonight_scraps
	check(dream.scraps_dealt() == 6 and dealt.has("hub") and dealt.has("f") and dealt.has("d") and not dealt.has("goal_bo"), "six scraps dealt over the hub, f and d, none in the goal room: %s" % [dealt])
	check(dealt.hub == ["round", "square"] and dealt.f == ["long", "round"] and dealt.d == ["square", "long"], "the shapes cycle round, square, long across them")
	check(dealt == dream.deal_scraps(["hub", "f", "d", "goal_bo"] as Array[String], 6) and dream.deal_scraps(["hub"] as Array[String], 6).hub.size() == 6, "deal_scraps is pure; the hub alone takes all six")
	check(dream.scraps_in_room() == ["round", "square"] and dream.ideas_in_room().is_empty(), "the hub holds its two scraps and no idea (the dealer lays none)")
	var scrap: StaticBody2D = dream.scraps_node.get_child(0)
	var spots: Array = dream.room.idea_spots() + dream.room.scrap_spots()
	check(scrap.is_in_group("scrap") and scrap.is_in_group("crisp") and scrap.collision_layer == 2 and scrap.rect().size == Vector2(24, 16) and scrap.has_node("Mark"), "a scrap is a crisp 24 x 16 StaticBody2D on layer 2 with its shape drawn")
	check(scrap.shape == "round" and scrap.label.text == shape_name("round") and scrap.label.text != "round" and scrap.has_node("Leader"), "named '%s' from scraps.json, on a backing with a leader" % scrap.label.text)
	check(spots.size() == 4 and scrap.position == spots[0] + Vector2(0, -64) and dream.scraps_node.get_child(1).position == spots[1] + Vector2(0, -64), "hung 64 px over the room's first spots (at hand height): %s" % [scrap.position])
	check(dream.room.scrap_spots().size() == 2 and dream.room.idea_spots().size() == 2 and scrap.visible and not dreamer.pinched, "the hub has two ScrapSpots and two IdeaSpots; the scrap is seen asleep")
	# The other sign's exit: Jorun's.
	Input.action_press("pinch")
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor(), "pinched on the hub's floor")
	frames = await hold_until("move_left", func() -> bool: return dream.current_room_id() != "hub", 600)
	check(frames < 600 and dream.current_room_id() == "a" and dream.room.id == "a", "walked into the left exit (Jorun's sign): room a is dealt, in %d frames" % frames)
	check(state.target == "jorun" and dream.rooms_tonight() == ["hub", "a", "c", "goal_jorun"], "the target changed to Jorun for the night: %s" % [dream.rooms_tonight()])
	check(toy.harness.summary().contains("retarget:jorun"), "the harness recorded retarget:jorun")
	var a_words: Dictionary = dream.room_words("a")
	check(dream.room_label.text == str(rooms_json.label_whose).format({"name": a_words.name, "whose": person("jorun").name}) and dream.room_label.text.contains(person("jorun").name), "room a's label says whose dream: '%s'" % dream.room_label.text)
	check(dream.room.exit != null and dream.room.exit.get_meta("branch") == "jorun" and dream.scraps_in_room().size() == 2, "its exit carries the branch; its two scraps are dealt afresh: %s" % [dream.scraps_in_room()])
	Input.action_release("pinch")
	Input.action_release("move_left")
	await free_toy()

	# ---------------------------------------------------------------- (C) scraps, on the dream alone
	await fresh_dream("bo", ["jorun", "bo"])
	check(dream.rooms_tonight() == ["hub", "f", "d", "goal_bo"] and dream.scraps_in_room().size() == 2, "(dream.tscn alone with the target Bo: the hub with two scraps)")
	Input.action_press("pinch")
	await settle()
	var first_scrap: StaticBody2D = dream.scraps_node.get_child(0)
	check(dream.scrap_in_reach() == null and not dream.grab_scrap(), "at the door no scrap is in reach: grab_scrap() refused")
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.scrap_in_reach() == first_scrap and dreamer.is_on_floor(), "walked left under the first scrap: in reach at x = %.0f (the scrap at %s)" % [dreamer.position.x, first_scrap.position])
	var signs_line: String = str(dw.signs).format({"left": sign_left, "right": sign_right})
	check(dream.devbar_text() == sep.join([str(dw.pinched), str(dw.scrap), hold_line(), signs_line]), "the dev bar: '%s'" % dream.devbar_text())
	var first_x: float = first_scrap.position.x
	await press_key(KEY_E)
	check(dream.scraps_carried == ["round"] and dream.lucidity == 1 and dream.effective() == 2, "E took it: +1 (not +2), lucidity 1, effective 1 + 1 carried = 2")
	check(dreamer.hip_count() == 1 and dreamer.hip.get_child(0).size == dreamer.HIP_PIECE and not dreamer.has_node("Hat"), "one piece at the hip; there is no hat (day B)")
	check(state.scraps_carried == ["round"] and acts.has(["grab_scrap", "round"]) and dream.scraps_in_room() == ["square"], "the state knows; acted grab_scrap:round; one scrap left in the room")
	check(dream.devbar_text() == sep.join([str(dw.pinched), str(dw.set_down_scrap), hold_line(), signs_line]), "a scrap carried, on the floor: '%s'" % dream.devbar_text())
	# Carry 3: two more by hand, then a fourth is refused.
	dream.place_scrap("square", dreamer.position + Vector2(0, -48))   # at hand height, clear of the body
	dream.place_scrap("long", dreamer.position + Vector2(0, -48))
	await get_tree().physics_frame
	check(dream.grab_scrap() and dream.grab_scrap() and dream.scraps_carried.size() == 3 and dream.lucidity == 3 and dream.effective() == 6, "two more: carried 3, lucidity 3, effective 3 + 3 = 6")
	dream.place_scrap("round", dreamer.position + Vector2(0, -48))
	await get_tree().physics_frame
	check(dream.scrap_in_reach() != null and not dream.grab_scrap() and dream.scraps_carried.size() == 3 and dream.lucidity == 3 and dreamer.hip_count() == 3, "a fourth in reach: refused, still 3 at the hip")
	check(state.carry_scraps == 3 and not dream.devbar_text().contains(str(dw.scrap)), "carry_scraps is 3; the dev bar no longer offers the grab")
	# Q sets one down as a step.
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > first_x + 120.0, 120)
	await settle()
	var feet_x: float = dreamer.position.x
	check(frames < 120 and dreamer.facing == 1 and dreamer.is_on_floor(), "walked right a little, facing right, at x = %.0f" % feet_x)
	await press_key(KEY_Q)
	await get_tree().physics_frame
	check(dream.scraps_carried == ["round", "square"] and dream.lucidity == 4 and dream.effective() == 6 and dreamer.hip_count() == 2, "Q: the top scrap (long) is set down: +1, lucidity 4, effective 4 + 2 = 6")
	var step: StaticBody2D = dream.scraps_node.get_child(dream.scraps_node.get_child_count() - 1)
	check(step.shape == "long" and step.rect().size == Vector2(24, 16) and is_equal_approx(step.position.x, feet_x + 42.0) and is_equal_approx(step.position.y, 592.0) and step.collision_layer == 2, "a 24 x 16 crisp box lies at the feet in front: %s" % [step.position])
	check(acts.has(["set_down_scrap", "long"]), "acted set_down_scrap:long")
	await press("jump")
	for i in 10:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	check(frames < 60 and absf(dreamer.position.y - 556.0) < 1.0 and absf(dreamer.position.x - step.position.x) < 24.0, "jumped onto it: standing at y = %.1f (16 px up), x = %.1f" % [dreamer.position.y, dreamer.position.x])
	check(dream.wonder("w1", "spot") and dream.wonder("w2", "spot") and dream.lucidity == 2, "(two wonders by hand: lucidity 2)")
	check(dream.scrap_in_reach() == step and dream.grab_scrap() and dream.scraps_carried == ["round", "square", "long"] and dream.lucidity == 3 and dream.effective() == 6, "grabbed it again from on top: +1, carried 3, effective 3 + 3 = 6")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor() and absf(dreamer.position.y - 572.0) < 1.0, 60)
	check(frames < 60, "the step gone, the dreamer dropped to the floor")
	Input.action_release("pinch")

	# ---------------------------------------------------------------- (D) the goal room
	check(dream.jump_to_room("goal_bo") and dream.current_room_id() == "goal_bo" and dream.goal_who == "bo" and dream.goal_idea == "pills", "jumped to Bo's goal room")
	var sleeper: Node2D = dream.room.sleeper()
	check(sleeper != null and sleeper.who == "bo" and sleeper.rect().size == Vector2(112, 56) and sleeper.get_node("Body") is Polygon2D, "Bo sleeps there: a capsule 112 x 56 lying down (the dreamer is 28 x 56)")
	check(sleeper.name_label.text == str(words.asleep).format({"name": person("bo").name}) and sleeper.snore_label.text == str(words.snore) and sleeper.snore_label.text != "", "named '%s', snoring '%s' from rooms.json" % [sleeper.name_label.text, sleeper.snore_label.text])
	check(dream.room_label.text == str(rooms_json.label_whose).format({"name": dream.room_words("goal_bo").name, "whose": person("bo").name}), "the room's label: '%s'" % dream.room_label.text)
	var goal_idea_node: StaticBody2D = dream.ideas_node.get_child(0)
	check(dream.ideas_in_room() == ["pills"] and goal_idea_node.has_meta("goal") and goal_idea_node.position == dream.room.idea_spots()[0] and goal_idea_node.label.text == "The Pills", "the idea lies beside him at %s: '%s'" % [goal_idea_node.position, goal_idea_node.label.text])
	check(goal_idea_node.position.x > sleeper.position.x and goal_idea_node.position.x - sleeper.position.x < 200.0, "beside, not under")
	check(dream.room.exits().is_empty() and dream.room.exit == null and not dream.exit_near() and dream.scraps_in_room().is_empty(), "no exit, no scrap in the goal room")
	var spots_here: Array = get_tree().get_nodes_in_group("wonder")
	check(spots_here.size() == 1 and spots_here[0].kind == "spot" and dream.room.has_node("Wonders/Quiet"), "one wonder spot")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 600)
	check(frames < 600 and dream.idea_in_reach() == goal_idea_node and dreamer.is_on_floor(), "walked to the idea in %d frames" % frames)
	var lucidity_at_idea: int = dream.lucidity
	check(not dream.has_method("grab") and dream.ideas_in_room() == ["pills"] and dream.lucidity == lucidity_at_idea and not dream.grab_scrap(), "there is no grab for an idea (day B): it is reached, never carried; grab_scrap finds nothing")
	check(dream.can_reach() and dream.devbar_text().contains(str(dw.reach)) and not dw.has("grab"), "the dev bar offers the reach: '%s'" % dream.devbar_text())
	await press_key(KEY_E)
	check(reaches == [["bo", "pills"]] and wakes.size() == 1 and wakes[0][0] == false and wakes[0][1] == ["round", "square", "long"], "E: reached(bo, pills), then woke(false, the three scraps) at once")
	check(dream.woken and dream.scraps_carried == ["round", "square", "long"] and acts.has(["reach", "pills"]), "the night is over with the three scraps still at the hip; acted reach:pills")
	Input.action_release("pinch")
	Input.action_release("move_right")
	await free_dream()

	# ---------------------------------------------------------------- (E) reaching in pinch.tscn: the morning after
	await new_toy()
	village = toy.village
	state.set_flag("talked:jorun")
	state.set_flag("talked:bo")
	state.target = "bo"
	village.refresh()
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	check(frames < WALK_FRAMES and dream != null and dream.rooms_tonight() == ["hub", "f", "d", "goal_bo"], "(flags and the target by hand; asleep: Bo's night)")
	hook_dream()
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == ["round"], "took the hub's first scrap")
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null and dreamer.position.x > 600.0, 600)
	check(frames < 600 and dream.grab_scrap() and dream.scraps_carried == ["round", "square"] and dream.lucidity == 2, "and the second: two at the hip, lucidity 2")
	check(dream.jump_to_room("goal_bo"), "(straight to the goal room)")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.can_reach(), 600)
	check(frames < 600, "at the idea")
	await press_key(KEY_E)
	await settle()
	check(wakes.size() == 1 and wakes[0][0] == false and reaches == [["bo", "pills"]] and toy.dream == null and not toy.picking, "E: the night ended gently, no picker")
	check(state.ideas_kept == ["pills"] and state.scraps == ["round", "square"] and state.scraps_carried.is_empty(), "the idea is in ideas_kept and the scraps in state.scraps: %s, %s" % [state.ideas_kept, state.scraps])
	check(state.reached.get("bo", false) and state.has_flag("reached:bo") and state.has_flag("kept:pills") and state.tally == 0 and state.day == 2, "reached:bo; the tally untouched; day 2")
	var summary: String = toy.harness.summary()
	check(summary.contains("  reached:bo") and summary.contains("  woke_gentle") and summary.contains("  kept:pills") and summary.contains("grabbed_scrap") and not summary.contains("woke_sudden"), "milestones reached:bo, woke_gentle, kept:pills, grabbed_scrap")
	village = toy.village
	wall = village.wall
	for i in 3:
		await get_tree().physics_frame
	check(village != null and toy.panel.say_label.text == str(village_json.wake_reached).format({"name": "The Pills"}), "the morning: '%s'" % toy.panel.say_label.text)
	check(wall.shown_branches() == ["jorun", "bo"] and wall.goal_text("bo") == "The Pills" and wall.goal_text("jorun") == str(wall_words.unknown), "the second night's wall names Bo's idea ('%s') and shows Jorun's '%s'" % [wall.goal_text("bo"), wall.goal_text("jorun")])
	check(wall.tonight_text() == tonight_line and state.target == "bo", "the target stays until changed: '%s'" % wall.tonight_text())
	check(village.desk_on and village.desk.idea == "pills" and village.desk.cards == ["round", "square"], "day B: the Desk runs on the idea reached, the two thoughts as its cards")
	Input.action_release("pinch")
	Input.action_release("move_right")
	await free_toy()

	# ---------------------------------------------------------------- (F) the self-pinch
	await fresh_dream("bo", ["jorun", "bo"])
	for i in 2:
		dream.fall()
	check(dream.lucidity == 2 and is_equal_approx(dream.aperture(), 0.75), "(two falls by hand: aperture 0.75, so the flicker has room both ways)")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == ["round"] and dream.lucidity == 3, "(a scrap at the hip)")
	await settle()
	check(is_zero_approx(dream.hold_seconds()) or dream.hold_seconds() < 0.5, "(the hold restarted at the stop: %.2f s)" % dream.hold_seconds())
	check(dreamer.pinched and dreamer.is_on_floor() and dreamer.is_still() and not dream.flickering(), "standing still pinched on the floor; no flicker yet")
	frames = await wait_until(func() -> bool: return dream.hold_seconds() >= 0.9, 120)
	check(frames < 120 and not dream.flickering() and is_zero_approx(dream.flicker()) and is_equal_approx(dream.shown_aperture(), dream.aperture()), "0.9 s into the hold: the frame is steady at %.3f" % dream.shown_aperture())
	check(dream.devbar_text().contains(str(dw.self_pinch).format({"s": "%.1f" % (3.0 - dream.hold_seconds())})), "the dev bar counts: '%s'" % dream.devbar_text())
	frames = await wait_until(func() -> bool: return dream.hold_seconds() >= 1.5, 60)
	var base: float = dream.aperture()
	var lo := 2.0
	var hi := 0.0
	for i in 15:   # one swing at 4 Hz
		await get_tree().physics_frame
		lo = minf(lo, dream.shown_aperture())
		hi = maxf(hi, dream.shown_aperture())
	check(frames < 60 and dream.flickering() and is_equal_approx(base, 0.5) and lo < base - 0.03 and hi > base + 0.03 and lo >= base - 0.05 - 0.001 and hi <= base + 0.05 + 0.001, "from 1.0 s the frame flickers: shown %.3f..%.3f about the aperture %.2f over 15 frames (+-0.05 at 4 Hz)" % [lo, hi, base])
	frames = await wait_until(func() -> bool: return dream.hold_seconds() >= 2.0, 60)
	check(frames < 60 and not dream.woken, "2.0 s: still asleep")
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_right")
	check(dream.hold_seconds() < 0.1 and not dream.flickering() and not dream.woken and dream.scraps_carried == ["round"], "a step at 2.0 s reset the hold (%.2f s): the flicker stopped" % dream.hold_seconds())
	await settle()
	frames = await wait_until(func() -> bool: return dream.hold_seconds() >= 2.9 - 0.001, 200)
	check(frames < 200 and not dream.woken and wakes.is_empty() and dream.hold_seconds() < 2.95, "2.9 s still: nothing yet (%.2f s)" % dream.hold_seconds())
	frames = await wait_until(func() -> bool: return dream.woken, 12)
	check(frames < 12 and wakes.size() == 1 and wakes[0][0] == false and wakes[0][1] == ["round"] and dream.self_pinched(), "3.0 s: woke(false, the scrap), no idea, by the self-pinch (%d frames on)" % frames)
	check(dream.scraps_carried == ["round"] and acts.has(["self_pinch", "3.0"]), "every scrap still carried; acted self_pinch")
	Input.action_release("pinch")
	await free_dream()
	# In pinch.tscn: not on the tally, the milestone, the scraps kept.
	await new_toy()
	village = toy.village
	state.set_flag("talked:bo")
	state.target = "bo"
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	hook_dream()
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap(), "(a scrap)")
	await settle()
	frames = await wait_until(func() -> bool: return toy.dream == null, 200)
	check(frames < 200 and wakes.size() == 1 and wakes[0][0] == false and state.tally == 0 and state.day == 2, "held still: woke by the self-pinch, not on the tally, day 2")
	check(state.scraps == ["round"] and state.ideas_kept.is_empty() and toy.harness.summary().contains("  self_pinch") and toy.harness.summary().contains("  woke_gentle"), "the scrap came home, no idea; milestones self_pinch and woke_gentle")
	for i in 3:
		await get_tree().physics_frame
	check(toy.panel.say_label.text == str(village_json.wake_self), "'%s'" % toy.panel.say_label.text)
	Input.action_release("pinch")
	await free_toy()

	# ---------------------------------------------------------------- (G) forced waking keeps one scrap
	await new_toy()
	village = toy.village
	state.set_flag("talked:bo")
	state.target = "bo"
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	dreamer = dream.dreamer
	hook_dream()
	Input.action_press("pinch")
	await settle()
	dream.place_scrap("long", dreamer.position + Vector2(0, -48))
	await get_tree().physics_frame
	check(dream.grab_scrap() and dream.scraps_carried == ["long"], "(a long thought by hand)")
	frames = await hold_until("move_left", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap(), "(the hub's round one)")
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null and dreamer.position.x > 600.0, 600)
	check(frames < 600 and dream.grab_scrap() and dream.scraps_carried == ["long", "round", "square"] and dream.effective() == 6, "(and the square: three at the hip, effective 6)")
	dream.fall()
	dream.fall()
	check(dream.effective() == 8 and dream.closing and not toy.picking, "two falls: the limit; the frame closes")
	frames = await wait_until(func() -> bool: return toy.picking, 120)
	check(frames < 120 and wakes.size() == 1 and wakes[0][0] == true and toy.panel.choice_box.visible and toy.panel.choice_box.get_child_count() == 3, "woke suddenly: the picker is up with three choices")
	check(toy.panel.choice_box.get_child(0).text.ends_with(shape_name("long")) and toy.panel.choice_box.get_child(1).text.ends_with(shape_name("round")) and toy.panel.choice_box.get_child(2).text.ends_with(shape_name("square")), "named from scraps.json: '%s', '%s', '%s'" % [toy.panel.choice_box.get_child(0).text, toy.panel.choice_box.get_child(1).text, toy.panel.choice_box.get_child(2).text])
	await press_key(KEY_2)
	await settle()
	check(not toy.picking and state.scraps == ["round"] and state.scraps_carried.is_empty() and state.ideas_kept.is_empty(), "2: one scrap kept, the round one: %s" % [state.scraps])
	check(state.tally == 1 and state.day == 2 and toy.harness.summary().contains("  woke_sudden") and toy.harness.summary().contains("lost  scrap:long") and toy.harness.summary().contains("keep_scrap  round"), "tally 1, day 2; the harness recorded the loss and the keep")
	village = toy.village
	check(village != null and village.lost_stack != null and village.lost_stack.get_child_count() == 2 and village.lost_stack.get_child(0).get_node("Name").text == shape_name("long") and village.lost_alpha() > 0.9, "the two lost scraps fade over the bunk, named")
	check(village.tally_wall.text == str(village_json.tally_mark) and village.wall.shown_branches() == ["bo"] and village.wall.goal_text("bo") == str(wall_words.unknown), "one mark on the wall; Bo's goal still a question mark")
	Input.action_release("pinch")
	await free_toy()

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


## The dev bar's self-pinch line as it reads now, the seconds left counting.
func hold_line() -> String:
	return str(devbar_json.dream.self_pinch).format({"s": "%.1f" % (3.0 - dream.hold_seconds())})


func shape_name(shape: String) -> String:
	for entry in scraps_json.shapes:
		if entry.id == shape:
			return str(entry.name)
	return shape


## A new pinch.tscn on day 1, listened to, ten frames in.
func new_toy() -> void:
	toy = TOY.instantiate()
	add_child(toy)
	state = toy.get_state()
	village_acts = []
	wakes = []
	reaches = []
	acts = []
	toy.village.acted.connect(func(kind: String, detail: String) -> void: village_acts.append([kind, detail]))
	for i in 10:
		await get_tree().physics_frame


func free_toy() -> void:
	for action in ["pinch", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	remove_child(toy)
	toy.queue_free()
	toy = null
	dream = null
	await get_tree().physics_frame


## Listen to the controller's dream.
func hook_dream() -> void:
	wakes = []
	reaches = []
	acts = []
	dream.woke.connect(func(sudden: bool, carried: Array) -> void: wakes.append([sudden, carried.duplicate()]))
	dream.reached.connect(func(who: String, idea: String) -> void: reaches.append([who, idea]))
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


## Press an action for one physics frame.
func press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


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
