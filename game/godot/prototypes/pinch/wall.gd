extends Node2D
## The map on the Long House wall (toy 4b, PINCH, SPEC-2 day A): the dream
## as far as the dreamer knows it. The hub (the Long House's own
## reflection) at the top, and under it one row per villager talked to
## (flag talked:<who>): their name, then their branch as a line of room
## boxes (data/branches.json, in order) ending in the goal box, which
## shows a question mark until their idea is reached (state.reached) and
## the idea's name after. A stem joins the hub to every row. With no row
## yet, the note "talk to someone first" stands where the first row would.
## The target (state.target) is written beside the hub ("Tonight: Bo's
## dream"). Grey boxes and backed labels (PinchLabel); every word comes
## from data/village.json "wall", the names from data/characters.json and
## data/ideas.json, handed in by the village (setup). refresh(state)
## redraws; the readers (shown_branches, goal_text, ...) are for the
## designer's eye and the tests. `position` is the map's top-left corner.

const BOX := Vector2(22, 14)      # px: one room on the map
const GAP := 8.0                  # px between boxes
const ROW := 24.0                 # px between rows
const NAME_WIDTH := 56.0          # px: the villager's name at a row's left
const HUB_WIDTH := 110.0          # px: the hub's word beside its box
const GOAL_WIDTH := 120.0         # px: the question mark or the idea's name after the goal box
const NOTE_WIDTH := 200.0
const TONIGHT_WIDTH := 170.0
const FONT := 11
const STEM := 2.0                 # px: the line from the hub down to the rows
const BOX_COLOR := Color(0.74, 0.74, 0.78)
const HUB_COLOR := Color(0.86, 0.86, 0.88)
const GOAL_COLOR := Color.WHITE
const REACHED_COLOR := Color(1.0, 0.9, 0.45)
const LINE_COLOR := Color(0.6, 0.6, 0.64)

var words: Dictionary = {}        # village.json "wall"
var branches: Array = []          # branches.json "branches", in order
var names := {}                   # who -> name
var idea_names := {}              # idea id -> name
var hub_box: ColorRect = null
var hub_label: Label = null
var tonight_label: Label = null
var note_label: Label = null
var rows := {}                    # who -> Node2D (the row drawn for that branch)
var rows_node: Node2D = null


## Before add_child: the words and the names this map draws with.
func setup(wall_words: Dictionary, branch_list: Array, villager_names: Dictionary, idea_name_map: Dictionary) -> void:
	words = wall_words
	branches = branch_list
	names = villager_names
	idea_names = idea_name_map


func _ready() -> void:
	var hub_x := NAME_WIDTH + GAP
	hub_box = _box(self, Vector2(hub_x, (PinchLabel.LINE - BOX.y) / 2.0), HUB_COLOR)
	hub_box.name = "Hub"
	hub_label = PinchLabel.make(word("hub"), Vector2(hub_x + BOX.x + 6.0, 0.0), HUB_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
	hub_label.name = "HubLabel"
	add_child(hub_label)
	tonight_label = PinchLabel.make("", Vector2(hub_x + BOX.x + 6.0 + HUB_WIDTH + 8.0, 0.0), TONIGHT_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
	tonight_label.name = "Tonight"
	add_child(tonight_label)
	note_label = PinchLabel.make(word("talk_first"), Vector2(hub_x, ROW), NOTE_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
	note_label.name = "Note"
	add_child(note_label)
	rows_node = Node2D.new()
	rows_node.name = "Rows"
	add_child(rows_node)


## A word from village.json "wall"; the key itself when the file lacks it.
func word(key: String) -> String:
	return str(words.get(key, key))


## Redrawn from the state: the rows of the talked-to villagers, the goal
## boxes named or not, the note, tonight's target.
func refresh(state: PinchState) -> void:
	for row in rows_node.get_children():
		rows_node.remove_child(row)
		row.queue_free()
	rows = {}
	var row_index := 0
	for branch in branches:
		var who := str(branch.get("who", ""))
		if not state.has_flag("talked:%s" % who):
			continue
		row_index += 1
		var row := Node2D.new()
		row.name = "Branch_%s" % who
		row.position = Vector2(0.0, ROW * row_index)
		row.set_meta("who", who)
		var name_label := PinchLabel.make(str(names.get(who, who)), Vector2.ZERO, NAME_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT, FONT)
		name_label.name = "Name"
		row.add_child(name_label)
		var x := NAME_WIDTH + GAP
		_rect(row, Rect2(x - GAP + 2.0, PinchLabel.LINE / 2.0 - STEM / 2.0, GAP - 2.0, STEM), LINE_COLOR)   # the tick from the stem
		var room_ids: Array = branch.get("rooms", [])
		for i in room_ids.size():
			var box := _box(row, Vector2(x, (PinchLabel.LINE - BOX.y) / 2.0), BOX_COLOR)
			box.name = "Room%d" % (i + 1)
			box.set_meta("room", str(room_ids[i]))
			x += BOX.x + GAP
		var reached: bool = state.reached.get(who, false)
		var goal := _box(row, Vector2(x, (PinchLabel.LINE - BOX.y) / 2.0), REACHED_COLOR if reached else GOAL_COLOR)
		goal.name = "Goal"
		var idea := str(branch.get("idea", ""))
		var goal_text := str(idea_names.get(idea, idea)) if reached else word("unknown")
		var goal_label := PinchLabel.make(goal_text, Vector2(x + BOX.x + 6.0, 0.0), GOAL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
		goal_label.name = "GoalLabel"
		row.add_child(goal_label)
		rows_node.add_child(row)
		rows[who] = row
	note_label.visible = rows.is_empty()
	var stem: ColorRect = get_node_or_null("Stem")
	if stem != null:
		remove_child(stem)
		stem.queue_free()
	if not rows.is_empty():
		var top := (PinchLabel.LINE + BOX.y) / 2.0
		stem = _rect(self, Rect2(NAME_WIDTH + 2.0, top, STEM, ROW * row_index + PinchLabel.LINE / 2.0 - top), LINE_COLOR)
		stem.name = "Stem"
	var tonight := ""
	if state.target != "" and rows.has(state.target):
		tonight = word("tonight").format({"name": str(names.get(state.target, state.target))})
	PinchLabel.set_text(tonight_label, tonight)
	tonight_label.visible = tonight != ""


# --- readers ---------------------------------------------------------------------

## The villagers whose branches are drawn, top to bottom.
func shown_branches() -> Array[String]:
	var whos: Array[String] = []
	for row in rows_node.get_children():
		whos.append(str(row.get_meta("who")))
	return whos


func hub_shown() -> bool:
	return hub_box != null and hub_box.visible


## What the goal box of a branch says: the question mark, or the idea's name once reached.
func goal_text(who: String) -> String:
	if not rows.has(who):
		return ""
	return (rows[who].get_node("GoalLabel") as Label).text


## The room boxes of a branch, in order (their room ids).
func row_rooms(who: String) -> Array[String]:
	var ids: Array[String] = []
	if rows.has(who):
		for child in rows[who].get_children():
			if child.has_meta("room"):
				ids.append(str(child.get_meta("room")))
	return ids


## The note shown when no branch is drawn yet ("" otherwise).
func note_text() -> String:
	return note_label.text if note_label.visible else ""


## "Tonight: Bo's dream", or "" with no target.
func tonight_text() -> String:
	return tonight_label.text if tonight_label.visible else ""


## The map's extent, from its top-left corner.
func size() -> Vector2:
	return Vector2(NAME_WIDTH + GAP + BOX.x + 6.0 + HUB_WIDTH + 8.0 + TONIGHT_WIDTH, ROW * (rows.size() + 1) + PinchLabel.LINE)


func _box(holder: Node, at: Vector2, color: Color) -> ColorRect:
	return _rect(holder, Rect2(at, BOX), color)


func _rect(holder: Node, rect: Rect2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	holder.add_child(box)
	return box
