extends Node
## Headless check of the toys' shared harness (rung 3): the text panel and
## the session recorder, with no toy. Instantiates both, shows a sentence,
## three choices and a hint, simulates the key for choice 2 and a click on a
## button, records three actions and two milestones (one of them twice),
## and reads them back from summary() and from the log file written when
## the harness leaves the tree. A second harness stays in the tree so the
## quit() path writes its own log (check the toy_sessions folder after the
## run). Prints PASS/FAIL per check and quits with 0 only if all pass.

const PANEL := preload("res://prototypes/_shared/text_panel.tscn")
const HARNESS := preload("res://prototypes/_shared/toy_harness.gd")

var failures := 0
var picks: Array[int] = []


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var panel := PANEL.instantiate()
	add_child(panel)
	var harness: Node = HARNESS.new()
	harness.name = "Harness"
	add_child(harness)
	harness.start("harness_test")
	panel.chosen.connect(func(i: int) -> void: picks.append(i))

	# The panel shows what it is told.
	panel.say("A sentence at the bottom of the screen.")
	panel.prompt("E to talk")
	panel.choices(["First", "Second", "Third"] as Array[String])
	check(panel.say_label.visible and panel.say_label.text == "A sentence at the bottom of the screen.", "say() put the sentence on the Say label (visible, text '%s')" % panel.say_label.text)
	check(panel.prompt_label.visible and panel.prompt_label.text == "E to talk", "prompt() put the hint on the Prompt label ('%s')" % panel.prompt_label.text)
	check(panel.choice_box.visible and panel.choice_box.get_child_count() == 3, "choices() made 3 buttons (%d) and showed them" % panel.choice_box.get_child_count())
	check(panel.choice_box.get_child(1).text == "2.  Second", "the second button is numbered: '%s'" % panel.choice_box.get_child(1).text)

	# The key for choice 2, through the input system, as a player would press it.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_2
	ev.keycode = KEY_2
	ev.unicode = 50
	ev.pressed = true
	check(ev.is_action_pressed("choice_2"), "the project maps key 2 to the action choice_2")
	check(not ev.is_action_pressed("choice_1") and not ev.is_action_pressed("choice_3"), "key 2 is not choice_1 or choice_3")
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	if picks.is_empty():
		print("  (Input.parse_input_event did not reach the tree headless; pushing the event to the root viewport instead)")
		get_tree().root.push_input(ev)
		await get_tree().process_frame
	check(picks == [1], "chosen(1) fired for choice_2 (got %s)" % [picks])
	check(not panel.choice_box.visible and panel.choice_box.get_child_count() == 0, "the choices went away after the pick (%d buttons left)" % panel.choice_box.get_child_count())
	var ev_e := InputEventKey.new()
	ev_e.physical_keycode = KEY_E
	ev_e.pressed = true
	check(ev_e.is_action_pressed("interact"), "the project maps physical E to the action interact")

	# A second round: the same key with no choices showing does nothing; a click picks.
	get_tree().root.push_input(ev)
	await get_tree().process_frame
	check(picks == [1], "a key press with no choices showing emits nothing (got %s)" % [picks])
	panel.choices(["Yes", "No"] as Array[String])
	(panel.choice_box.get_child(0) as Button).pressed.emit()
	check(picks == [1, 0], "a click on the first button emits chosen(0) (got %s)" % [picks])

	# hide_all clears the three.
	panel.say("Still here")
	panel.prompt("hint")
	panel.choices(["A"] as Array[String])
	panel.hide_all()
	check(not panel.say_label.visible and not panel.prompt_label.visible and not panel.choice_box.visible and panel.choice_box.get_child_count() == 0, "hide_all() hid the sentence, the hint and the choices")

	# The harness counts and timestamps.
	harness.action("talk")
	harness.action("choose", "Second")
	harness.action("choose", "Yes")
	harness.milestone("first_talk")
	harness.milestone("first_choice")
	harness.milestone("first_talk")   # a repeat: must not count twice
	var s: String = harness.summary()
	print("--- summary() ---\n%s\n--- end ---" % s)
	check(s.contains("toy: harness_test"), "summary names the toy")
	check(s.contains("played: ") and s.contains("minutes"), "summary reports minutes played")
	check(s.contains("actions: 3 (") and s.contains("per minute)"), "summary reports 3 actions and a per-minute rate")
	check(s.contains("  talk: 1") and s.contains("  choose: 2"), "summary counts per kind: talk 1, choose 2")
	check(s.contains("milestones: 2"), "summary reports 2 milestones (the repeat was ignored)")
	check(s.count("first_talk") == 1 and s.count("first_choice") == 1, "each milestone is listed once with its time")
	var ms_line := RegEx.create_from_string("\\n  \\d\\d:\\d\\d  first_choice")
	check(ms_line.search(s) != null, "a milestone line carries a mm:ss time")
	check(s.contains("  choose  Second") and s.contains("  choose  Yes"), "the timeline keeps the actions' details")

	# Leaving the tree writes the log.
	remove_child(harness)
	var path: String = harness.log_path
	check(path.begins_with("user://toy_sessions/harness_test_") and path.ends_with(".log"), "the log path is user://toy_sessions/<toy>_<timestamp>.log: %s" % path)
	check(path != "" and FileAccess.file_exists(path), "the log file exists at %s" % ProjectSettings.globalize_path(path))
	var text := FileAccess.get_file_as_string(path) if path != "" else ""
	check(text.contains("toy: harness_test") and text.contains("milestones: 2") and text.contains("first_choice") and text.contains("actions: 3 ("), "the log file holds the summary")
	harness.free()

	# A harness that stays in the tree: quit() must write its log too (seen in the folder after the run).
	var h2: Node = HARNESS.new()
	h2.name = "Harness"
	add_child(h2)
	h2.start("harness_test_quit")
	h2.action("quit_path")
	h2.milestone("about_to_quit")

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
