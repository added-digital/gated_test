extends CanvasLayer
## The grey-box text layer every toy shares: one sentence at the bottom of the
## screen (say), up to three numbered choices (choices, answered by the
## chosen signal), and a small hint line (prompt). Default theme, a dark box
## behind the words so they can be read over the world, nothing more.
## The words themselves come from the toy's text file, never from here.
##
## API (the toy phases use it exactly):
##   say(text)          the sentence; "" hides it
##   choices(options)   shows the options numbered 1..3; the player presses
##                      1/2/3 (project.godot: choice_1..choice_3) or clicks;
##                      chosen(index) is emitted once and the options go away
##   prompt(text)       a small hint line under the sentence ("E to talk"); "" hides it
##   hide_all()         clears the three
##
## Clicking needs a visible mouse: the player (scripts/player.gd) captures it
## and Esc frees it. The number keys work either way.

signal chosen(index: int)

const MAX_KEYS := 3   # choice_1..choice_3 exist in project.godot; a 4th option is click-only

@onready var say_label: Label = $Root/Bottom/Stack/Say
@onready var choice_box: VBoxContainer = $Root/Bottom/Stack/Choices
@onready var prompt_label: Label = $Root/Bottom/Stack/Prompt

var _options: Array[String] = []


func say(text: String) -> void:
	say_label.text = text
	say_label.visible = text != ""


func prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func choices(options: Array[String]) -> void:
	_clear_choices()
	_options = options.duplicate()
	for i in _options.size():
		var b := Button.new()
		b.text = ("%d.  %s" % [i + 1, _options[i]]) if i < MAX_KEYS else _options[i]
		b.focus_mode = Control.FOCUS_NONE   # no keyboard focus: the number keys and the mouse do everything
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_pick.bind(i))
		choice_box.add_child(b)
	choice_box.visible = not _options.is_empty()


func hide_all() -> void:
	say("")
	prompt("")
	_clear_choices()


func _clear_choices() -> void:
	_options = []
	for c in choice_box.get_children():
		choice_box.remove_child(c)
		c.queue_free()
	choice_box.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _options.is_empty():
		return
	for i in mini(_options.size(), MAX_KEYS):
		if event.is_action_pressed("choice_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			_pick(i)
			return


func _pick(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	_clear_choices()   # before the signal, so a handler may call choices() again at once
	chosen.emit(index)
