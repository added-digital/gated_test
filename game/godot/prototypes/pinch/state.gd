class_name PinchState
extends Resource
## The one state of toy 4, PINCH (rung 3): what day it is, the limits, which
## ideas are carried, kept, claimed, built or small things, the tally of
## sudden wakings, the pills, and the memory flags. One instance lives in
## the controller (pinch.gd) and is handed to the village and the dream
## before they enter the tree; nothing else holds state. Nothing is saved.
##
## An idea's day (day 4): kept at waking (ideas_kept, on the table) -> told
## at breakfast: claimed by its owner (ideas_claimed, plot -> idea: a
## scaffold today) -> standing the next morning (ideas_built, new_day), or
## nobody's (small_things: a bench, a sign, a lantern post the same day).
##
## Flags (memory, name -> true): told_wrong, built:<plot>, kept:<idea>,
## talked:<who>, asked:<request>, said:<who>:<line>, made:pills. Conditions
## on a line or a request (an "if" list in data/characters.json) are flag
## names, or tally:N, tally>=N, day:N, day>=N, has_pills (holds()).
## gauge_visible (day 5) is the one setting: H in the dream toggles the
## sleep gauge and the choice holds for the rest of the session.

const TILE := 256.0          # px: one tile of street; the dark recedes one tile per building
const BASE_LIT_TILES := 3    # tiles lit on each side of the Long House before anything stands
const PILL_BONUS := 2        # the lucidity limit tonight is this much higher with a pill
const HAT_CARRY := 3         # ideas under the taller hat (Bo's request)

var day := 1
var lucidity_limit := 8      # the limit without a pill; night_limit() is tonight's
var carry_limit := 2         # 3 with the taller hat (day 4: Bo's request, the morning his loft stands)
var ideas_carried: Array[String] = []   # under the hat, in the dream now
var ideas_kept: Array[String] = []      # carried up and kept at waking, not yet told: on the table
var ideas_claimed := {}                 # plot id -> idea id, claimed at breakfast today: a scaffold
var ideas_built := {}                   # plot id -> idea id, standing on the street
var small_things: Array[String] = []    # idea ids nobody claimed: a bench, a sign, a lantern post
var tally := 0                          # nights woken suddenly: one mark each on the wall
var flags := {}                         # memory: name -> true
var has_pills := false                  # made at the stove shed after Tove's request
var pill_tonight := false               # a pill taken at the bunk: the limit is PILL_BONUS higher this night only
var breakfast_done_day := 0             # the last day breakfast happened (or was walked away from)
var gauge_visible := true               # the sleep gauge is shown; H toggles it and the session remembers (day 5)


## Tiles lit on each side of the Long House: three, plus one per building standing.
func lit_tiles() -> int:
	return BASE_LIT_TILES + ideas_built.size()


## The lucidity limit tonight: the limit, plus the pill's bonus if one was taken.
func night_limit() -> int:
	return lucidity_limit + (PILL_BONUS if pill_tonight else 0)


## An idea kept at waking: on the table, and remembered.
func keep(id: String) -> void:
	ideas_kept.append(id)
	set_flag("kept:%s" % id)


## The next morning: the day counter, the pill worn off, and every idea
## claimed yesterday standing on its plot. Returns the plots raised, in order.
func new_day() -> Array[String]:
	day += 1
	pill_tonight = false
	var raised: Array[String] = []
	for plot in ideas_claimed.keys():
		ideas_built[plot] = ideas_claimed[plot]
		set_flag("built:%s" % plot)
		raised.append(str(plot))
	ideas_claimed.clear()
	return raised


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true


func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


## True when every condition in the list holds (an empty list holds).
func holds(conditions: Array) -> bool:
	for condition in conditions:
		if not condition_holds(str(condition)):
			return false
	return true


## True when any condition in the list holds (an empty list does not).
func holds_any(conditions: Array) -> bool:
	for condition in conditions:
		if condition_holds(str(condition)):
			return true
	return false


## One condition: a flag name, or tally:N, tally>=N, day:N, day>=N, has_pills.
func condition_holds(condition: String) -> bool:
	if condition.begins_with("tally>="):
		return tally >= int(condition.substr(7))
	if condition.begins_with("tally:"):
		return tally == int(condition.substr(6))
	if condition.begins_with("day>="):
		return day >= int(condition.substr(5))
	if condition.begins_with("day:"):
		return day == int(condition.substr(4))
	if condition == "has_pills":
		return has_pills
	return flags.has(condition)


## Reads one of the toy's data/*.json files; null (and an error) if it cannot.
static func load_json(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("[pinch] cannot read %s" % path)
	return data
