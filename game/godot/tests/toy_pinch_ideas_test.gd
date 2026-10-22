extends Node2D
## Scripted play of the day-3 dream of toy 4, PINCH, headless: the ideas,
## the frame that follows and eases, the three new rooms, the ladder, the
## early bed, and the controller's keep-one. The dreamer is driven through
## the input actions with frame budgets; lucidity, positions and the frame
## are read back. Sections: (A) the dealer lays one idea per dealt room on
## one of its IdeaSpots, named from ideas.json, none in the bed room or the
## ladder, every idea at most once; (B) grab at 40 px pinched (not asleep,
## not at 48 px): +2, in hand 2 s (counted double) then settled, the hat
## stack's count and height, wobble asleep and still pinched, the carry
## limit refuses a third, Q sets the top idea down as a 48 x 24 solid step
## at the feet (+1), standable and re-grabbable (+2), a step left in a room
## is lost and back in the pool; (C) the frame's opening is centred on the
## dreamer when it fits and clamped at the edge otherwise, the shown
## aperture eases over 0.35 s, and at the limit the frame is shut 48 frames
## before woke fires; (D) room c solved by a set-down step, room d by a
## pinch over the island, room e by the goat and the beam, the ladder room
## holds no idea, on day 3 the bed is dealt at position 2 and walking past
## it goes on; (E) pinch.tscn: no picker while the frame is shut, the
## picker keeps one, the rest fade over the bunk and are dealt again, the
## kept one lies on the table by day. SPEC-2 (day A): the branch dealer
## lays no ideas in rooms any more (scraps instead) and deals no bed room,
## so (A) now checks that nothing is dealt and that an idea placed by hand
## is what it was, and every room this test drives is dealt by hand
## (redeal, without scraps) with its idea placed where the dealer used to
## lay it; the early bed of day 3 was the deck's and is dealt by hand too.
## Prints PASS/FAIL per check and quits with 0 only if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const TOY := preload("res://prototypes/pinch/pinch.tscn")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const IDEAS_FILE := "res://prototypes/pinch/data/ideas.json"
const ALL_ROOMS: Array[String] = ["tutorial", "a", "b", "c", "d", "e", "ladder", "bed"]
const IDEA_ROOMS: Array[String] = ["tutorial", "a", "b", "c", "d", "e"]
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

	# ---------------------------------------------------------------- (A) the dealer (SPEC-2: no idea is dealt any more)
	await fresh(1)
	var order: Array[String] = ["tutorial", "a", "bed"]   # the rooms sections (A) and (B) drive, dealt by hand
	check(dream.tonight_ideas.is_empty() and dream.ideas_in_room().is_empty(), "the branch dealer lays no idea in any room: tonight_ideas is empty (scraps take their place)")
	dream.redeal(ALL_ROOMS, false)
	var ok: bool = dream.tonight_ideas.is_empty()
	for id in ALL_ROOMS:
		dream.jump_to_room(id)
		ok = ok and dream.ideas_in_room().is_empty()
	check(ok, "eight rooms dealt by hand: none holds an idea")
	var pool: Array = dream.ideas_pool()
	check(pool.size() == 8 and dream.deal_ideas(1, ALL_ROOMS).size() == 6 and dream.deal_ideas(1, ALL_ROOMS) == dream.deal_ideas(1, ALL_ROOMS) and dream.deal_ideas(2, ALL_ROOMS) != dream.deal_ideas(1, ALL_ROOMS), "the first loop's deal_ideas is kept, pure and seeded by the day, over the pool of 8; the night does not call it")
	dream.redeal(order, false)
	var idea: StaticBody2D = dream.place_idea(pool[0], dream.room.idea_spots()[0])
	await get_tree().physics_frame
	var in_room: Array = dream.ideas_in_room()
	check(in_room == [pool[0]] and dream.current_room_id() == "tutorial", "an idea placed by hand on the tutorial's spot: %s" % [in_room])
	check(idea is StaticBody2D and idea.is_in_group("idea") and idea.is_in_group("crisp") and idea.collision_layer == 2 and idea.get_meta("id") == idea.id, "the idea is a crisp StaticBody2D on layer 2, in the groups idea and crisp")
	check(idea.label.text == name_of(idea.id) and idea.label.text != "" and idea.label.text != idea.id, "it is labelled '%s' from ideas.json" % idea.label.text)
	check(idea.rect().size == Vector2(48, 24) and dream.room.idea_spots().has(idea.position), "48 x 24 at an IdeaSpot of the room, %s" % [idea.position])
	check(idea.visible and not dreamer.pinched, "seen asleep")
	dream.jump_to_room("bed")
	check(dream.devbar_text() == str(dream.devbar_words.dream.asleep) and dream.devbar_text().contains("pinch") and dream.hint_text() == str(dream.room_words("bed").hint), "the dev bar reads '%s' and the room's hint '%s' (the readability pass: the fixed controls line is gone)" % [dream.devbar_text(), dream.hint_text()])

	# ---------------------------------------------------------------- (B) grab, hand, hat, set down
	await fresh(1)
	dream.redeal(order, false)
	var first: String = pool[0]
	var idea_node: StaticBody2D = dream.place_idea(first, Vector2(60, 588))   # where the first loop's dealer laid the tutorial's idea
	await get_tree().physics_frame
	check(idea_node.position == Vector2(60, 588), "the tutorial's idea lies at (60, 588), behind the door")
	check(dream.idea_in_reach() == idea_node and not dream.grab() and dream.lucidity == 0 and dream.carried.is_empty(), "asleep at the door the idea is in reach, but grab() does nothing")
	Input.action_press("pinch")
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor() and is_equal_approx(dreamer.position.y, 572.0), "pinched: on the floor at y = %.1f" % dreamer.position.y)
	dreamer.respawn(Vector2(146, 572))   # the boxes 48 px apart
	await get_tree().physics_frame
	check(dream.idea_in_reach() == null and not dream.grab(), "48 px from the idea's box: out of reach, grab() refused")
	dreamer.respawn(Vector2(138, 572))   # 40 px apart
	await get_tree().physics_frame
	check(dream.idea_in_reach() == idea_node, "40 px from the idea's box: in reach")
	var shown_before: float = dream.shown_aperture()
	check(dream.grab(), "grab() took it")
	check(dream.lucidity == 2 and dream.carried == [first] and dream.in_hand() and dream.effective() == 4, "grab: lucidity 2, one carried, in hand: effective 4 (%d, %d)" % [dream.lucidity, dream.effective()])
	check(is_equal_approx(dream.aperture(), 0.5) and is_equal_approx(dream.shown_aperture(), shown_before), "aperture 1 - 4/8 = %.3f; the shown aperture has not moved yet (%.3f)" % [dream.aperture(), dream.shown_aperture()])
	check(dream.ideas_node.get_child_count() == 0 and dream.ideas_in_room().is_empty(), "the idea left the room")
	check(dreamer.hat_count() == 1 and is_equal_approx(dreamer.hat_height(), 24.0) and is_equal_approx(dreamer.hat_top_offset(), dreamer.HAND_OFFSET), "the hat holds one piece, 24 px high, offset %.0f px to the side: in hand" % dreamer.hat_top_offset())
	check(acts.back() == ["grab", first] and state.ideas_carried == [first], "acted grab:%s, the state knows" % first)
	for i in 10:
		await get_tree().physics_frame
	var shown_10: float = dream.shown_aperture()
	check(shown_10 < 1.0 and shown_10 > 0.5, "10 frames after the grab the shown aperture is between 1.0 and 0.5: %.3f" % shown_10)
	for i in 20:
		await get_tree().physics_frame
	check(is_equal_approx(dream.shown_aperture(), 0.5) and is_equal_approx(dream.shown_aperture(), dream.aperture()), "30 frames after the grab it equals the aperture: %.3f" % dream.shown_aperture())
	check(dream.in_hand() and dream.effective() == 4, "half a second on: still in hand")
	var frames := await wait_until(func() -> bool: return not dream.in_hand(), 150)
	check(frames + 30 >= 118 and frames + 30 <= 122 and dream.effective() == 3 and is_equal_approx(dream.aperture(), 0.625), "the hand settled %d frames after the grab: effective 3, aperture %.3f" % [frames + 30, dream.aperture()])
	check(dreamer.hat_count() == 1 and is_zero_approx(dreamer.hat_top_offset()), "the piece sits under the hat, still (offset %.1f)" % dreamer.hat_top_offset())
	Input.action_release("pinch")
	var offsets: Array[float] = []
	for i in 30:
		await get_tree().physics_frame
		offsets.append(dreamer.hat_top_offset())
	check(not dreamer.pinched and offsets.max() - offsets.min() > 2.0 and absf(offsets.max()) <= 3.0 + 0.01, "asleep the hat wobbles: offsets %.1f..%.1f over 30 frames" % [offsets.min(), offsets.max()])
	Input.action_press("pinch")
	await settle()
	check(dreamer.pinched and is_zero_approx(dreamer.hat_top_offset()), "pinched it sits still again")
	# The carry limit: two more ideas on the far floor (flat, nothing in the way).
	dreamer.respawn(Vector2(800, 572))
	await settle()
	pool = dream.ideas_pool()
	pool.erase(first)
	var second: String = pool[0]
	var third: String = pool[1]
	dream.place_idea(second, Vector2(900, 588))
	dream.place_idea(third, Vector2(960, 588))
	check(dreamer.is_on_floor() and is_equal_approx(dreamer.position.y, 572.0) and dream.idea_in_reach() == null, "(on the far floor at x = %.0f, the two ideas ahead)" % dreamer.position.x)
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.grab() and dream.carried == [first, second] and dream.lucidity == 4 and dream.effective() == 7, "walked to the second idea and took it: carried 2, lucidity 4, in hand: effective 7")
	check(dreamer.hat_count() == 2 and is_equal_approx(dreamer.hat_height(), 48.0), "two pieces on the hat, 48 px high")
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	check(frames < 150 and dream.effective() == 6, "settled: effective 6")
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.idea_in_reach().id == third and not dream.grab() and dream.carried.size() == 2 and dream.lucidity == 4, "the third idea is in reach but the hat holds %d: grab() refused, lucidity still 4" % state.carry_limit)
	# Set down, by the Q key, facing left.
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x < 850.0, 120)
	await settle()
	var feet_x: float = dreamer.position.x
	check(dreamer.facing == -1 and dreamer.is_on_floor(), "walked back left to x = %.1f, facing left" % feet_x)
	await press_key(KEY_Q)
	await get_tree().physics_frame
	check(dream.carried == [first] and dream.lucidity == 5 and dream.effective() == 6 and not dream.in_hand(), "Q: the top idea (%s) left the hat, +1: lucidity 5, effective 6" % second)
	var step: StaticBody2D = dream.ideas_node.get_child(dream.ideas_node.get_child_count() - 1)
	check(step.id == second and step.rect().size == Vector2(48, 24) and is_equal_approx(step.position.x, feet_x - 42.0) and is_equal_approx(step.position.y, 588.0) and step.collision_layer == 2, "a 48 x 24 solid box lies at the feet in front: %s" % [step.position])
	check(acts.back() == ["set_down", second] and dreamer.hat_count() == 1, "acted set_down:%s; one piece on the hat" % second)
	# Stand on it.
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x <= step.position.x + 24.0 + 14.0 + 0.5, 120)
	check(frames < 120 and dreamer.is_on_floor() and is_equal_approx(dreamer.position.y, 572.0), "walked up against the step at x = %.1f, still on the floor" % dreamer.position.x)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 10:
		Input.action_press("move_left")
		await get_tree().physics_frame
	Input.action_release("move_left")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	check(frames < 60 and absf(dreamer.position.y - 548.0) < 1.0 and absf(dreamer.position.x - step.position.x) < 24.0, "jumped onto the step: standing at y = %.1f (24 px up), x = %.1f" % [dreamer.position.y, dreamer.position.x])
	check(dream.lucidity == 5 and hard_landings == 0, "a 24 px step costs nothing")
	# Re-grab it from on top (three wonders first, to stay under the limit).
	check(dream.wonder("w1", "spot") and dream.wonder("w2", "spot") and dream.wonder("w3", "spot") and dream.lucidity == 2, "(three wonders by hand: lucidity 2)")
	check(dream.idea_in_reach() == step and dream.grab() and dream.carried == [first, second] and dream.lucidity == 4 and dream.effective() == 7, "re-grabbed the step from on top: +2, lucidity 4, carried 2, in hand: effective 7")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor() and absf(dreamer.position.y - 572.0) < 1.0, 60)
	check(frames < 60, "the step gone, the dreamer dropped to the floor")
	# A step left behind is lost for the night, back in the pool.
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	check(dream.set_down() and dream.carried == [first] and dream.ideas_in_room().has(second) and dream.ideas_in_room().has(third) and dream.lucidity == 5, "set %s down again (lucidity 5); it and %s lie in the room" % [second, third])
	check(dream.next_room() and dream.current_room_id() == order[1] and not dream.ideas_in_room().has(second), "left the room: %s is in play" % dream.current_room_id())
	check(dream.left_behind.has(second) and dream.left_behind.has(third) and acts.has(["left", second]) and dream.carried == [first] and dream.ideas_pool().has(second), "%s (and %s) was left behind: lost for the night, still in the pool" % [second, third])
	var again: Dictionary = dream.deal_ideas(2, IDEA_ROOMS)
	check(again.values().has(second), "the next night can deal it again")
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
	check(not dream.grab() and not dream.set_down() and not dream.wonder("c2", "spot") and dream.lucidity == 8, "nothing more counts while the frame closes")
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
	# Room c: the climb, the step.
	await fresh(1)
	dream.redeal(["c", "bed"] as Array[String], false)
	var top_idea: String = dream.ideas_pool()[0]
	dream.place_idea(top_idea, Vector2(1056, 284))   # the room's IdeaSpot, by hand
	check(dream.current_room_id() == "c" and dream.ideas_in_room() == [top_idea] and dream.ideas_node.get_child(0).position == dream.room.idea_spots()[0], "room c: its idea %s lies on the top shelf at (1056, 284)" % top_idea)
	pool = dream.ideas_pool()
	pool.erase(top_idea)
	var helper: String = pool[0]
	dream.place_idea(helper, Vector2(200, 588))
	var t0 := Time.get_ticks_msec()
	var frames_c := 0
	Input.action_press("pinch")
	await settle()
	frames_c += SETTLE
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 120)
	frames_c += frames
	check(frames < 120 and dream.grab() and dream.carried == [helper], "pinched, walked to %s on the floor and took it" % helper)
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	frames_c += frames
	check(dream.lucidity == 2 and dream.effective() == 3, "settled: lucidity 2, effective 3")
	var ledges: Array = [dream.room.get_node("Crisp/Ledge1"), dream.room.get_node("Crisp/Ledge2"), dream.room.get_node("Crisp/Ledge3")]
	for i in 3:
		var ledge: StaticBody2D = ledges[i]
		frames = await climb_until(ledge, func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > ledge.position.x + 20.0 and dreamer.position.y < ledge.position.y, 240)
		frames_c += frames
		check(frames < 240 and absf(dreamer.position.y - (ledge.position.y - 28.0)) < 1.0, "up ledge %d in %d frames, standing at y = %.1f" % [i + 1, frames, dreamer.position.y])
	check(dream.lucidity == 2 and hard_landings == 0, "the climb cost nothing")
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
	check(dream.set_down() and dream.carried.is_empty() and dream.lucidity == 3 and dream.ideas_in_room().has(helper), "set %s down as a step: lucidity 3" % helper)
	var step_c: StaticBody2D = dream.ideas_node.get_child(dream.ideas_node.get_child_count() - 1)
	check(is_equal_approx(step_c.position.x, step_x) and is_equal_approx(step_c.position.y, 396.0), "the step floats past the ledge's end at %s" % [step_c.position])
	await press("jump")
	for i in 10:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 60)
	frames_c += 72
	check(frames < 60 and absf(dreamer.position.y - 356.0) < 1.0 and absf(dreamer.position.x - step_x) < 24.0, "on the step at y = %.1f, x = %.1f" % [dreamer.position.y, dreamer.position.x])
	await press("jump")
	for i in 8:
		await get_tree().physics_frame
	frames = await hold_until("move_right", func() -> bool: return dreamer.is_on_floor(), 60)
	frames_c += 70
	check(frames < 60 and absf(dreamer.position.y - (shelf.position.y - 28.0)) < 1.0 and dreamer.position.x > shelf.position.x, "from the step onto the shelf: standing at y = %.1f, x = %.1f" % [dreamer.position.y, dreamer.position.x])
	check(dream.lucidity == 3 and hard_landings == 0, "the two jumps up cost nothing")
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 120)
	frames_c += frames
	check(frames < 120 and dream.grab() and dream.carried == [top_idea] and dream.lucidity == 5 and dream.effective() == 7, "took %s at the top: lucidity 5, in hand: effective 7" % top_idea)
	frames = await wait_until(func() -> bool: return not dream.in_hand(), 150)
	frames_c += frames
	check(dream.effective() == 6 and acts.has(["set_down", helper]), "settled: effective 6; the set-down is on the record")
	frames = await hold_until("move_left", func() -> bool: return not dreamer.is_on_floor(), 120)
	frames_c += frames
	var edge_x: float = dreamer.position.x
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 120)
	frames_c += frames
	check(frames < 120 and hard_landings == 1 and dream.lucidity == 6 and absf(dreamer.position.y - 572.0) < 1.0 and dreamer.position.x > 940.0, "stepped off the shelf's edge at x = %.0f and dropped straight to the floor past the step: one hard fall, lucidity 6" % edge_x)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "c", 300)
	frames_c += frames
	check(frames < 300 and dream.current_room_id() == "bed" and dream.left_behind == [helper] and dream.carried == [top_idea], "the exit: on to the bed room; %s stayed behind, %s under the hat (room %s in %d frames, left behind %s, carried %s, at %s)" % [helper, top_idea, dream.current_room_id(), frames, dream.left_behind, dream.carried, dreamer.position])
	check(frames_c < SOLVE_FRAMES, "room c solved in %d frames (%.1f s of play, %.1f s wall)" % [frames_c, frames_c / 60.0, (Time.get_ticks_msec() - t0) / 1000.0])
	Input.action_release("pinch")

	# Room d: the maze, the lift, the island.
	await fresh(1)
	dream.redeal(["d", "bed"] as Array[String], false)
	var island_idea: String = dream.ideas_pool()[0]
	dream.place_idea(island_idea, Vector2(900, 228))
	check(dream.current_room_id() == "d" and dream.ideas_in_room() == [island_idea] and dream.ideas_node.get_child(0).position == dream.room.idea_spots()[0], "room d: its idea %s lies on the island" % island_idea)
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
	check(dream.idea_in_reach() != null and dream.grab() and dream.carried == [island_idea] and dream.lucidity == 2, "took %s" % island_idea)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "d", 300)
	frames_d += frames
	check(frames < 300 and dream.current_room_id() == "bed", "the island's far end is the exit: on to the bed room")
	check(frames_d < SOLVE_FRAMES, "room d solved in %d frames (%.1f s)" % [frames_d, frames_d / 60.0])
	Input.action_release("pinch")

	# Room e: cold water, the goat, the beam.
	await fresh(1)
	dream.redeal(["e", "bed"] as Array[String], false)
	var beam_idea: String = dream.ideas_pool()[0]
	dream.place_idea(beam_idea, Vector2(800, 348))
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	var water: Area2D = dream.room.get_node("Hazards/Water")
	check(dream.current_room_id() == "e" and dream.ideas_in_room() == [beam_idea] and dream.ideas_node.get_child(0).position == dream.room.idea_spots()[0] and water.is_in_group("hazard") and goat.id == "e_goat", "room e: its idea %s lies on the beam over the water" % beam_idea)
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
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 120)
	frames_e += frames
	check(frames < 120 and dream.grab() and dream.carried == [beam_idea] and dream.lucidity == 2, "took %s" % beam_idea)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "e", 400)
	frames_e += frames
	check(frames < 400 and dream.current_room_id() == "bed" and hard_landings == 1 and dream.lucidity == 3 and dream.blinks == 0, "off the beam's end onto the far floor (a hard fall, lucidity 3), never in the water, and out: the bed room")
	check(frames_e < SOLVE_FRAMES, "room e solved in %d frames (%.1f s)" % [frames_e, frames_e / 60.0])
	Input.action_release("pinch")

	# The ladder: no idea, a sign, exit only.
	await fresh(1)
	dream.redeal(["ladder", "bed"] as Array[String], false)
	var sign: Label = dream.room.get_node("Sign/Text")
	check(dream.current_room_id() == "ladder" and not dream.tonight_ideas.has("ladder") and dream.ideas_in_room().is_empty() and dream.room.idea_spots().is_empty(), "the ladder room holds no idea and no spot for one")
	check(sign.text == str(rooms_json.words.ladder_sign) and sign.text != "ladder_sign", "the sign reads '%s'" % sign.text)
	check(dream.room.get_node("Crisp/Ladder/Rung1").collision_layer == 2 and dream.room.exit != null, "a crisp ladder, an exit")
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "ladder", 400)
	check(frames < 400 and dream.current_room_id() == "bed" and dream.lucidity == 0, "walked under the ladder to the exit: the bed room, lucidity 0")
	Input.action_release("pinch")

	# The bed in the wrong place (the deck's day-3 trick; SPEC-2's dealer never deals it, so it is dealt by hand here).
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
	check(village.table_idea_ids().is_empty() and village.lost_stack == null, "day 1: nothing on the table, nothing over the bunk")
	frames = await walk_walker_to_bunk(village)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(frames < 400 and dream != null, "asleep")
	dreamer = dream.dreamer
	wakes.clear()
	dream.woke.connect(func(sudden: bool, carried: Array) -> void: wakes.append([sudden, carried]))
	dream.redeal(["bed"] as Array[String])   # SPEC-2: the night deals no bed room; by hand
	check(dream.current_room_id() == "bed" and dream.ideas_in_room().is_empty(), "in the bed room (dealt by hand), which holds no idea")
	var keep_id: String = ideas_json[0].id
	var lose_id: String = ideas_json[1].id
	dream.place_idea(keep_id, Vector2(300, 588))
	dream.place_idea(lose_id, Vector2(420, 588))
	Input.action_press("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.grab(), "took %s" % keep_id)
	frames = await hold_until("move_right", func() -> bool: return dream.idea_in_reach() != null, 300)
	check(frames < 300 and dream.grab() and dream.carried == [keep_id, lose_id] and dream.effective() == 7, "took %s: effective 7" % lose_id)
	dream.fall()
	check(dream.effective() == 8 and dream.closing and not toy.picking, "a fall: the limit; the frame closes, no picker yet")
	for i in 40:
		await get_tree().physics_frame
	check(not toy.picking and not panel.choice_box.visible and toy.dream == dream and wakes.is_empty(), "40 frames on: the frame still shut, the dream still up, no picker")
	frames = await wait_until(func() -> bool: return toy.picking, 60)
	check(frames < 60 and wakes.size() == 1 and panel.choice_box.visible and panel.choice_box.get_child_count() == 2 and panel.say_label.text == words.wake_sudden, "then woke: the picker is up with two choices")
	await press_key(KEY_1)
	await settle()
	check(state.ideas_kept == [keep_id] and state.ideas_carried.is_empty() and state.day == 2, "kept %s, day 2" % keep_id)
	village = toy.village
	check(village != null and village.table_idea_ids() == [keep_id], "the kept idea lies on the table by day")
	var table_piece: Node2D = village.table_ideas.get_child(0)
	check(table_piece.get_child(2).text == name_of(keep_id), "labelled '%s'" % table_piece.get_child(2).text)
	check(village.lost_stack != null and village.lost_stack.get_child_count() == 1 and village.lost_stack.get_child(0).get_meta("id") == lose_id and village.lost_alpha() > 0.9, "the lost idea floats over the bunk (alpha %.2f)" % village.lost_alpha())
	check(village.lost_stack.position == Vector2.ZERO and village.lost_stack.get_child(0).position.x > village.BUNK.position.x and village.lost_stack.get_child(0).position.y < village.BUNK.position.y - 40.0, "above the bunk")
	# The fade runs on process delta (village._process), so wait in real
	# seconds the same way, never a frame count: at 120 Hz 180 frames is 1.5 s.
	var waited := await wait_seconds(3.0)
	check(village.lost_stack != null and village.lost_alpha() < 0.6 and village.lost_alpha() > 0.4, "3 s on (%.2f s of process time): half faded (alpha %.2f)" % [waited, village.lost_alpha()])
	waited = await wait_until_seconds(func() -> bool: return village.lost_stack == null, 6.0)
	check(village.lost_stack == null and is_zero_approx(village.lost_alpha()) and waited > 2.5 and waited < 4.0, "6 s on: gone (%.2f s after the half)" % waited)
	check(toy.harness.summary().contains("lost  %s" % lose_id) and toy.harness.summary().contains("kept:%s" % keep_id), "the harness recorded lost %s and kept:%s" % [lose_id, keep_id])
	Input.action_release("pinch")
	frames = await walk_walker_to_bunk(village)
	await press_key(KEY_E)
	await settle()
	dream = toy.dream
	check(dream != null and dream.ideas_pool().has(lose_id) and not dream.ideas_pool().has(keep_id), "night 2: %s is back in the pool, %s is not" % [lose_id, keep_id])
	check(dream.tonight_ideas.is_empty() and dream.rooms_tonight() == ["hub"] and dream.scraps_dealt() == 6, "SPEC-2: the dealer laid no idea tonight (nobody talked to: the hub alone, with its six scraps)")

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
	dream.woke.connect(func(sudden: bool, carried: Array) -> void: wakes.append([sudden, carried]))
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
