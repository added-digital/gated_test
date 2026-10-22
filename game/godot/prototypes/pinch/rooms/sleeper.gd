extends Node2D
## A villager asleep in their goal room (toy 4b, PINCH, SPEC-2 day A): a
## large grey capsule, twice the dreamer, lying down on the floor, with
## their name and a snore mark over it, both from the data files (the name
## from characters.json through the dream's `names`, the snore and the
## "asleep" line from rooms.json through the room's `words`). Drawn only:
## no collision, so the dreamer walks past. `position` is the middle of
## the floor under it; `who` is the villager's id. The feel (day C): at a
## reach the snore mark grows once (grow_snore: to 1 + SNORE_GROW and back
## over the seconds given; snore_scale()).

const SIZE := Vector2(112, 56)       # px: lying down, twice the dreamer's 28 x 56 turned on its side
const BODY := Color(0.66, 0.66, 0.68)
const EYE := Color(0.12, 0.12, 0.14)
const LABEL_WIDTH := 160.0
const SNORE_RISE := 2.0              # px/s the snore mark drifts up before it starts again
const SNORE_LOOP := 3.0              # s per drift
const SNORE_GROW := 0.8              # the snore mark grows to 1 + this, once, at a reach

@export var who := ""

var name_label: Label = null
var snore_label: Label = null
var _time := 0.0
var _grow_left := 0.0                # s of the snore's growth left; 0 when still
var _grow_total := 0.0


func _ready() -> void:
	var body := Polygon2D.new()
	body.name = "Body"
	body.color = BODY
	body.polygon = _stadium(SIZE)
	body.position = Vector2(-SIZE.x / 2.0, -SIZE.y)
	add_child(body)
	for i in 2:   # shut eyes: two short lines at the head end (the left)
		var eye := ColorRect.new()
		eye.name = "EyeL" if i == 0 else "EyeR"
		eye.color = EYE
		eye.size = Vector2(6, 1)
		eye.position = Vector2(-SIZE.x / 2.0 + 14.0, -SIZE.y + 20.0 + i * 10.0)
		add_child(eye)
	name_label = PinchLabel.make("", Vector2(-LABEL_WIDTH / 2.0, -SIZE.y - 30.0 - PinchLabel.LINE), LABEL_WIDTH)
	name_label.name = "Name"
	add_child(name_label)
	snore_label = PinchLabel.make("", Vector2(-LABEL_WIDTH / 2.0 + 40.0, -SIZE.y - 56.0 - PinchLabel.LINE), LABEL_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, 14)
	snore_label.name = "Snore"
	snore_label.pivot_offset = Vector2(LABEL_WIDTH / 2.0, PinchLabel.LINE)   # grows about its middle, from its baseline
	add_child(snore_label)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, SNORE_LOOP)
	snore_label.position.y = -SIZE.y - 56.0 - PinchLabel.LINE - _time * SNORE_RISE
	if _grow_left > 0.0:
		_grow_left = maxf(_grow_left - delta, 0.0)
	snore_label.scale = Vector2.ONE * snore_scale()


## The snore mark grows once, to 1 + SNORE_GROW and back, over `seconds` (the reach).
func grow_snore(seconds: float) -> void:
	_grow_left = seconds
	_grow_total = seconds


## The snore mark's scale now: 1 at rest, up to 1 + SNORE_GROW in the middle of its growth.
func snore_scale() -> float:
	if _grow_left <= 0.0 or _grow_total <= 0.0:
		return 1.0
	return 1.0 + SNORE_GROW * sin(PI * (1.0 - _grow_left / _grow_total))


## The words: the "asleep" line with the villager's name, and the snore mark.
func set_words(asleep_line: String, snore: String) -> void:
	PinchLabel.set_text(name_label, asleep_line)
	PinchLabel.set_text(snore_label, snore)


## The capsule's box, in the room.
func rect() -> Rect2:
	return Rect2(position - Vector2(SIZE.x / 2.0, SIZE.y), SIZE)


## The points of a capsule (a stadium) `size` big lying down, its top-left at the origin.
func _stadium(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := size.y / 2.0
	var steps := 8
	for i in steps + 1:   # the right half-circle, top to bottom
		var a := -PI / 2.0 + PI * i / steps
		points.append(Vector2(size.x - r, r) + Vector2(cos(a), sin(a)) * r)
	for i in steps + 1:   # the left half-circle, bottom to top
		var a := PI / 2.0 + PI * i / steps
		points.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
	return points
