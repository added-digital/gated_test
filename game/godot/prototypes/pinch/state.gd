class_name PinchState
extends Resource
## The one state of toy 4b, PINCH (rung 3, the second loop): what day it
## is, the limits, whose dream tonight is, which ideas have been reached,
## developed, built, the scraps brought home, the tally of sudden wakings
## and the memory flags. One instance lives in the controller (pinch.gd)
## and is handed to the village and the dream before they enter the tree;
## nothing else holds state. Nothing is saved.
##
## A night (SPEC-2): `target` is whose dream tonight is (set at the wall,
## or by the hub's other exit; it stays until changed, and the wall shows
## it); `reached` remembers whose idea has been reached (who -> true: the
## wall names it; a reached branch gives its idea no second time); the
## idea reached comes home as ideas_kept (on the desk the next morning)
## and the scraps as `scraps` (shape ids, the Desk's cards, at most
## KEEP_SCRAPS); scraps_carried are the ones in the dream now, at most
## CARRY_SCRAPS.
##
## A morning (day B, the Desk): the idea is developed as far as the
## outline is filled. A building idea claimed in full goes to
## ideas_claimed (plot -> idea: a scaffold today) and stands the next
## morning (ideas_built, new_day); developed weak it is a small building
## (weak_buildings[plot]). The pill is `pill_bonus` (+2 full, +1 weak,
## for every night after: night_limit()). The lantern is `lantern` (every
## room on the wall is named) or, weak, names every room of one branch
## (`revealed`, who -> rooms named from the branch's start: also what
## three scraps alone reveal, one more room at a time).
##
## Flags (memory, name -> true): built:<plot>, kept:<idea>, talked:<who>,
## reached:<who>, developed:<idea>, developed_weak:<idea>, asked:<request>,
## said:<who>:<line>, revealed:<who>. Conditions on a line or a request
## (an "if" list in data/characters.json) are flag names, or tally:N,
## tally>=N, day:N, day>=N. gauge_visible and devbar_visible are the two
## settings (H and Tab in the dream; the choice holds for the session).

const TILE := 256.0          # px: one tile of street; the dark recedes one tile per building
const BASE_LIT_TILES := 3    # tiles lit on each side of the Long House before anything stands
const CARRY_SCRAPS := 3      # scraps carried in the dream at once (SPEC-2: carry 3)
const KEEP_SCRAPS := 6       # scraps kept for the Desk at most (SPEC-2: leftovers up to six)
const FULL_PILL := 2         # the limit grows this much for every night after a pill developed in full
const WEAK_PILL := 1         # ... and this much for a weak one

var day := 1
var target := ""                        # whose dream tonight (a villager id), "" before the wall is read
var reached := {}                       # who -> true: their idea has been reached (the wall names it)
var scraps: Array[String] = []          # scrap shapes brought home, in order: the Desk's cards
var scraps_carried: Array[String] = []  # scrap shapes at the hip, in the dream now
var carry_scraps := CARRY_SCRAPS
var lucidity_limit := 8                 # the limit without a pill; night_limit() is tonight's
var pill_bonus := 0                     # the pill developed at the Desk: FULL_PILL or WEAK_PILL more, every night after
var lantern := false                    # the lantern developed in full: the wall names every room
var revealed := {}                      # who -> rooms of their branch the wall names, from its start (the reveal, the weak lantern)
var ideas_kept: Array[String] = []      # reached last night: on the desk this morning
var ideas_claimed := {}                 # plot id -> idea id, developed at the Desk today: a scaffold
var ideas_built := {}                   # plot id -> idea id, standing on the street
var weak_buildings := {}                # plot id -> true: developed weak, a small building (claimed, then built)
var tally := 0                          # nights woken suddenly: one mark each on the wall
var flags := {}                         # memory: name -> true
var desk_done_day := 0                  # the last day the Desk ran (or was walked away from)
var gauge_visible := true               # the sleep gauge is shown; H toggles it and the session remembers
var devbar_visible := true              # the dev bar (what can be done now) is shown; Tab toggles it and the session remembers


## Tiles lit on each side of the Long House: three, plus one per building standing.
func lit_tiles() -> int:
	return BASE_LIT_TILES + ideas_built.size()


## The lucidity limit tonight: the limit, plus the pill's bonus once one is developed (permanent).
func night_limit() -> int:
	return lucidity_limit + pill_bonus


## An idea kept at waking: on the desk, and remembered.
func keep(id: String) -> void:
	ideas_kept.append(id)
	set_flag("kept:%s" % id)


## A scrap brought home at waking (SPEC-2): kept for the Desk, and
## remembered; false (and dropped) past KEEP_SCRAPS of them.
func keep_scrap(shape: String) -> bool:
	if scraps.size() >= KEEP_SCRAPS:
		return false
	scraps.append(shape)
	set_flag("kept_scrap:%s" % shape)
	return true


## An idea reached in its goal room (SPEC-2): the wall names it from now on.
func reach(who: String, idea: String) -> void:
	reached[who] = true
	set_flag("reached:%s" % who)
	keep(idea)


## A building idea developed at the Desk: a scaffold on its plot today
## (standing tomorrow), a small one when developed weak.
func claim(plot: String, idea: String, weak: bool) -> void:
	ideas_claimed[plot] = idea
	if weak:
		weak_buildings[plot] = true


## The pill developed: the limit is higher for every night after, for good.
func develop_pill(weak: bool) -> void:
	pill_bonus += WEAK_PILL if weak else FULL_PILL


## One more room of a branch is known on the wall (three scraps at the Desk). Returns how many are.
func reveal(who: String, branch_rooms: int) -> int:
	revealed[who] = mini(int(revealed.get(who, 0)) + 1, branch_rooms)
	set_flag("revealed:%s" % who)
	return revealed[who]


## Every room of one branch is known (the weak lantern).
func reveal_all(who: String, branch_rooms: int) -> void:
	revealed[who] = branch_rooms
	set_flag("revealed:%s" % who)


## Whether the wall names the `index`-th room of a branch: with the lantern, every one; else as far as revealed.
func room_known(who: String, index: int) -> bool:
	return lantern or index < int(revealed.get(who, 0))


## The next morning: the day counter, and every idea developed yesterday
## standing on its plot. Returns the plots raised, in order.
func new_day() -> Array[String]:
	day += 1
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


## One condition: a flag name, or tally:N, tally>=N, day:N, day>=N.
func condition_holds(condition: String) -> bool:
	if condition.begins_with("tally>="):
		return tally >= int(condition.substr(7))
	if condition.begins_with("tally:"):
		return tally == int(condition.substr(6))
	if condition.begins_with("day>="):
		return day >= int(condition.substr(5))
	if condition.begins_with("day:"):
		return day == int(condition.substr(4))
	return flags.has(condition)


## Reads one of the toy's data/*.json files; null (and an error) if it cannot.
static func load_json(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("[pinch] cannot read %s" % path)
	return data
