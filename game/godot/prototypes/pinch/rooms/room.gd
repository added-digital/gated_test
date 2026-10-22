extends Node2D
## One screen of the dream (toy 4, PINCH): 1152 x 648 of grey boxes. A room
## scene declares its crisp and soft geometry (box.gd), its currents,
## wonders, exit and hazards (zone.gd, goat.gd), its Door (a Marker2D: where
## the dreamer appears) and its idea spawn spots (Marker2Ds under IdeaSpots;
## the dealer lays one idea on one of them, day 3). The bed room also holds
## Bed, Block and an Exit the dream keeps only when the bed is dealt early.
## A Label with the metadata `word` shows that word from rooms.json (the
## ladder's sign). The bounds (left, right, top, and the net below that
## only the asleep body touches) are built here so no room forgets them.
## The door's word (the readability pass) sits LEFT of the door at the
## floor line (DOOR_LABEL_WIDTH wide, DOOR_LABEL_GAP px short of the body,
## DOOR_LABEL_DOWN px under the door's middle), on a backing: beside the
## body, not under it, and below the sleep gauge's lowest label, so they
## never share a line. The bed's name (room_bed.tscn) is backed here too.
## Every word drawn comes from data/rooms.json, handed in as `words` by
## the dream before add_child.
##
## The second loop (SPEC-2, day A): a room may have several exits (the hub
## has ExitLeft and ExitRight), listed by exits(); each carries the branch
## it leads down in its metadata `branch` and a sign (set_sign: the zone's
## word) that the dream sets from the night's target. ScrapSpots (Marker2Ds)
## are where the dealer hangs scraps besides the IdeaSpots; the scraps
## themselves live under Scraps (scraps_holder(), made when a scene lacks
## it). A goal room holds a Sleeper (sleeper.gd), whose words are set here.

const SIZE := Vector2(1152, 648)
const WALL := 16.0
const LAYER_BOUNDS := 1
const LAYER_NET := 8
const BOUND_COLOR := Color(0.28, 0.28, 0.34)
const DOOR_LABEL_WIDTH := 72.0   # "door" is 37 px; 72 keeps the box inside a room whose door is at x 100
const DOOR_LABEL_GAP := 22.0    # px from the door's middle to the label's right end (the body is 28 wide)
const DOOR_LABEL_DOWN := 54.0   # px from the door's middle to the label's top: just under the feet, on the floor

@export var id := ""

var words: Dictionary = {}   # rooms.json "words"; set by the dream
var door_label: Label = null

@onready var door: Marker2D = $Door
@onready var exit: Area2D = _first_exit()   # the one exit, or the first of several; null once removed
@onready var ideas: Node2D = $Ideas


func _ready() -> void:
	_bound("Left", Rect2(0, 0, WALL, SIZE.y), LAYER_BOUNDS, true)
	_bound("Right", Rect2(SIZE.x - WALL, 0, WALL, SIZE.y), LAYER_BOUNDS, true)
	_bound("Top", Rect2(0, 0, SIZE.x, WALL), LAYER_BOUNDS, true)
	_bound("Net", Rect2(0, SIZE.y, SIZE.x, WALL), LAYER_NET, false)
	door_label = PinchLabel.make(word("door"), door.position + Vector2(-DOOR_LABEL_GAP - DOOR_LABEL_WIDTH, DOOR_LABEL_DOWN), DOOR_LABEL_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	door_label.name = "DoorLabel"
	add_child(door_label)
	for node in find_children("*", "", true, false):
		if "word" in node and node.word != "":
			node.set_label(word(node.word))
		elif node is Label and node.has_meta("word"):
			node.text = word(str(node.get_meta("word")))
	var bed_name: Label = get_node_or_null("Bed/Name")
	if bed_name != null:
		bed_name.set_meta("max_width", bed_name.size.x)
		PinchLabel.back(bed_name)
		PinchLabel.set_text(bed_name, word("bed"))
	var sleeper: Node2D = get_node_or_null("Sleeper")
	if sleeper != null:
		sleeper.set_words(word("asleep").format({"name": sleeper.who}), word("snore"))


## A word from rooms.json; the key itself when the file lacks it.
func word(key: String) -> String:
	return str(words.get(key, key))


func bed() -> ColorRect:
	return get_node_or_null("Bed") as ColorRect


func block() -> StaticBody2D:
	return get_node_or_null("Block") as StaticBody2D


## No way on from here (the bed room dealt last): every exit zone goes.
func remove_exit() -> void:
	for zone in exits():
		remove_child(zone)
		zone.queue_free()
	exit = null


## One exit goes (the hub's unused side); `exit` is the first that is left.
func remove_exit_named(exit_name: String) -> void:
	var zone: Area2D = get_node_or_null(exit_name)
	if zone != null and zone.role == "exit":
		remove_child(zone)
		zone.queue_free()
	exit = _first_exit()


## The exit zones of this room, in scene order (none once removed).
func exits() -> Array[Area2D]:
	var zones: Array[Area2D] = []
	for child in get_children():
		if child is Area2D and "role" in child and child.role == "exit":
			zones.append(child)
	return zones


func _first_exit() -> Area2D:
	var zones := exits()
	return zones[0] if not zones.is_empty() else null


## The exit's sign (SPEC-2: whose dream lies that way) and the branch it leads down.
func set_sign(exit_name: String, text: String, branch: String) -> void:
	var zone: Area2D = get_node_or_null(exit_name)
	if zone == null:
		return
	zone.set_label(text)
	zone.set_meta("branch", branch)


## The sleeping villager of a goal room, or null.
func sleeper() -> Node2D:
	return get_node_or_null("Sleeper") as Node2D


## Where the scraps lie: the Scraps node, made here when the scene has none.
func scraps_holder() -> Node2D:
	var holder: Node2D = get_node_or_null("Scraps")
	if holder == null:
		holder = Node2D.new()
		holder.name = "Scraps"
		add_child(holder)
	return holder


## Where ideas may lie in this room, in order.
func idea_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var holder: Node2D = get_node_or_null("IdeaSpots")
	if holder != null:
		for marker in holder.get_children():
			if marker is Marker2D:
				spots.append(marker.position)
	return spots


## Where the dealer may hang scraps besides the idea spots, in order.
func scrap_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var holder: Node2D = get_node_or_null("ScrapSpots")
	if holder != null:
		for marker in holder.get_children():
			if marker is Marker2D:
				spots.append(marker.position)
	return spots


## The door's word, as a box in the room.
func door_label_rect() -> Rect2:
	return Rect2(door_label.position, Vector2(DOOR_LABEL_WIDTH, PinchLabel.LINE))


func _bound(bound_name: String, rect: Rect2, layer: int, drawn: bool) -> void:
	var wall := StaticBody2D.new()
	wall.name = bound_name
	wall.position = rect.position + rect.size / 2.0
	wall.collision_layer = layer
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.add_child(shape)
	if drawn:
		var color := ColorRect.new()
		color.position = -rect.size / 2.0
		color.size = rect.size
		color.color = BOUND_COLOR
		wall.add_child(color)
	add_child(wall)
