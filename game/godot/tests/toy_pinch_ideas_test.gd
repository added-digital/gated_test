extends Node2D
## Scripted play of the dream of toy 4b, PINCH, headless: the things
## carried (the first loop's ideas were; day B: the scraps are, and an
## idea is only reached), the frame that follows and eases, the rooms
## solved by hand, the ladder, the early bed, and the controller's
## keep-one. The dreamer is driven through the input actions with frame
## budgets; lucidity, positions and the frame are read back. Sections:
## (A) the dealer lays no idea anywhere (the first loop's idea dealer is
## gone with the hat); an idea placed by hand on a room's IdeaSpot is a
## crisp 48 x 24 body named from ideas.json; (B) a thought: grab at 40 px
## pinched (not asleep, not at 48 px): +1 to the hip (no hand, no
## doubling), the shown aperture eases over 0.35 s, the hip's count, the
## carry of 3 refuses a fourth, Q sets the top thought down as a 24 x 16
## solid step at the feet (+1), standable and re-grabbable (+1), a step
## left in a room is left (acted left); (C) the frame's opening is centred
## on the dreamer when it fits and clamped at the edge otherwise, the
## shown aperture eases over 0.35 s, and at the limit the frame is shut 48
## frames before woke fires; (D) room c solved by a set-down step (a
## thought's, 16 px: one jump from it reaches the top), room d by a pinch
## over the island, room e by the goat and the beam, the ladder room holds
## nothing, the first loop's early bed dealt by hand and walked past; (E)
## pinch.tscn: no picker while the frame is shut, the picker keeps one
## thought, the rest fade over the bunk, the kept one is in state.scraps
## (no table: the Desk takes it when three are there). Every room this
## test drives is dealt by hand (redeal, without the dealer's scraps) with
## its thought placed by hand where the first loop's dealer laid its idea.
## Prints PASS/FAIL per check and quits with 0 only if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const TOY := preload("res://prototypes/pinch/pinch.tscn")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ALL_ROOMS: Array[String] = ["tutorial", "a", "b", "c", "d", "e", "ladder", "bed"]
const SOLVE_FRAMES := 1200   # 20 s at 60 Hz: each room must be solved inside this
const SETTLE := 20

var failures := 0
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var wakes: Array = []
var acts: Array = []   # [kind, detail] per acted signal
var hard_landings := 0
var rooms_json: Dictionary
var ideas_json: Array


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	rooms_json = PinchState.load_json(ROOMS_FILE)
	ideas_json = PinchState.load_json(IDEAS_FILE)
	var screen: Vector2 = get_viewport().get_visible_rect().size

	# ---------------------------------------------------------------- (A) the dealer (no idea is dealt; an idea by hand)
	await fresh(1)
	var order: Array[String] = ["tutorial", "a", "bed"]   # the rooms sections (A) and (B) drive, dealt by hand
	check(dream.ideas_in_room().is_empty() and dream.rooms_tonight() == ["hub"], "the branch dealer lays no idea in any room (a night with no target: the hub alone)")
	dream.redeal(ALL_ROOMS, false)
	var ok: bool = true
	for id in ALL_ROOMS:
		dream.jump_to_room(id)
		ok = ok and dream.ideas_in_room().is_empty() and dream.scraps_in_room().is_empty()
	check(ok and not dream.has_method("deal_ideas") and not dream.has_method("ideas_pool") and not dream.has_method("grab"), "eight rooms dealt by hand: none holds an idea or a thought; the first loop's idea dealer and grab are gone (day B)")
	check(ideas_json.size() == 3, "ideas.json holds the three branch ideas")
	dream.redeal(order, false)
	var first_idea: String = ideas_json[0].id
	var idea: StaticBody2D = dream.place_idea(first_idea, dream.room.idea_spots()[0])
	await get_tree().physics_frame
	var in_room: Array = dream.ideas_in_room()
	check(in_room == [first_idea] and dream.current_room_id() == "tutorial", "an idea placed by hand on the tutorial's spot: %s" % [in_room])
	check(idea is StaticBody2D and idea.is_in_group("idea") and idea.is_in_group("crisp") and idea.collision_layer == 2 and idea.get_meta("id") == idea.id, "the idea is a crisp StaticBody2D on layer 2, in the groups idea and crisp")
	check(idea.label.text == name_of(idea.id) and idea.label.text != "" and idea.label.text != idea.id, "it is labelled '%s' from ideas.json" % idea.label.text)
	check(idea.rect().size == Vector2(48, 24) and dream.room.idea_spots().has(idea.position), "48 x 24 at an IdeaSpot of the room, %s" % [idea.position])
	check(idea.visible and not dreamer.pinched, "seen asleep")
	check(dream.idea_in_reach() == idea and not dream.can_reach(), "in reach at the door, but not the goal's: nothing to reach, nothing to grab")
	dream.jump_to_room("bed")
	check(dream.devbar_text() == str(dream.devbar_words.dream.asleep) and dream.devbar_text().contains("pinch") and dream.hint_text() == str(dream.room_words("bed").hint), "the dev bar reads '%s' and the room's hint '%s'" % [dream.devbar_text(), dream.hint_text()])

	# ---------------------------------------------------------------- (B) grab, the hip, set down
	await fresh(1)
	dream.redeal(order, false)
	var first := "round"
	var scrap_node: StaticBody2D = dream.place_scrap(first, Vector2(60, 556))   # over where the first loop's dealer laid the tutorial's idea, at hand height
	await get_tree().physics_frame
	check(scrap_node.position == Vector2(60, 556), "a thought hangs at (60, 556), behind the door")
	check(dream.scrap_in_reach() == scrap_node and not dream.grab_scrap() and dream.lucidity == 0 and dream.scraps_carried.is_empty(), "asleep at the door the thought is in reach, but grab_scrap() does nothing")
	Input.action_press("pinch")
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor() and is_equal_approx(dreamer.position.y, 572.0), "pinched: on the floor at y = %.1f" % dreamer.position.y)
	dreamer.respawn(Vector2(134, 572))   # the boxes 48 px apart
	await get_tree().physics_frame
	check(dream.scrap_in_reach() == null and not dream.grab_scrap(), "48 px from the thought's box: out of reach, grab_scrap() refused")
	dreamer.respawn(Vector2(126, 572))   # 40 px apart
	await get_tree().physics_frame
	check(dream.scrap_in_reach() == scrap_node, "40 px from the thought's box: in reach")
	var shown_before: float = dream.shown_aperture()
	check(dream.grab_scrap(), "grab_scrap() took it")
	check(dream.lucidity == 1 and dream.scraps_carried == [first] and dream.effective() == 2, "grab: lucidity 1, one carried: effective 2 (%d, %d); no hand that counts double" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 0.75) and is_equal_approx(dream.shown_aperture(), shown_before), "aperture 1 - 2/8 = %.3f; the shown aperture has not moved yet (%.3f)" % [dream.aperture(), dream.shown_aperture()])
	check(dream.scraps_node.get_child_count() == 0 and dream.scraps_in_room().is_empty(), "the thought left the room")
	check(dreamer.hip_count() == 1 and dreamer.hip.get_child(0).size == dreamer.HIP_PIECE and not dreamer.has_node("Hat"), "the hip holds one piece; there is no hat")
	check(acts.back() == ["grab_scrap", first] and state.scraps_carried == [first], "acted grab_scrap:%s, the state knows" % first)
	for i in 10:
		await get_tree().physics_frame
	var shown_10: float = dream.shown_aperture()
	check(shown_10 < 1.0 and shown_10 > 0.75, "10 frames after the grab the shown aperture is between 1.0 and 0.75: %.3f" % shown_10)
	for i in 20:
		await get_tree().physics_frame
	check(is_equal_approx(dream.shown_aperture(), 0.75) and is_equal_approx(dream.shown_aperture(), dream.aperture()), "30 frames after the grab it equals the aperture: %.3f" % dream.shown_aperture())
	for i in 60:
		await get_tree().physics_frame
	check(dream.effective() == 2 and dreamer.hip_count() == 1 and dream.hold_seconds() > 1.0 and not dream.woken, "a second on: still effective 2 (nothing settles: a thought is small); standing still pinched, the self-pinch's hold is counting (%.1f s)" % dream.hold_seconds())
	# The carry: two more thoughts on the far floor (flat, nothing in the way), a fourth refused.
	dreamer.respawn(Vector2(800, 572))
	await settle()
	var second := "square"
	var third := "long"
	dream.place_scrap(second, Vector2(900, 556))
	dream.place_scrap(third, Vector2(960, 556))
	check(dreamer.is_on_floor() and is_equal_approx(dreamer.position.y, 572.0) and dream.scrap_in_reach() == null, "(on the far floor at x = %.0f, the two thoughts ahead)" % dreamer.position.x)
	var frames := await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == [first, second] and dream.lucidity == 2 and dream.effective() == 4, "walked to the second thought and took it: carried 2, lucidity 2, effective 4")
	check(dreamer.hip_count() == 2, "two pieces at the hip")
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == [first, second, third] and dream.lucidity == 3 and dream.effective() == 6, "and the third: carried 3, lucidity 3, effective 6")
	dream.place_scrap("round", Vector2(1020, 556))
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.scrap_in_reach() != null and not dream.grab_scrap() and dream.scraps_carried.size() == 3 and dream.lucidity == 3, "a fourth thought is in reach but the hip holds %d: grab_scrap() refused, lucidity still 3" % state.carry_scraps)
	# Set down, by the Q key, facing left.
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x < 850.0, 120)
	await settle()
	var feet_x: float = dreamer.position.x
	check(dreamer.facing == -1 and dreamer.is_on_floor(), "walked back left to x = %.1f, facing left" % feet_x)
	await press_key(KEY_Q)
	await get_tree().physics_frame
	check(dream.scraps_carried == [first, second] and dream.lucidity == 4 and dream.effective() == 6, "Q: the top thought (%s) left the hip, +1: lucidity 4, effective 6" % third)
	var step: StaticBody2D = dream.scraps_node.get_child(dream.scraps_node.get_child_count() - 1)
	check(step.shape == third and step.rect().size == Vector2(24, 16) and is_equal_approx(step.position.x, feet_x - 42.0) and is_equal_approx(step.position.y, 592.0) and step.collision_layer == 2, "a 24 x 16 solid box lies at the feet in front: %s" % [step.position])
	check(acts.back() == ["set_down_scrap", third] and dreamer.hip_count() == 2, "acted set_down_scrap:%s; two pieces at the hip" % third)
	# Stand on it.
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x <= step.position.x + 12.0 + 14.0 + 0.5, 120)
	check(frames < 120 and dreamer.is_on_floor() and absf(dreamer.position.y - 572.0) < 1.0, "walked up against the step at x = %.1f, still on the floor (y %.2f: the step's side nudges the body a hair)" % [dreamer.position.x, dreamer.position.y])
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 10:
		Input.action_press("move_left")
		await get_tree().physics_frame
	Input.action_release("move_left")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	check(frames < 60 and absf(dreamer.position.y - 556.0) < 1.0 and absf(dreamer.position.x - step.position.x) < 24.0, "jumped onto the step: standing at y = %.1f (16 px up), x = %.1f" % [dreamer.position.y, dreamer.position.x])
	check(dream.lucidity == 4 and hard_landings == 0, "a 16 px step costs nothing")
	# Re-grab it from on top (three wonders first, to stay under the limit).
	check(dream.wonder("w1", "spot") and dream.wonder("w2", "spot") and dream.wonder("w3", "spot") and dream.lucidity == 1, "(three wonders by hand: lucidity 1)")
	check(dream.scrap_in_reach() == step and dream.grab_scrap() and dream.scraps_carried == [first, second, third] and dream.lucidity == 2 and dream.effective() == 5, "re-grabbed the step from on top: +1, lucidity 2, carried 3: effective 5")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor() and absf(dreamer.position.y - 572.0) < 1.0, 60)
	check(frames < 60, "the step gone, the dreamer dropped to the floor")
	# A step left behind is left for the night.
	check(dream.set_down() and dream.scraps_carried == [first, second] and dream.scraps_in_room().has(third) and dream.lucidity == 3, "set %s down again (lucidity 3); it and the fourth lie in the room" % third)
	check(dream.next_room() and dream.current_room_id() == order[1] and dream.scraps_in_room().is_empty(), "left the room: %s is in play, nothing lying in it" % dream.current_room_id())
	check(acts.has(["left", "scrap:%s" % third]) and acts.has(["left", "scrap:round"]) and dream.scraps_carried == [first, second], "%s and the fourth were left behind (acted left); two still at the hip" % third)
	Input.action_release("pinch")

	# ---------------------------------------------------------------- (C) the frame
	await fresh(1)
	check(dream.frame_open == Rect2(Vector2.ZERO, screen) and dream.frame_center() == screen / 2.0, "aperture 1: the opening is the whole screen")
	dreamer.respawn(Vector2(576, 324))   # the room's middle: on the screen's middle
	for i in 4:
		dream.fall()
	check(dream.lucidity == 4 and is_equal_approx(dream.aperture(), 0.5), "(four falls by hand: aperture 0.5)")
	for i in 25:
		await get_tree().physics_frame
	var at: Vector2 = dream.dreamer_screen_position()
	check(dream.frame_open.size.is_equal_approx(screen * 0.5) and dream.frame_center().distance_to(at) <= 2.0, "the opening (%s) is centred on the dreamer's screen position %s: centre %s" % [dream.frame_open.size, at, dream.frame_center()])
	var moved := Vector2(576, 324) + Vector2(-8, 6)
	dreamer.respawn(moved)
	await get_tree().physics_frame
	at = dream.dreamer_screen_position()
	check(dream.frame_center().distance_to(at) <= 2.0 and dream.frame_open.get_center() != screen / 2.0, "the dreamer moved; the opening followed: centre %s, dreamer %s" % [dream.frame_center(), at])
	dreamer.respawn(Vector2(120, 572))   # the door: at the bottom left, the opening cannot centre on it
	await get_tree().physics_frame
	at = dream.dreamer_screen_position()
	var expected_corner: Vector2 = (at - screen * 0.25).clamp(Vector2.ZERO, screen * 0.5)
	check(dream.frame_open.position.is_equal_approx(expected_corner) and Rect2(Vector2.ZERO, screen).encloses(dream.frame_open) and dream.frame_open.position.x == 0.0, "at the door the opening is clamped inside the screen at %s (the dreamer's screen position %s)" % [dream.frame_open.position, at])
	# The ease on a wonder, back up.
	var from: float = dream.shown_aperture()
	dream.wonder("c1", "spot")
	for i in 10:
		await get_tree().physics_frame
	check(dream.shown_aperture() > from and dream.shown_aperture() < dream.aperture(), "a wonder opens the frame: 10 frames on the shown aperture %.3f is between %.3f and %.3f" % [dream.shown_aperture(), from, dream.aperture()])
	# The limit: the frame shuts, stays shut 48 frames, then woke.
	for i in 5:
		dream.fall()
	check(dream.lucidity == 8 and dream.effective() == 8 and dream.closing and wakes.is_empty() and not dream.woken, "lucidity 8 = the limit: closing, not yet woken")
	check(not dream.grab_scrap() and not dream.set_down() and not dream.wonder("c2", "spot") and dream.lucidity == 8, "nothing more counts while the frame closes")
	var shut := 0
	var total := 0
	while wakes.is_empty() and total < 200:
		await get_tree().physics_frame
		total += 1
		if not wakes.is_empty():
			break
		if dream.shown_aperture() == 0.0:
			shut += 1
	check(shut == 48 and total == 69 and wakes.size() == 1 and wakes[0][0] == true, "the frame eased shut and stayed shut %d frames (0.8 s) before woke fired, %d frames after the limit" % [shut, total])
	check(dream.woken and dream.frame_open.size == Vector2.ZERO, "woken, the frame shut")

	# ---------------------------------------------------------------- (D) rooms c, d, e, the ladder, the early bed
	# Room c: the climb, the step (a thought's).
	await fresh(1)
	dream.redeal(["c", "bed"] as Array[String], false)
	var top_shape := "round"
	dream.place_scrap(top_shape, Vector2(1056, 232))   # over the room's IdeaSpot on the top shelf, at hand height
	check(dream.current_room_id() == "c" and dream.scraps_in_room() == [top_shape] and dream.scraps_node.get_child(0).position == dream.room.idea_spots()[0] + Vector2(0, -52), "room c: a thought hangs over the top shelf at (1056, 232)")
	var helper := "square"
	dream.place_scrap(helper, Vector2(200, 556))
	var t0 := Time.get_ticks_msec()
	var frames_c := 0
	Input.action_press("pinch")
	await settle()
	frames_c += SETTLE
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 120)
	frames_c += frames
	check(frames < 120 and dream.grab_scrap() and dream.scraps_carried == [helper], "pinched, walked to the %s thought on the floor and took it" % helper)
	check(dream.lucidity == 1 and dream.effective() == 2, "lucidity 1, effective 2")
	var ledges: Array = [dream.room.get_node("Crisp/Ledge1"), dream.room.get_node("Crisp/Ledge2"), dream.room.get_node("Crisp/Ledge3")]
	for i in 3:
		var ledge: StaticBody2D = ledges[i]
		frames = await climb_until(ledge, func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > ledge.position.x + 20.0 and dreamer.position.y < ledge.position.y, 240)
		frames_c += frames
		check(frames < 240 and absf(dreamer.position.y - (ledge.position.y - 28.0)) < 1.0, "up ledge %d in %d frames, standing at y = %.1f" % [i + 1, frames, dreamer.position.y])
	check(dream.lucidity == 1 and hard_landings == 0, "the climb cost nothing")
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 872.0, 120)
	frames_c += frames
	await settle()
	frames_c += SETTLE
	check(frames < 120 and dreamer.is_on_floor() and dreamer.position.x < 886.0, "at the right end of ledge 3, x = %.1f" % dreamer.position.x)
	var shelf: StaticBody2D = dream.room.get_node("Crisp/Shelf")
	var top_y: float = dreamer.position.y
	await press("jump")
	for i in 60:
		await get_tree().physics_frame
		top_y = minf(top_y, dreamer.position.y)
		if i > 5 and dreamer.is_on_floor():
			break
	frames_c += 62
	check(top_y > shelf.position.y - 28.0 + 8.0 and dreamer.is_on_floor() and absf(dreamer.position.y - 380.0) < 1.0, "a jump alone peaks at y = %.1f: the shelf (standing y %.0f) is out of reach by %.0f px" % [top_y, shelf.position.y - 28.0, top_y - (shelf.position.y - 28.0)])
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x < 846.0, 60)
	frames_c += frames
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 850.0, 60)
	frames_c += frames
	await settle()
	frames_c += SETTLE
	check(dreamer.facing == 1 and dreamer.position.x >= 850.0 and dreamer.position.x < 854.0 and dreamer.is_on_floor(), "back a little, facing right, at x = %.1f" % dreamer.position.x)
	var step_x: float = dreamer.position.x + 42.0
	check(dream.set_down() and dream.scraps_carried.is_empty() and dream.lucidity == 2 and dream.scraps_in_room().has(helper), "set the %s thought down as a step: lucidity 2" % helper)
	var step_c: StaticBody2D = dream.scraps_node.get_child(dream.scraps_node.get_child_count() - 1)
	check(is_equal_approx(step_c.position.x, step_x) and is_equal_approx(step_c.position.y, 400.0), "the step floats past the ledge's end at %s" % [step_c.position])
	await press("jump")
	for i in 10:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	frames_c += 72
	check(frames < 60 and absf(dreamer.position.y - 364.0) < 1.0 and absf(dreamer.position.x - step_x) < 24.0, "on the step at y = %.1f (16 px up), x = %.1f" % [dreamer.position.y, dreamer.position.x])
	await press("jump")
	for i in 8:
		await get_tree().physics_frame
	frames = await hold_until("move_right", func() -> bool: return dreamer.is_on_floor(), 60)
	frames_c += 70
	check(frames < 60 and absf(dreamer.position.y - (shelf.position.y - 28.0)) < 1.0 and dreamer.position.x + 14.0 > shelf.position.x, "from the step onto the shelf: standing at y = %.1f, x = %.1f (the shelf from x %.0f)" % [dreamer.position.y, dreamer.position.x, shelf.position.x])
	check(dream.lucidity == 2 and hard_landings == 0, "the two jumps up cost nothing")
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 120)
	frames_c += frames
	check(frames < 120 and dream.grab_scrap() and dream.scraps_carried == [top_shape] and dream.lucidity == 3 and dream.effective() == 4, "took the %s thought at the top: lucidity 3, effective 4" % top_shape)
	check(acts.has(["set_down_scrap", helper]), "the set-down is on the record")
	frames = await hold_until("move_left", func() -> bool: return not dreamer.is_on_floor(), 120)
	frames_c += frames
	var edge_x: float = dreamer.position.x
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 120)
	frames_c += frames
	check(frames < 120 and hard_landings == 1 and dream.lucidity == 4 and absf(dreamer.position.y - 572.0) < 1.0 and dreamer.position.x > 940.0, "stepped off the shelf's edge at x = %.0f and dropped straight to the floor past the step: one hard fall, lucidity 4" % edge_x)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "c", 300)
	frames_c += frames
	check(frames < 300 and dream.current_room_id() == "bed" and acts.has(["left", "scrap:%s" % helper]) and dream.scraps_carried == [top_shape], "the exit: on to the bed room; the %s stayed behind, the %s at the hip (room %s in %d frames)" % [helper, top_shape, dream.current_room_id(), frames])
	check(frames_c < SOLVE_FRAMES, "room c solved in %d frames (%.1f s of play, %.1f s wall)" % [frames_c, frames_c / 60.0, (Time.get_ticks_msec() - t0) / 1000.0])
	Input.action_release("pinch")

	# Room d: the maze, the lift, the island.
	await fresh(1)
	dream.redeal(["d", "bed"] as Array[String], false)
	var island_shape := "long"
	dream.place_scrap(island_shape, Vector2(900, 196))
	check(dream.current_room_id() == "d" and dream.scraps_in_room() == [island_shape] and dream.scraps_node.get_child(0).position == dream.room.idea_spots()[0] + Vector2(0, -32), "room d: a thought hangs over the island")
	var frames_d := 0
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 310.0, 240)
	frames_d += frames
	check(frames < 240 and not dreamer.pinched and dreamer.carried_by.size() == 1, "drifted into the lift at x = %.1f" % dreamer.position.x)
	frames = await wait_until(func() -> bool: return dreamer.position.x >= 880.0, 480)
	frames_d += frames
	check(frames < 480 and dreamer.position.y < 200.0 and dreamer.position.y > 140.0, "the lift alone carried the body up and across to (%.0f, %.0f), above the island" % [dreamer.position.x, dreamer.position.y])
	check(dream.wonders_seen.has("d_maze") and dream.lucidity == 0, "through the soft maze on the way: its wonder (at 0, stays 0)")
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 30)
	frames_d += frames
	check(frames < 30 and dreamer.position.y <= 212.5 and dreamer.position.x > 820.0 and dreamer.position.x < 1136.0 and hard_landings == 0, "pinched over the island: landed at (%.0f, %.0f), free" % [dreamer.position.x, dreamer.position.y])
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 120)
	frames_d += frames
	check(frames < 120 and dream.grab_scrap() and dream.scraps_carried == [island_shape] and dream.lucidity == 1, "took the %s thought" % island_shape)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "d", 300)
	frames_d += frames
	check(frames < 300 and dream.current_room_id() == "bed", "the island's far end is the exit: on to the bed room")
	check(frames_d < SOLVE_FRAMES, "room d solved in %d frames (%.1f s)" % [frames_d, frames_d / 60.0])
	Input.action_release("pinch")

	# Room e: cold water, the goat, the beam.
	await fresh(1)
	dream.redeal(["e", "bed"] as Array[String], false)
	var beam_shape := "square"
	dream.place_scrap(beam_shape, Vector2(800, 316))
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	var water: Area2D = dream.room.get_node("Hazards/Water")
	check(dream.current_room_id() == "e" and dream.scraps_in_room() == [beam_shape] and dream.scraps_node.get_child(0).position == dream.room.idea_spots()[0] + Vector2(0, -32) and water.is_in_group("hazard") and goat.id == "e_goat", "room e: a thought hangs over the beam over the water")
	var frames_e := 0
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
	frames_e += frames
	frames = await wait_until(func() -> bool: return dreamer.carried_by.has(goat), 480)
	frames_e += frames
	check(frames < 480, "the goat came by in %d frames" % frames)
	frames = await wait_until(func() -> bool: return goat.center().x < 820.0 and goat.center().y < 320.0, 480)
	frames_e += frames
	check(frames < 480 and dreamer.carried_by.has(goat) and dreamer.position.y < 320.0 and dreamer.position.x > 700.0, "carried across the water and up, over the beam at (%.0f, %.0f)" % [dreamer.position.x, dreamer.position.y])
	check(dream.wonders_seen.has("e_goat") and dream.lucidity == 0, "the goat's wonder")
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 30)
	frames_e += frames
	check(frames < 30 and dreamer.position.y <= 332.5 and dreamer.position.x > 700.0 and dreamer.position.x < 900.0 and hard_landings == 0 and dream.blinks == 0, "pinched over the beam: landed on it at (%.0f, %.0f), free" % [dreamer.position.x, dreamer.position.y])
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 120)
	frames_e += frames
	check(frames < 120 and dream.grab_scrap() and dream.scraps_carried == [beam_shape] and dream.lucidity == 1, "took the %s thought" % beam_shape)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "e", 400)
	frames_e += frames
	check(frames < 400 and dream.current_room_id() == "bed" and hard_landings == 1 and dream.lucidity == 2 and dream.blinks == 0, "off the beam's end onto the far floor (a hard fall, lucidity 2), never in the water, and out: the bed room")
	check(frames_e < SOLVE_FRAMES, "room e solved in %d frames (%.1f s)" % [frames_e, frames_e / 60.0])
	Input.action_release("pinch")

	# The ladder: nothing to take, a sign, exit only.
	await fresh(1)
	dream.redeal(["ladder", "bed"] as Array[String], false)
	var sign: Label = dream.room.get_node("Sign/Text")
	check(dream.current_room_id() == "ladder" and dream.ideas_in_room().is_empty() and dream.scraps_in_room().is_empty() and dream.room.idea_spots().is_empty(), "the ladder room holds nothing and no spot for anything")
	check(sign.text == str(rooms_json.words.ladder_sign) and sign.text != "ladder_sign", "the sign reads '%s'" % sign.text)
	check(dream.room.get_node("Crisp/Ladder/Rung1").collision_layer == 2 and dream.room.exit != null, "a crisp ladder, an exit")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "ladder", 400)
	check(frames < 400 and dream.current_room_id() == "bed" and dream.lucidity == 0, "walked under the ladder to the exit: the bed room, lucidity 0")
	Input.action_release("pinch")

	# The bed in the wrong place (the first loop's day-3 trick, dealt by hand: SPEC-2's dealer never deals it).
	await fresh(3)
	var night3: Array[String] = ["a", "b", "bed", "c", "d", "bed"]
	dream.redeal(night3, false)
	check(dream.rooms_tonight() == night3 and night3[2] == "bed" and night3[5] == "bed" and night3.count("bed") == 2, "the bed dealt at position 2 and last, by hand: %s" % [night3])
	check(dream.jump_to_room("bed") and dream.room_index == 2 and dream.room.exit != null and dream.bed != null, "in the early bed room: the bed, and an exit past it")
	Input.action_press("pinch")
	await settle()
	frames = await climb_until(dream.block, func() -> bool: return dream.current_room_id() != "bed", 400)
	check(frames < 400 and dream.room_index == 3 and dream.current_room_id() == night3[3] and wakes.is_empty(), "walked past the bed, over the block, through the exit: the night goes on in %s" % dream.current_room_id())
	check(dream.next_room() and dream.next_room() and dream.room_index == 5 and dream.current_room_id() == "bed" and dream.room.exit == null and not dream.next_room(), "the last room is the bed again, with no exit")
	Input.action_release("pinch")
	Input.action_release("move_right")

	# ---------------------------------------------------------------- (E) the controller
	remove_child(dream)
	dream.queue_free()
	dream = null
	await get_tree().physics_frame
	var toy: Node = TOY.instantiate()
	add_child(toy)
	var panel: CanvasLayer = toy.panel
	var village: Node2D = toy.village
	state = toy.get_state()
	var words: Dictionary = toy.words
	for i in 10:
		await get_tree().physics_frame
	check(village.lost_stack == null and not village.desk_on and state.scraps.is_empty(), "day 1: nothing over the bunk, no Desk, no thought kept")
	frames = await walk_walker_to_bunk(village)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < 400 and dream != null, "asleep")
	dreamer = dream.dreamer
	wakes.clear()
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps]))
	dream.redeal(["bed"] as Array[String])   # SPEC-2: the night deals no bed room; by hand
	check(dream.current_room_id() == "bed" and dream.scraps_in_room().is_empty(), "in the bed room (dealt by hand), which holds nothing (the dealer hangs no thought there)")
	var keep_shape := "round"
	var lose_shape := "long"
	dream.place_scrap(keep_shape, Vector2(300, 556))
	dream.place_scrap(lose_shape, Vector2(420, 556))
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap(), "took the %s thought" % keep_shape)
	frames = await hold_until("move_right", func() -> bool: return dream.scrap_in_reach() != null, 300)
	check(frames < 300 and dream.grab_scrap() and dream.scraps_carried == [keep_shape, lose_shape] and dream.effective() == 4, "took the %s: effective 4" % lose_shape)
	for i in 4:
		dream.fall()
	check(dream.effective() == 8 and dream.closing and not toy.picking, "four falls: the limit; the frame closes, no picker yet")
	for i in 40:
		await get_tree().physics_frame
	check(not toy.picking and not panel.choice_box.visible and toy.dream == dream and wakes.is_empty(), "40 frames on: the frame still shut, the dream still up, no picker")
	frames = await wait_until(func() -> bool: return toy.picking, 60)
	check(frames < 60 and wakes.size() == 1 and wakes[0][1] == [keep_shape, lose_shape] and panel.choice_box.visible and panel.choice_box.get_child_count() == 2 and panel.say_label.text == words.wake_sudden, "then woke with the two thoughts: the picker is up with two choices")
	await press_key(KEY_1)
	await settle()
	check(state.scraps == [keep_shape] and state.scraps_carried.is_empty() and state.day == 2, "kept the %s, day 2" % keep_shape)
	village = toy.village
	check(village != null and not village.desk_on and village.has_node("Street/TableIdeas") == false, "one thought: no Desk; nothing is drawn on the table by day (day B: the Desk draws the cards when it runs)")
	check(village.lost_stack != null and village.lost_stack.get_child_count() == 1 and village.lost_stack.get_child(0).get_meta("id") == "scrap:%s" % lose_shape and village.lost_alpha() > 0.9, "the lost thought floats over the bunk (alpha %.2f)" % village.lost_alpha())
	check(village.lost_stack.position == Vector2.ZERO and village.lost_stack.get_child(0).position.x > village.BUNK.position.x and village.lost_stack.get_child(0).position.y < village.BUNK.position.y - 40.0, "above the bunk")
	check(village.lost_stack.get_child(0).get_node("Name").text == toy.scrap_name(lose_shape), "named '%s' from scraps.json" % village.lost_stack.get_child(0).get_node("Name").text)
	# The fade runs on process delta (village._process), so wait in real
	# seconds the same way, never a frame count: at 120 Hz 180 frames is 1.5 s.
	var waited := await wait_seconds(3.0)
	check(village.lost_stack != null and village.lost_alpha() < 0.6 and village.lost_alpha() > 0.4, "3 s on (%.2f s of process time): half faded (alpha %.2f)" % [waited, village.lost_alpha()])
	waited = await wait_until_seconds(func() -> bool: return village.lost_stack == null, 6.0)
	check(village.lost_stack == null and is_zero_approx(village.lost_alpha()) and waited > 2.5 and waited < 4.0, "6 s on: gone (%.2f s after the half)" % waited)
	check(toy.harness.summary().contains("lost  scrap:%s" % lose_shape) and toy.harness.summary().contains("keep_scrap  %s" % keep_shape), "the harness recorded lost scrap:%s and keep_scrap %s" % [lose_shape, keep_shape])
	Input.action_release("pinch")
	frames = await walk_walker_to_bunk(village)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and state.scraps == [keep_shape] and dream.scraps_carried.is_empty(), "night 2: the %s is kept at home, nothing at the hip" % keep_shape)
	check(dream.ideas_in_room().is_empty() and dream.rooms_tonight() == ["hub"] and dream.scraps_dealt() == 6, "SPEC-2: the dealer laid no idea tonight (nobody talked to: the hub alone, with its six thoughts)")

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## A new dream on `day` with a fresh state; the old one gone.
func fresh(day: int) -> void:
	if dream != null:
		remove_child(dream)
		dream.queue_free()
		await get_tree().physics_frame
	state = PinchState.new()
	state.day = day
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	dreamer = dream.dreamer
	wakes = []
	acts = []
	hard_landings = 0
	dream.woke.connect(func(sudden: bool, scraps: Array) -> void: wakes.append([sudden, scraps]))
	dream.acted.connect(func(kind: String, detail: String) -> void: acts.append([kind, detail]))
	dreamer.hard_landing.connect(func() -> void: hard_landings += 1)
	await get_tree().physics_frame


func name_of(id: String) -> String:
	for idea in ideas_json:
		if idea.id == id:
			return idea.name
	return ""


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


## Real seconds, accumulated from process delta (as the village's clocks
## are), so the wait is the same at any refresh rate. Returns the seconds waited.
func wait_seconds(seconds: float) -> float:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited


## Real seconds until the condition holds or the timeout passes (toy_help_test's wait_until).
func wait_until_seconds(cond: Callable, timeout: float) -> float:
	var waited := 0.0
	while not cond.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited


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


## Walk right and jump when a ledge's left edge is within 100 px and the body is still below its top.
func climb_until(ledge: StaticBody2D, cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		Input.action_press("move_right")
		var ahead: float = ledge.position.x - (dreamer.position.x + 14.0)
		if dreamer.is_on_floor() and ahead < 100.0 and dreamer.position.y > ledge.position.y and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_right")
	Input.action_release("jump")
	await get_tree().physics_frame
	return frames


## Press an action for one physics frame.
func press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


## Hold move_right or move_left until the bunk is in range, or 400 frames.
func walk_walker_to_bunk(village: Node2D) -> int:
	var frames := 0
	var target: float = village.BUNK.get_center().x
	while not village.bunk_in_range() and frames < 400:
		Input.action_press("move_right" if village.walker.position.x < target else "move_left")
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
