extends Node3D
## Headless check of the Remember toy (rung 3, toy 1) through its real
## scene: the player is driven to the character with auto_move, E and the
## number keys go through the input system, and every line is read back from
## the toy's line_shown signal. Two full plays: the first picks reply 1 at
## every choice, the second reply 2. Each must get through the three
## encounters (the character walking 8-10 m between them), and in the
## third encounter must reach a line whose "if" names a flag set in the
## first encounter; the two plays must reach different third-encounter
## lines. Prints PASS/FAIL per check and quits with 0 only if all pass.

const TOY := preload("res://prototypes/remember/remember.tscn")

const APPROACH := 1.5      # m: stop driving the player this close to the character
const WALK_FRAMES := 900   # physics frames allowed to reach the character (10 m at 3.5 m/s is about 170)
const GLIDE_FRAMES := 900  # physics frames allowed for the character's walk (10 m at 1.6 m/s is 375)
const MAX_PRESSES := 60    # key presses allowed per encounter before giving up
const E3_EXPECTED := ["e3_promise[e1_promised]", "e3_promise[e1_no_promise]"]   # per play: the encounter-1 promise, kept or not

var failures := 0
var toy: Node3D
var lines: Array = []   # per encounter of the current play, the nodes shown, in order


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var first := await play(0)
	var second := await play(1)
	var a := signatures(first[2])
	var b := signatures(second[2])
	check(a != b, "the two plays reached different encounter-3 lines:\n    reply 1: %s\n    reply 2: %s" % [", ".join(a), ", ".join(b)])
	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## One whole play, picking reply number option + 1 at every choice.
## Returns the lines shown, one array per encounter.
func play(option: int) -> Array:
	print("=== play %d: reply %d at every choice ===" % [option + 1, option + 1])
	toy = TOY.instantiate()
	add_child(toy)
	lines = []
	toy.line_shown.connect(func(n: Dictionary) -> void: lines[-1].append(n))
	var player: CharacterBody3D = toy.player
	var character: Node3D = toy.character
	var panel: CanvasLayer = toy.panel
	var harness: Node = toy.harness
	check(toy.dialogue.error == "", "dialogue.json loads and every link checks out%s" % ("" if toy.dialogue.error == "" else ":\n" + toy.dialogue.error))
	check(character.name_label.text == toy.dialogue.character and toy.dialogue.character != "", "the name over the character's head is the file's: '%s'" % character.name_label.text)
	await settle(player)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "the player stands on the grey ground, feet at y = %.3f" % player.position.y)
	await get_tree().process_frame
	check(not panel.prompt_label.visible, "no hint while %.1f m from the character" % distance(player, character))

	for k in 3:
		lines.append([])
		var stood := character.global_position
		await approach(player, character)
		await get_tree().process_frame
		check(panel.prompt_label.visible and panel.prompt_label.text == toy.ui("talk"), "within talk range the hint reads '%s'" % panel.prompt_label.text)
		await press(KEY_E)
		check(toy.talking and panel.say_label.visible, "E opened encounter %d: '%s'" % [k + 1, panel.say_label.text])
		var presses := await converse(option)
		check(not toy.talking and not panel.say_label.visible, "encounter %d ended by itself after %d presses, the words gone" % [k + 1, presses])
		check(harness.summary().contains("encounter_%d_done" % (k + 1)), "milestone encounter_%d_done recorded" % (k + 1))
		check(character.walking, "the character walks off after the goodbye")
		var frames := await glide(character)
		var moved := Vector2(stood.x, stood.z).distance_to(Vector2(character.global_position.x, character.global_position.z))
		check(not character.walking and moved >= 8.0 and moved <= 10.0, "the character stopped after %d frames, %.1f m from where it stood (8 to 10)" % [frames, moved])
		print("  encounter %d, %d lines: %s" % [k + 1, lines[k].size(), ", ".join(signatures(lines[k]))])

	# The memory: encounter 2 greets by the name given in encounter 1;
	# encounter 3 holds the player to the promise of encounter 1.
	check(lines[1].size() > 0 and lines[1][0].has("if"), "encounter 2 opens with a line picked by an encounter-1 reply: '%s'" % (lines[1][0].text if lines[1].size() > 0 else ""))
	var from_e1: Array = lines[2].filter(func(n: Dictionary) -> bool: return n.get("if", []).any(func(f) -> bool: return str(f).begins_with("e1_")))
	check(from_e1.size() > 0, "encounter 3 showed %d line(s) picked by a flag from encounter 1" % from_e1.size())
	var sigs := signatures(lines[2])
	check(E3_EXPECTED[option] in sigs, "encounter 3 reached %s" % E3_EXPECTED[option])
	var s: String = harness.summary()
	check(s.contains("memory_shown"), "milestone memory_shown recorded")
	var n_choices := 0
	for enc in lines:
		for n in enc:
			if n.has("choices"):
				n_choices += 1
	check(s.contains("  choice: %d" % n_choices), "the summary counts %d choices" % n_choices)
	var first_reply: String = lines[0].filter(func(n: Dictionary) -> bool: return n.has("choices"))[0].choices[option].text
	check(s.contains("  choice  " + first_reply), "the timeline keeps the reply's words: '%s'" % first_reply)

	# After the last encounter the character stays put and the last lines repeat.
	lines.append([])
	await approach(player, character)
	await press(KEY_E)
	var again: bool = toy.talking
	await converse(option)
	check(again and not toy.talking and not character.walking and lines[3].size() > 0, "a fourth talk gives a closing line and nobody walks: '%s'" % (lines[3][0].text if lines[3].size() > 0 else ""))

	# Leaving the tree writes the session log.
	remove_child(toy)
	check(harness.log_path != "" and FileAccess.file_exists(harness.log_path), "the session log was written: %s" % ProjectSettings.globalize_path(harness.log_path))
	toy.free()
	return lines


## "id[flags]" per line, so two plays can be compared.
static func signatures(nodes: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for n in nodes:
		out.append("%s[%s]" % [n.id, ",".join(PackedStringArray(n.get("if", [])))])
	return out


static func distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x, a.global_position.z).distance_to(Vector2(b.global_position.x, b.global_position.z))


## Let gravity put the capsule on the ground before driving it.
func settle(player: CharacterBody3D) -> void:
	player.auto_move = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame


## Drive the player toward the character, through the physics engine.
func approach(player: CharacterBody3D, character: Node3D) -> void:
	var frames := 0
	while frames < WALK_FRAMES and distance(player, character) > APPROACH:
		var to := character.global_position - player.global_position
		to.y = 0.0
		player.auto_move = to.normalized()
		await get_tree().physics_frame
		frames += 1
	player.auto_move = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(distance(player, character) <= toy.TALK_RANGE, "the player walked to the character in %d frames, now %.2f m away (talk range %.1f)" % [frames, distance(player, character), toy.TALK_RANGE])


## Wait for the character's walk to end; returns the frames it took.
func glide(character: Node3D) -> int:
	var frames := 0
	while character.walking and frames < GLIDE_FRAMES:
		await get_tree().physics_frame
		frames += 1
	return frames


## Press keys until the conversation ends: the option's number at a choice,
## E everywhere else. Returns the number of presses.
func converse(option: int) -> int:
	var presses := 0
	while toy.talking and presses < MAX_PRESSES:
		presses += 1
		if toy.node.has("choices"):
			await press(KEY_1 + mini(option, toy.node.choices.size() - 1))
		else:
			await press(KEY_E)
	return presses


## One key press and release, through the input system, as a player would.
func press(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
