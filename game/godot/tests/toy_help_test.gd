extends Node3D
## Scripted play of toy 2, Help (prototypes/help/help.tscn), headless. The
## player is driven through the physics engine with auto_move, as in the
## walk test; E is pressed through the input system. The run: meet the
## runner, read request 1, walk to its crate, pick it up, come back, hand it
## over, and expect the milestone request_1_done; then meet the runner again
## for request 2, stand still until its clock runs out and expect too_late;
## then meet them once more and expect request 3 still offered, asked with
## its ask_after_miss line because request 2 was missed. Prints PASS/FAIL
## per check and quits with 0 only if every check passes.

const TOY := preload("res://prototypes/help/help.tscn")
const MEET_FRAMES := 2400   # 40 s to meet the runner (a round trip of the path is 12 s)
const WALK_FRAMES := 1800   # 30 s to reach a crate or come back
const CLOSE := 1.5          # m: inside the toy's pick-up (2 m) and hand-over (3 m) ranges

var toy: Node3D
var player: CharacterBody3D
var runner: Node3D
var panel: CanvasLayer
var harness: Node
var failures := 0


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	toy = TOY.instantiate()
	add_child(toy)
	player = toy.player
	runner = toy.runner
	panel = toy.panel
	harness = toy.harness
	await settle()
	check(toy.requests.size() == 3, "requests.json holds 3 requests (%d)" % toy.requests.size())
	check(harness.toy_name == "help", "the harness was started as 'help' (%s)" % harness.toy_name)
	check(panel.say_label.visible and panel.say_label.text == toy.words.start, "the start line is on screen: '%s'" % panel.say_label.text)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "the player stands on the ground, feet at y = %.3f" % player.position.y)
	check(not runner.stopped, "the runner is running at the start")

	# 1. Meet the runner: request 1.
	var frames := await meet_runner()
	var r1: Dictionary = toy.requests[0]
	check(toy.number == 1 and not toy.request.is_empty(), "the runner stopped and offered request 1 after %d frames, at %s" % [frames, runner.global_position])
	check(runner.stopped, "the runner is stopped for the request")
	check(panel.say_label.text == r1.ask, "the panel says request 1's ask line")
	check(toy.crate != null and toy.crate.get_node("Name").text == r1.item, "the crate '%s' is on the field at %s" % [r1.item, toy.crate.global_position if toy.crate else Vector3.ZERO])
	check(panel.prompt_label.text.begins_with("%d s" % ceili(toy.time_left)), "the prompt line starts with the countdown: '%s'" % panel.prompt_label.text)
	check(panel.prompt_label.text.ends_with(r1.where), "the prompt line ends with the where hint")

	# 2. Fetch the crate.
	frames = await walk_to(toy.crate)
	check(frames < WALK_FRAMES, "reached the crate in %d frames, %.2f m away" % [frames, flat_distance(toy.crate)])
	check(panel.prompt_label.text.ends_with(toy.words.pick_up.format({"item": r1.item})), "near the crate the prompt says how to pick it up: '%s'" % panel.prompt_label.text)
	await press_e()
	check(toy.carrying(), "E picked the crate up: it is parented to the player")
	check(toy.crate != null and toy.crate.position.is_equal_approx(toy.HOLD_AT), "the crate floats in front of the player at %s" % (toy.crate.position if toy.crate else Vector3.ZERO))
	check(harness.summary().contains("  pickup: 1"), "the harness counted one pickup")
	check(panel.prompt_label.text.ends_with(toy.words.bring_back.format({"item": r1.item})), "carrying, the prompt says to bring it back: '%s'" % panel.prompt_label.text)

	# 3. Bring it back and hand it over.
	frames = await walk_to(runner)
	check(frames < WALK_FRAMES, "back at the runner in %d frames, %.2f m away" % [frames, flat_distance(runner)])
	check(panel.prompt_label.text.ends_with(toy.words.hand_over.format({"item": r1.item})), "near the runner with the crate the prompt says how to hand it over: '%s'" % panel.prompt_label.text)
	var left: float = toy.time_left
	await press_e()
	check(toy.request.is_empty() and toy.crate == null, "E handed it over: request 1 closed with %.1f s left and the crate is gone" % left)
	check(panel.say_label.text == r1.thanks, "the panel says the thanks line")
	check(panel.prompt_label.text == "", "the countdown is gone")
	check(harness.summary().contains("  deliver: 1") and harness.summary().contains("request_1_done"), "the harness counted one deliver and the milestone request_1_done")
	check(not runner.stopped and not runner.passed_an_end, "the runner hurried on and may not stop before the next end of the path")

	# 4. The next request after they pass again.
	frames = await meet_runner()
	var r2: Dictionary = toy.requests[1]
	check(toy.number == 2 and not toy.request.is_empty(), "request 2 offered after the runner passed an end, %d frames later" % frames)
	check(panel.say_label.text == r2.ask, "the panel says request 2's plain ask line (request 1 was delivered, not missed)")
	check(absf(toy.time_left - float(r2.seconds)) < 0.1, "request 2's clock started at its own %d s (%.2f)" % [r2.seconds, toy.time_left])

	# 5. Stand still until the clock runs out. The toy's clock counts real
	# seconds in _process, so wait on the toy's own state with a timeout in
	# seconds, never a frame count: at 120 Hz a frame count is half the time.
	player.auto_move = Vector3.ZERO
	var waited := await wait_until(func() -> bool: return toy.request.is_empty(), float(r2.seconds) + 5.0)
	check(waited >= float(r2.seconds) - 0.5 and waited < float(r2.seconds) + 5.0, "request 2's clock ran out after %.1f s (its %d s)" % [waited, r2.seconds])
	check(toy.request.is_empty() and toy.crate == null, "request 2 closed by the clock and its crate is gone")
	check(panel.say_label.text == r2.too_late, "the panel says the too-late line")
	check(harness.summary().contains("  00:") and harness.summary().contains("too_late"), "the harness recorded the milestone too_late")
	check(not harness.summary().contains("request_2_done"), "no request_2_done milestone for a miss")
	check(not runner.stopped, "the runner left without it")

	# 6. The next request is still offered after a miss.
	frames = await meet_runner()
	var r3: Dictionary = toy.requests[2]
	check(toy.number == 3 and not toy.request.is_empty(), "request 3 still offered after the miss, %d frames later" % frames)
	check(panel.say_label.text == r3.get("ask_after_miss", "") and panel.say_label.text != r3.ask, "after the too_late the panel says request 3's ask_after_miss line, not its ask: '%s'" % panel.say_label.text)

	print("--- summary() ---\n%s\n--- end ---" % harness.summary())
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## Let gravity put the capsule on the ground before driving it.
func settle() -> void:
	player.auto_move = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame


## Wait, in real seconds, until a condition holds or the timeout passes.
## Returns the seconds waited. Process delta, like the toy's own clock.
func wait_until(cond: Callable, timeout: float) -> float:
	var waited := 0.0
	while not cond.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited


## Chase the runner until a request opens or the frames run out.
func meet_runner() -> int:
	var frames := 0
	while toy.request.is_empty() and frames < MEET_FRAMES:
		player.auto_move = flat_direction(runner)
		await get_tree().physics_frame
		frames += 1
	player.auto_move = Vector3.ZERO
	await get_tree().process_frame
	return frames


## Steer toward a node until within CLOSE of it or the frames run out.
func walk_to(target: Node3D) -> int:
	var frames := 0
	while flat_distance(target) > CLOSE and frames < WALK_FRAMES:
		player.auto_move = flat_direction(target)
		await get_tree().physics_frame
		frames += 1
	player.auto_move = Vector3.ZERO
	await get_tree().process_frame
	return frames


## Press and release E through the input system, as a player would.
func press_e() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_E
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func flat_direction(target: Node3D) -> Vector3:
	var to := target.global_position - player.global_position
	to.y = 0.0
	return to.normalized()


func flat_distance(target: Node3D) -> float:
	var to := target.global_position - player.global_position
	to.y = 0.0
	return to.length()
