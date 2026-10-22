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
## from data/village.json "wall", the names from data/characters.json,
## data/ideas.json and data/rooms.json, handed in by the village (setup).
## refresh(state) redraws; the readers (shown_branches, goal_text,
## row_room_names, progress_text, ...) are for the designer's eye and the
## tests. `position` is the map's top-left corner.
##
## Map knowledge (day B): a room box the state knows (state.room_known:
## the lantern names every room; three scraps at the Desk name a branch's
## rooms from its start) is drawn wide (NAMED_BOX) with the room's name
## inside; the rest stay blank boxes.
##
## The outline's progress (day C): a reached idea whose outline waits on
## the desk (state.ideas_kept) has its count after its name ("2 / 4",
## village.json wall.progress, from state.outline_count); developed, the
## name stands alone.
##
## The feel (day C), drawn only, every number a constant below: with a
## target chosen, the chosen row is drawn at full brightness and the
## others at ROW_DIM (before any target every row rests at ROW_REST); a
## change eases each row to its level over BRIGHTEN seconds
## (row_brightness); the goal box of a branch not yet reached (the
## question mark's) pulses slowly, PULSE either way about its middle over
## PULSE_PERIOD seconds (goal_pulse_scale); a reached one stands still.

const BOX := Vector2(22, 14)      # px: one room on the map, unknown
const NAMED_BOX := Vector2(92, 14)   # px: a room the map names
const GAP := 8.0                  # px between boxes
const ROW := 24.0                 # px between rows
const NAME_WIDTH := 56.0          # px: the villager's name at a row's left
const HUB_WIDTH := 110.0          # px: the hub's word beside its box
const GOAL_WIDTH := 120.0         # px: the question mark or the idea's name after the goal box
const PROGRESS_WIDTH := 56.0      # px: the outline's count after the idea's name
const NOTE_WIDTH := 200.0
const TONIGHT_WIDTH := 170.0
const FONT := 11
const ROOM_FONT := 10
const STEM := 2.0                 # px: the line from the hub down to the rows
const ROW_REST := 0.85            # every row's brightness before a target is chosen
const ROW_DIM := 0.5              # the rows not chosen, once one is
const BRIGHTEN := 0.4             # s a row takes to brighten or dim when the target changes
const PULSE := 0.12               # the question mark's box swells and shrinks this much either way
const PULSE_PERIOD := 2.5         # s per swing
const BOX_COLOR := Color(0.74, 0.74, 0.78)
const NAMED_COLOR := Color(0.86, 0.86, 0.9)
const HUB_COLOR := Color(0.86, 0.86, 0.88)
const GOAL_COLOR := Color.WHITE
const REACHED_COLOR := Color(1.0, 0.9, 0.45)
const LINE_COLOR := Color(0.6, 0.6, 0.64)

var words: Dictionary = {}        # village.json "wall"
var branches: Array = []          # branches.json "branches", in order
var names := {}                   # who -> name
var idea_names := {}              # idea id -> name
var room_names := {}              # room id -> name (rooms.json)
var hub_box: ColorRect = null
var hub_label: Label = null
var tonight_label: Label = null
var note_label: Label = null
var rows := {}                    # who -> Node2D (the row drawn for that branch)
var rows_node: Node2D = null
var _width := 0.0                 # px: the widest row drawn
var _levels := {}                 # who -> the row's brightness now (ROW_DIM .. 1)
var _targets := {}                # who -> the brightness the row eases to
var _time := 0.0


## Before add_child: the words and the names this map draws with.
func setup(wall_words: Dictionary, branch_list: Array, villager_names: Dictionary, idea_name_map: Dictionary, room_name_map: Dictionary = {}) -> void:
	words = wall_words
	branches = branch_list
	names = villager_names
	idea_names = idea_name_map
	room_names = room_name_map


func _ready() -> void:
	var hub_x := NAME_WIDTH + GAP
	hub_box = _box(self, Vector2(hub_x, (PinchLabel.LINE - BOX.y) / 2.0), BOX, HUB_COLOR)
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


func _process(delta: float) -> void:
	_time += delta
	for who in rows:
		var level: float = _levels.get(who, 1.0)
		var to: float = _targets.get(who, 1.0)
		level = move_toward(level, to, delta * (1.0 - ROW_DIM) / BRIGHTEN)   # dim to full in BRIGHTEN seconds
		_levels[who] = level
		var v := row_brightness(who)
		(rows[who] as Node2D).modulate = Color(v, v, v, 1.0)
		var goal: ColorRect = (rows[who] as Node2D).get_node_or_null("Goal")
		if goal != null:
			goal.scale = Vector2.ONE * goal_pulse_scale(who)


## A word from village.json "wall"; the key itself when the file lacks it.
func word(key: String) -> String:
	return str(words.get(key, key))


## Redrawn from the state: the rows of the talked-to villagers, the room
## boxes named as far as known, the goal boxes named or not with the
## outline's progress, the note, tonight's target, each row's brightness.
func refresh(state: PinchState) -> void:
	for row in rows_node.get_children():
		rows_node.remove_child(row)
		row.queue_free()
	rows = {}
	_width = NAME_WIDTH + GAP + BOX.x + 6.0 + HUB_WIDTH + 8.0 + TONIGHT_WIDTH
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
			var room_id := str(room_ids[i])
			var known: bool = state.room_known(who, i)
			var size := NAMED_BOX if known else BOX
			var box := _box(row, Vector2(x, (PinchLabel.LINE - size.y) / 2.0), size, NAMED_COLOR if known else BOX_COLOR)
			box.name = "Room%d" % (i + 1)
			box.set_meta("room", room_id)
			box.set_meta("known", known)
			if known:
				var room_label := PinchLabel.make(str(room_names.get(room_id, room_id)), Vector2(x, 0.0), size.x, HORIZONTAL_ALIGNMENT_CENTER, ROOM_FONT, false)
				room_label.name = "RoomLabel%d" % (i + 1)
				room_label.set_meta("room", room_id)
				row.add_child(room_label)
			x += size.x + GAP
		var reached: bool = state.reached.get(who, false)
		var goal := _box(row, Vector2(x, (PinchLabel.LINE - BOX.y) / 2.0), BOX, REACHED_COLOR if reached else GOAL_COLOR)
		goal.name = "Goal"
		goal.pivot_offset = BOX / 2.0   # the pulse swells about its middle
		goal.set_meta("pulses", not reached)
		var idea := str(branch.get("idea", ""))
		var goal_text := str(idea_names.get(idea, idea)) if reached else word("unknown")
		var goal_label := PinchLabel.make(goal_text, Vector2(x + BOX.x + 6.0, 0.0), GOAL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
		goal_label.name = "GoalLabel"
		row.add_child(goal_label)
		var progress := ""
		if reached and state.ideas_kept.has(idea):
			progress = word("progress").format({"filled": state.outline_count(idea), "total": branch.get("slots", []).size()})
		var progress_label := PinchLabel.make(progress, Vector2(x + BOX.x + 6.0 + GOAL_WIDTH + 4.0, 0.0), PROGRESS_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, FONT)
		progress_label.name = "Progress"
		progress_label.visible = progress != ""
		row.add_child(progress_label)
		rows_node.add_child(row)
		rows[who] = row
		_width = maxf(_width, x + BOX.x + 6.0 + GOAL_WIDTH + 4.0 + PROGRESS_WIDTH)
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
	# Each row's brightness: the chosen one full, the rest dim; all at rest with no target.
	for who in rows:
		var level := ROW_REST
		if tonight != "":
			level = 1.0 if who == state.target else ROW_DIM
		_targets[who] = level
		if not _levels.has(who):
			_levels[who] = level   # a new row starts where it belongs; a change eases
		var v := row_brightness(who)
		(rows[who] as Node2D).modulate = Color(v, v, v, 1.0)


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


## The outline's progress after a branch's idea ("2 / 4"); "" before the idea is reached and once it is developed.
func progress_text(who: String) -> String:
	if not rows.has(who):
		return ""
	var label: Label = rows[who].get_node("Progress")
	return label.text if label.visible else ""


## How bright a branch's row is drawn now: 1 for the chosen one, ROW_DIM
## for the rest once a target is chosen, ROW_REST before; eased.
func row_brightness(who: String) -> float:
	return float(_levels.get(who, 1.0))


## The brightness a branch's row is easing to.
func row_brightness_target(who: String) -> float:
	return float(_targets.get(who, 1.0))


## The scale of a branch's goal box now: swinging 1 - PULSE .. 1 + PULSE
## while the branch is unreached (the question mark); 1 once reached.
func goal_pulse_scale(who: String) -> float:
	if not rows.has(who):
		return 1.0
	var goal: ColorRect = rows[who].get_node("Goal")
	if not goal.get_meta("pulses", false):
		return 1.0
	return 1.0 + PULSE * sin(TAU * _time / PULSE_PERIOD)


## The room boxes of a branch, in order (their room ids).
func row_rooms(who: String) -> Array[String]:
	var ids: Array[String] = []
	if rows.has(who):
		for child in rows[who].get_children():
			if child.has_meta("room") and child is ColorRect:
				ids.append(str(child.get_meta("room")))
	return ids


## What the room boxes of a branch say, in order: the room's name where
## the map knows it, "" for a blank box.
func row_room_names(who: String) -> Array[String]:
	var texts: Array[String] = []
	if not rows.has(who):
		return texts
	var row: Node2D = rows[who]
	var i := 0
	for child in row.get_children():
		if child.has_meta("room") and child is ColorRect:
			i += 1
			var label: Label = row.get_node_or_null("RoomLabel%d" % i)
			texts.append(label.text if label != null else "")
	return texts


## The note shown when no branch is drawn yet ("" otherwise).
func note_text() -> String:
	return note_label.text if note_label.visible else ""


## "Tonight: Bo's dream", or "" with no target.
func tonight_text() -> String:
	return tonight_label.text if tonight_label.visible else ""


## The map's extent, from its top-left corner.
func size() -> Vector2:
	return Vector2(_width, ROW * (rows.size() + 1) + PinchLabel.LINE)


func _box(holder: Node, at: Vector2, extent: Vector2, color: Color) -> ColorRect:
	return _rect(holder, Rect2(at, extent), color)


func _rect(holder: Node, rect: Rect2, color: Color) -> ColorRect:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	holder.add_child(box)
	return box
