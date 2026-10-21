extends Node3D
## Toy 1, Remember (rung 3): one character who remembers what you said.
## Walk up to them (TALK_RANGE) and the hint says E to talk. E opens the
## conversation in dialogue.json; 1, 2, 3 pick a reply; E moves to the next
## line. Every reply sets flags, and later lines are picked by those flags
## (dialogue.gd). An encounter ends at a node with "end": the character
## walks to the next spot and talking again starts the next encounter; once
## all are done, the file's "after" line plays. The harness gets every choice,
## one milestone per encounter and "memory_shown" the first time a line
## picked by an earlier choice plays.

signal line_shown(node: Dictionary)   # every line as it appears (tests listen)

const DIALOGUE := preload("res://prototypes/remember/dialogue.gd")
const TALK_RANGE := 2.0   # m, player to character, to talk

var dialogue := DIALOGUE.new()
var flags := {}        # flag -> true: everything the player has said that matters
var encounter := 0     # how many encounters are done
var talking := false
var node := {}         # the line on screen; {} between conversations

@onready var player: CharacterBody3D = $Player
@onready var character: Node3D = $Character
@onready var panel: CanvasLayer = $TextPanel
@onready var harness: Node = $Harness


func _ready() -> void:
	harness.start("remember")
	if not dialogue.load_file():
		push_warning("dialogue.json: " + dialogue.error)
	character.set_display_name(dialogue.character)
	panel.chosen.connect(_on_chosen)


func _process(_delta: float) -> void:
	if talking:
		return   # the conversation sets its own hints
	if character.walking:
		panel.prompt(ui("walking"))
	else:
		panel.prompt(ui("talk") if near() else "")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if talking:
		if not node.has("choices"):   # with choices up, only 1/2/3 answer
			_advance()
	elif near() and not character.walking:
		_begin()


func near() -> bool:
	var a := player.global_position
	var b := character.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= TALK_RANGE


func ui(key: String) -> String:
	return dialogue.ui.get(key, "")


func all_done() -> bool:
	return encounter >= dialogue.encounters.size()


func _begin() -> void:
	talking = true
	harness.action("talk", "after" if all_done() else "encounter %d" % (encounter + 1))
	_show(dialogue.after if all_done() else dialogue.encounters[encounter].start)


func _show(id: String) -> void:
	node = dialogue.node_for(id, flags)
	if node.is_empty():
		push_warning("dialogue.json: no node '%s' fits the flags %s" % [id, flags.keys()])
		_finish()
		return
	panel.say("%s: %s" % [node.get("who", dialogue.character), node.text])
	if dialogue.is_memory(node):
		harness.milestone("memory_shown")
	line_shown.emit(node)
	if node.has("choices"):
		var options: Array[String] = []
		for c in node.choices:
			options.append(c.text)
		panel.choices(options)
		panel.prompt(ui("choose"))
	else:
		panel.prompt(ui("continue"))


func _advance() -> void:
	if node.get("end", false):
		_finish()
	else:
		_show(node.next)


func _on_chosen(index: int) -> void:
	var choice: Dictionary = node.choices[index]
	harness.action("choice", choice.text)
	for f in choice.get("set", []):
		flags[f] = true
	_show(choice.next)


func _finish() -> void:
	talking = false
	node = {}
	panel.hide_all()
	if all_done():
		return   # the "after" line: nothing to count, nowhere to go
	harness.milestone("encounter_%d_done" % (encounter + 1))
	var e: Dictionary = dialogue.encounters[encounter]
	if e.has("then_walk_to"):
		character.walk_to(Vector3(e.then_walk_to[0], 0.0, e.then_walk_to[1]))
	encounter += 1
