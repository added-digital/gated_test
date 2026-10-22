extends Node2D
## Scripted play of the day-2 dream of toy 4, PINCH (prototypes/pinch/
## dream.tscn alone, with a fresh PinchState), headless. The dreamer is
## driven through the input actions (Input.action_press) with frame
## budgets; positions, lucidity and the frame are read back. The run, night
## 1: the dealer (tutorial first, the two rooms in the seeded order, the
## bed last; night 2 has no tutorial); the tutorial: asleep nothing moves
## for 60 frames, the soft pillar is passed, the current carries the body
## across the gap (120 px/s on its own), pinching over the far floor lands
## in under 30 frames for nothing, a jump reaches 80 px and lands free,
## walking off the far floor into the gap fails the screen (blink shut,
## back at the door in under 100 frames, +1), the step by the door: up by a
## jump, off it a hard fall (+1), pinched inside the current nothing
## moves, the exit chains to the second room with the frame unchanged;
## room a: the soft wall's wonder once (-1, not twice, never below 0), the
## jump up the ledge is free, 3 s still in the spot (-1); room b: a hazard
## while pinched fails the screen, the goat carries the body along its
## round (the dreamer's motion equals the goat's), its wonder once, pinch
## over the far floor, the exit; the bed room: two ideas, the block, the
## bed, E wakes gently. Prints PASS/FAIL per check and quits with 0 only
## if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const DRIFT_FRAMES := 600   # 10 s at 60 Hz: the longest drift here is about 6 s
const RIDE_FRAMES := 720    # 12 s: the goat's round is 2440 px at 300 px/s (8.1 s)
const SETTLE := 20

var failures := 0
var dream: Node2D
var dreamer: CharacterBody2D
var state: PinchState
var wakes: Array = []
var entered: Array[String] = []
var hard_landings := 0


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	state = PinchState.new()
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	dreamer = dream.dreamer
	dream.woke.connect(func(sudden: bool, carried: Array) -> void: wakes.append([sudden, carried]))
	dream.room_entered.connect(func(id: String) -> void: entered.append(id))
	dreamer.hard_landing.connect(func() -> void: hard_landings += 1)
	var rooms_json: Dictionary = PinchState.load_json(ROOMS_FILE)
	await get_tree().physics_frame

	# (7) The dealer, night 1.
	var order: Array = dream.rooms_tonight()
	check(order.size() == 4 and order[0] == "tutorial" and order[3] == "bed", "night 1 deals 4 rooms, the tutorial first and the bed last: %s" % [order])
	var middle: Array = [order[1], order[2]]
	middle.sort()
	check(middle == ["a", "b"], "the two rooms lie between them, each once: %s" % [order])
	check(order == dream.deal(1) and dream.deal(1) == dream.deal(1), "the order is the deal seeded by day 1, the same each time")
	var night2: Array = dream.deal(2)
	check(night2.size() == 3 and night2[0] != "tutorial" and night2[2] == "bed" and not night2.has("tutorial"), "night 2 deals no tutorial: %s" % [night2])
	check(dream.current_room_id() == "tutorial" and dream.room.id == "tutorial" and entered.is_empty(), "the tutorial is the room in play (dealt in _ready, before anyone could listen)")
	var tutorial_words: Dictionary = dream.room_words("tutorial")
	check(dream.room_label.text == str(rooms_json.label).format({"name": tutorial_words.name, "hint": tutorial_words.hint}) and dream.room_label.text.contains("exit"), "the room label reads '%s'" % dream.room_label.text)
	check(dreamer.collision_layer == 16 and dreamer.collision_mask == 9, "asleep the dreamer is on layer 16 and masks bounds and net (1 | 8 = %d)" % dreamer.collision_mask)
	check(dream.frame_top.get_parent().name == "Frame" and dream.frame_top.get_parent().get_parent() == dream, "the frame belongs to the dream, not the room")

	# (1) Asleep: no gravity, soft is passed, the current carries.
	var door: Vector2 = dream.room.door.position
	var start: Vector2 = dreamer.position
	check(start == door, "the dreamer starts at the door %s" % [door])
	for i in 60:
		await get_tree().physics_frame
	check(dreamer.position == start and not dreamer.is_on_floor() and not dreamer.pinched, "asleep, 60 frames, no input: the body has not moved (%s), off the floor" % [dreamer.position])
	check(dream.lucidity == 0 and is_equal_approx(dream.aperture(), 1.0) and dream.frame_open.size == get_viewport().get_visible_rect().size, "lucidity 0, the frame fully open")
	var pillar: StaticBody2D = dream.room.get_node("Soft/Pillar")
	check(pillar.collision_layer == 4 and pillar.is_in_group("soft") and pillar.visible, "the soft pillar is on layer 4, in the group soft, and seen while asleep")
	var frames := await hold_until("move_right", func() -> bool: return dreamer.position.x > 360.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dreamer.position.y == start.y, "nudged right through the soft pillar (x 300..340) in %d frames, y unchanged at %.1f" % [frames, dreamer.position.y])
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > 500.0, DRIFT_FRAMES)
	var current: Area2D = dream.room.get_node("Currents/Across")
	check(frames < DRIFT_FRAMES and dreamer.carried_by == [current], "over the gap at x = %.1f, inside the current" % dreamer.position.x)
	var x0: float = dreamer.position.x
	for i in 30:
		await get_tree().physics_frame
	check(is_equal_approx(dreamer.velocity.x, 120.0) and is_equal_approx(dreamer.position.x - x0, 60.0) and dreamer.position.y == start.y, "no input: the current alone carries at 120 px/s (%.1f px in 30 frames), y unchanged" % (dreamer.position.x - x0))
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > 830.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dreamer.position.y == start.y and not dreamer.is_on_floor(), "carried across the gap to x = %.1f, still hovering" % dreamer.position.x)

	# (2) Pinch over the far floor: a short drop, free.
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 30)
	check(frames < 30 and dreamer.pinched and dreamer.collision_mask == 3 and is_equal_approx(dreamer.position.y, 572.0), "pinched over the far floor: landed in %d frames at y = %.1f (mask bounds | crisp = %d)" % [frames, dreamer.position.y, dreamer.collision_mask])
	check(dream.lucidity == 0 and hard_landings == 0, "a drop of 24 px is not a hard fall: lucidity 0")
	check(not pillar.visible and pillar.get_child(0).disabled, "pinched: the soft pillar is hidden and its shape disabled")

	# (4) A jump reaches 80 px and lands free; a drop taller than a body does not.
	var floor_y: float = dreamer.position.y
	var top_y := floor_y
	await press("jump")
	for i in 60:
		await get_tree().physics_frame
		top_y = minf(top_y, dreamer.position.y)
		if i > 5 and dreamer.is_on_floor():
			break
	check(floor_y - top_y >= 80.0, "the jump rose %.1f px" % (floor_y - top_y))
	check(dreamer.is_on_floor() and dream.lucidity == 0 and hard_landings == 0, "landed from the jump on the same floor: not a hard fall, lucidity 0")

	# (3) Walk off the far floor into the gap: the screen fails.
	frames = await hold_until("move_left", func() -> bool: return not dreamer.is_on_floor(), 300)
	check(frames < 300 and dreamer.position.x < 760.0, "walked left off the far floor at x = %.1f" % dreamer.position.x)
	var blink_seen := false
	frames = 0
	while frames < 100 and not (dream.blinks == 1 and not dream.blinking and dreamer.visible):
		if dream.blinking and dream.frame_open.size == Vector2.ZERO and not dreamer.visible and dreamer.frozen:
			blink_seen = true
		await get_tree().physics_frame
		frames += 1
	check(frames < 100 and frames >= 60 and dream.blinks == 1, "fell out of the room, blinked for one second and reappeared in %d frames" % frames)
	check(blink_seen, "during the blink the frame was shut and the dreamer gone")
	check(dreamer.position.distance_to(door) < 8.0, "back at the door: %s" % [dreamer.position])
	check(dream.lucidity == 1 and is_equal_approx(dream.aperture(), 1.0 - 1.0 / 8.0), "a failed screen: lucidity 1, aperture %.3f" % dream.aperture())
	check_frame()
	await settle()
	check(dreamer.is_on_floor() and dream.lucidity == 1 and hard_landings == 0, "pinch still held: the drop at the door is short, nothing more counted")

	# (4b) The step: up by a jump, off it a hard fall.
	var step: StaticBody2D = dream.room.get_node("Crisp/Step")
	await press("jump")
	frames = await hold_until("move_right", func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 200.0 and dreamer.position.y < 520.0, 120)
	check(frames < 120 and absf(dreamer.position.y - (step.position.y - 28.0)) < 1.0, "jumped onto the step in %d frames, standing at y = %.1f" % [frames, dreamer.position.y])
	frames = await hold_until("move_right", func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 300.0, 120)
	check(frames < 120 and absf(dreamer.position.y - 572.0) < 1.0 and hard_landings == 1 and dream.lucidity == 2, "walked off the step (64 px, taller than a body): a hard fall at y = %.1f, %d hard landing(s), lucidity %d" % [dreamer.position.y, hard_landings, dream.lucidity])
	check(dreamer.carried_by.is_empty() and is_zero_approx(dreamer.velocity.x), "pinched inside the current: it does nothing")
	check_frame()

	# Across again, and out through the exit.
	Input.action_release("pinch")
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > 830.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and not dreamer.is_on_floor(), "asleep again, carried across in %d frames" % frames)
	Input.action_press("pinch")
	await settle()
	var before: Rect2 = dream.frame_open
	var frame_node: Node = dream.frame_top
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "tutorial", 300)
	check(frames < 300 and dream.current_room_id() == order[1] and entered == [order[1]], "standing pinched in the exit dealt the next room, %s, in %d frames" % [dream.current_room_id(), frames])
	check(dreamer.position.distance_to(dream.room.door.position) < 8.0, "the dreamer is at the new room's door")
	check(dream.frame_open == before and dream.frame_top == frame_node and dream.lucidity == 2, "the frame persisted across rooms: still %s" % [before])
	Input.action_release("pinch")

	# (5) Room a: the soft wall's wonder, once; the climb; the spot.
	check(dream.jump_to_room("a") and dream.current_room_id() == "a" and dream.room.id == "a", "jumped to room a")
	door = dream.room.door.position
	await get_tree().physics_frame
	check(dreamer.position == door and not dreamer.pinched, "at room a's door, asleep")
	var wall: Area2D = dream.room.get_node("Wonders/Wall")
	check(wall.is_in_group("wonder") and wall.is_in_group("soft") and wall.id == "a_wall" and wall.kind == "soft_wall" and wall.visible, "the soft wall is a wonder, soft, seen")
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > 560.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dream.lucidity == 1 and dream.wonders_seen.has("a_wall"), "drifted through the soft wall: wonder, lucidity 2 -> 1")
	frames = await hold_until("move_left", func() -> bool: return dreamer.position.x < 400.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dream.lucidity == 1, "drifted back through it: nothing more this visit")
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > 620.0, DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dream.lucidity == 1, "and through a third time: still 1")
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor(), 30)
	check(frames < 30 and dream.lucidity == 1, "pinched over the far floor of room a: landed, free")
	var ledge: StaticBody2D = dream.room.get_node("Crisp/Ledge")
	frames = await climb_until(ledge, func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 790.0 and dreamer.position.y < 520.0, 400)
	check(frames < 400 and absf(dreamer.position.y - (ledge.position.y - 28.0)) < 1.0, "one jump up the ledge (64 px) in %d frames, standing at x = %.1f, y = %.1f" % [frames, dreamer.position.x, dreamer.position.y])
	check(dream.lucidity == 1 and hard_landings == 1, "the climb cost nothing: lucidity 1")
	var spot: Area2D = dream.room.get_node("Wonders/Quiet")
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x > spot.position.x + 40.0, 120)
	check(frames < 120 and spot.overlaps_body(dreamer), "standing in the spot at x = %.1f" % dreamer.position.x)
	for i in 150:
		await get_tree().physics_frame
	check(dream.lucidity == 1, "2.5 s still: not yet")
	for i in 40:
		await get_tree().physics_frame
	check(dream.lucidity == 0 and dream.wonders_seen.has("a_spot"), "3 s still in the spot: wonder, lucidity 0")
	dream.fall()
	check(dream.lucidity == 1, "(a hard fall by hand: lucidity 1, to see the floor at 0)")
	check(not dream.wonder("a_spot", "spot") and dream.lucidity == 1, "the same wonder again gives nothing")
	check(dream.wonder("made_up", "spot") and dream.lucidity == 0, "a wonder at 0 stays 0: never below")
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "a", 300)
	var after_a: String = order[order.find("a") + 1]
	check(frames < 300 and dream.current_room_id() == after_a, "room a's exit dealt the room after it, %s" % dream.current_room_id())
	Input.action_release("pinch")

	# (6) Room b: the goat; a pinch too early over the pit; the goat again to the exit.
	check(dream.jump_to_room("b") and dream.current_room_id() == "b", "jumped to room b")
	door = dream.room.door.position
	await get_tree().physics_frame
	var lucidity_before: int = dream.lucidity
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	check(goat.is_in_group("current") and goat.is_in_group("wonder") and goat.kind == "goat" and goat.id == "b_goat" and goat.label.text == rooms_json.words.goat, "the goat is a current and a wonder, labelled '%s'" % goat.label.text)
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
	frames = await wait_until(func() -> bool: return dreamer.carried_by.has(goat), RIDE_FRAMES)
	check(frames < RIDE_FRAMES and not dreamer.pinched, "the goat came by in %d frames" % frames)
	for i in 60:
		await get_tree().physics_frame
	check(dreamer.carried_by.has(goat) and dreamer.position.distance_to(goat.center()) < 2.0, "a second on: the dreamer sits on the goat's back (%.1f px from its middle)" % dreamer.position.distance_to(goat.center()))
	var d0: Vector2 = dreamer.position
	var g0: Vector2 = goat.global_position
	for i in 90:
		await get_tree().physics_frame
	var moved: Vector2 = dreamer.position - d0
	var goat_moved: Vector2 = goat.global_position - g0
	check(moved.length() > 100.0 and moved.distance_to(goat_moved) < 2.0, "90 frames on the goat: the dreamer moved %s, the goat %s" % [moved, goat_moved])
	check(dream.lucidity == maxi(0, lucidity_before - 1) and dream.wonders_seen.has("b_goat"), "riding the goat: wonder, lucidity %d" % dream.lucidity)
	frames = await wait_until(func() -> bool: return goat.center().x > 700.0 and goat.center().y < 220.0, RIDE_FRAMES)
	check(frames < RIDE_FRAMES and dreamer.carried_by.has(goat) and dreamer.position.y < 240.0, "carried up over the wall, over the pit at x = %.1f, y = %.1f" % [dreamer.position.x, dreamer.position.y])
	var blinks_before: int = dream.blinks
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dream.blinks > blinks_before, 120)
	check(frames < 120 and dream.blinking and dream.lucidity == maxi(0, lucidity_before - 1) + 1, "pinched too early: fell into the pit (the hazard), the screen failed in %d frames, lucidity %d" % [frames, dream.lucidity])
	frames = await wait_until(func() -> bool: return not dream.blinking, 100)
	check(frames < 100 and dreamer.position.distance_to(door) < 8.0, "back at room b's door after the one-second blink (%d frames)" % frames)
	var lucidity_after_fail: int = dream.lucidity
	Input.action_release("pinch")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
	frames = await wait_until(func() -> bool: return dreamer.carried_by.has(goat), RIDE_FRAMES)
	check(frames < RIDE_FRAMES, "the goat came round again in %d frames" % frames)
	frames = await wait_until(func() -> bool: return goat.center().x > 1000.0 and goat.center().y > 535.0, RIDE_FRAMES)
	check(frames < RIDE_FRAMES and dreamer.carried_by.has(goat) and dreamer.position.x > 900.0 and dreamer.position.distance_to(goat.center()) < 2.0 and dream.lucidity == lucidity_after_fail, "carried round and down to the far side, on the goat's back at x = %.1f, y = %.1f; no second wonder" % [dreamer.position.x, dreamer.position.y])
	Input.action_press("pinch")
	frames = await wait_until(func() -> bool: return dreamer.is_on_floor() or dream.current_room_id() != "b", 30)
	check(frames < 30 and dream.lucidity == lucidity_after_fail and dream.blinks == blinks_before + 1 and dream.hard_falls == 2, "pinched off the goat's back above the far floor (32 px): landed free, lucidity %d" % dream.lucidity)
	frames = await hold_until("move_right", func() -> bool: return dream.current_room_id() != "b", 300)
	var after_b: String = order[order.find("b") + 1]
	check(frames < 300 and dream.current_room_id() == after_b, "room b's exit dealt the room after it, %s" % dream.current_room_id())
	check(dream.blinks == 2 and dream.hard_falls == 2 and wakes.is_empty(), "two failed screens, two hard falls, still dreaming (%d, %d)" % [dream.blinks, dream.hard_falls])

	# The bed room: the stub's contents, and a gentle waking.
	check(dream.jump_to_room("bed") and dream.current_room_id() == "bed", "jumped to the bed room")
	check(dream.ideas_node.get_child_count() == 2 and dream.block != null and dream.bed != null and dream.room.exit == null, "two ideas, the block and the bed, no exit")
	check(not dream.set_down(), "set_down is reserved (day 3): nothing yet")
	await settle()
	frames = await hold_until("move_right", func() -> bool: return dream.bed_in_reach(), DRIFT_FRAMES)
	check(frames < DRIFT_FRAMES and dream.lie_down(), "walked to the bed in %d frames and lay down" % frames)
	check(wakes.size() == 1 and wakes[0][0] == false and wakes[0][1].is_empty(), "woke gently with nothing carried")
	Input.action_release("pinch")
	Input.action_release("move_right")

	# (7) Night 2: no tutorial.
	remove_child(dream)
	dream.queue_free()
	await get_tree().physics_frame
	state = PinchState.new()
	state.day = 2
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	await get_tree().physics_frame
	check(dream.rooms_tonight() == night2 and dream.current_room_id() == night2[0] and dream.current_room_id() != "tutorial", "night 2 opens on %s, the seeded order %s" % [dream.current_room_id(), dream.rooms_tonight()])

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## The four frame rects leave a centred hole of aperture * screen.
func check_frame() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var expected: Vector2 = screen * dream.aperture()
	var hole: Rect2 = dream.frame_open
	var ok: bool = hole.size.is_equal_approx(expected) and hole.position.is_equal_approx((screen - expected) / 2.0)
	ok = ok and dream.frame_top.size.is_equal_approx(Vector2(screen.x, hole.position.y)) and dream.frame_left.size.is_equal_approx(Vector2(hole.position.x, hole.size.y))
	check(ok, "the frame leaves %.0f x %.0f open (aperture %.3f)" % [hole.size.x, hole.size.y, dream.aperture()])


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
