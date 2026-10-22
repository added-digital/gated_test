class_name PinchDriver
extends Node
## The scripted player of toy 4b, PINCH: drives one dream
## (prototypes/pinch/dream.tscn, alone or inside pinch.tscn) through a
## night room by room, as a person would, through the input actions
## (move_left, move_right, pinch, jump) and the dream's own acts
## (grab_scrap, set_down_scrap, reach, self_pinch, lie_down), so the
## balance test and the four-night test can measure what a night costs.
## Two modes:
##   competent  no mistakes: ride the currents asleep, pinch only over a
##              floor within a body's drop, take the scraps on the way as
##              long as the hip has room and effective stays SCRAP_MARGIN
##              under the limit, take the wonders on the way (still,
##              asleep), reach the idea.
##   clumsy     the same route with one hard fall in every room that has a
##              drop, one wrong pinch (over a gap or the water) per night,
##              and one set-down (a scrap set down and picked up again)
##              per night; every scrap in reach is taken.
## A night (SPEC-2) is the hub, a branch, a goal room. In the hub the
## driver takes the scraps in reach and walks into the exit whose sign is
## the target's (the right one); with no exit (no target) it pinches
## itself awake. In the goal room the driver takes the quiet spot (asleep)
## and reaches the idea (E pinched): the night ends "reached"; on a branch
## already reached (day B: two scraps where the idea was, no idea) it
## takes what it can and pinches itself awake. play_night() returns what
## happened; `did` is the list of the driver's moves, for reading a night
## back. play_night's `end` is one of "reached", "self" (the self-pinch),
## "bed" (the first loop's bed room, dealt by hand), "woke" or "stuck",
## and `carried` counts the scraps. Every room routine stops as soon as
## the frame is closing or the night is over. Ideas are never taken (day
## B: the first loop's hat is gone); the first loop's rooms (the tutorial,
## the ladder, the bed) are still played when dealt by hand.

const SETTLE := 20          # frames for a body to land and the input to flush
const ROOM_FRAMES := 2400   # 40 s: a room still in play after its routine and this is a stuck driver
const RIDE_FRAMES := 720    # 12 s: longer than any goat's round (8.1 s)
const DRIFT_FRAMES := 600   # 10 s: longer than any drift here
const STILL_FRAMES := 190   # 3 s still in a spot, and a few frames over
const TAP := 10             # frames of pinch per feathering tap: a drop of about 19 px, never a hard fall
const SCRAP_MARGIN := 2     # a scrap is taken only while effective + its two points stay this far under the limit
const HOLD_FRAMES := 200    # frames the self-pinch is held: 3 s and a little

var dream: Node2D = null
var dreamer: CharacterBody2D = null
var mode := "competent"
var did: Array[String] = []          # the driver's moves this night, in order
var wrong_pinch_done := false        # clumsy: once per night
var set_down_done := false           # clumsy: once per night
var stuck := false                   # a room routine ended with the room still in play
var acts := {}                       # kind -> count, from the dream's acted signal (the lucidity table's kinds)
var woke: Array = []                 # [sudden, scraps] once the night is over
var final := {}                      # the dream's numbers at the woke signal (the controller frees the dream right after)
var frames_played := 0
var room_at_start := -1              # the room index a routine began in: a move that lands in the exit ends the routine
var reached_who := ""                # the goal reached this night, if any
var self_pinched := false            # the night ended by the self-pinch


## Take over a dream (alone, or the controller's). The night can be
## played at once; a new night needs attach() again.
func attach(a_dream: Node2D, play_mode: String) -> void:
	dream = a_dream
	dreamer = a_dream.dreamer
	mode = play_mode
	did = []
	wrong_pinch_done = false
	set_down_done = false
	stuck = false
	acts = {}
	woke = []
	final = {}
	frames_played = 0
	reached_who = ""
	self_pinched = false
	dream.acted.connect(_on_acted)
	dream.woke.connect(_on_woke)
	dream.reached.connect(_on_reached)


func _on_woke(sudden: bool, scraps: Array) -> void:
	woke = [sudden, scraps]
	final = {"lucidity": dream.lucidity, "effective": dream.effective(), "blinks": dream.blinks, "hard_falls": dream.hard_falls, "carried": scraps.size(), "scraps": scraps.size()}


func _on_reached(who: String, _idea: String) -> void:
	reached_who = who


func _on_acted(kind: String, detail: String) -> void:
	var key := kind.get_slice(":", 0)   # wonder:<id> counts as wonder
	if key in ["set_down", "force", "fall", "fail", "wonder", "grab_scrap", "set_down_scrap"]:
		acts[key] = acts.get(key, 0) + 1
	if key == "fail":
		did.append("fail:%s" % detail)
	if key == "self_pinch":
		self_pinched = true


## Plays the night from the room in play to the end: the idea reached,
## the self-pinch, the bed, or waking. Returns {rooms, acts, lucidity,
## effective, end ("reached" | "self" | "bed" | "woke" | "stuck"), carried
## (the scraps), scraps, kept, frames, seconds, blinks, hard_falls}.
func play_night() -> Dictionary:
	var rooms: Array[String] = []
	while alive() and not stuck:
		var id: String = dream.current_room_id()
		rooms.append(id)
		var index: int = dream.room_index
		await play_room(id)
		if not alive():
			break
		if dream.room_index == index:
			stuck = true
			did.append("stuck in %s" % id)
	release_all()
	var waited := 0
	while woke.is_empty() and waited < 120 and is_instance_valid(dream):   # the frame shuts (0.35 s) and holds (0.8 s) before woke fires
		await get_tree().physics_frame
		waited += 1
	frames_played += waited
	var end := "stuck"
	if not woke.is_empty():
		if woke[0]:
			end = "woke"
		elif reached_who != "":
			end = "reached"
		elif self_pinched:
			end = "self"
		else:
			end = "bed"
	if final.is_empty() and is_instance_valid(dream):   # no waking: the numbers as they stand
		final = {"lucidity": dream.lucidity, "effective": dream.effective(), "blinks": dream.blinks, "hard_falls": dream.hard_falls, "carried": dream.scraps_carried.size(), "scraps": dream.scraps_carried.size()}
	var carried: int = final.get("carried", 0)
	var kept := carried + (1 if end == "reached" else 0)   # the idea reached comes home too
	if end == "woke":
		kept = mini(1, carried)
	return {
		"rooms": rooms, "acts": acts.duplicate(), "lucidity": final.get("lucidity", 0), "effective": final.get("effective", 0),
		"end": end, "carried": carried, "scraps": final.get("scraps", 0), "kept": kept, "frames": frames_played, "seconds": frames_played / 60.0,
		"blinks": final.get("blinks", 0), "hard_falls": final.get("hard_falls", 0),
	}


func alive() -> bool:
	return is_instance_valid(dream) and not dream.woken and not dream.closing


## True while the routine's room is still the one in play and the night goes on.
func in_room() -> bool:
	return alive() and dream.room_index == room_at_start


func play_room(id: String) -> void:
	did.append("enter %s" % id)
	room_at_start = dream.room_index
	match id:
		"tutorial":
			await play_tutorial()
		"a":
			await play_a()
		"b":
			await play_b()
		"c":
			await play_c()
		"d":
			await play_d()
		"e":
			await play_e()
		"f":
			await play_f()
		"ladder":
			await play_ladder()
		"bed":
			await play_bed()
		"hub":
			await play_hub()
		_:
			if id.begins_with("goal_"):
				await play_goal()
	release_all()


# --- the rooms ------------------------------------------------------------------

## The hub (SPEC-2): the two scraps either side of the door, then the exit
## whose sign is the target's (the right one); with no exit, the self-pinch.
func play_hub() -> void:
	await land()
	if dream.room.exits().is_empty():
		did.append("no way on: pinched myself awake")
		await self_pinch()
		return
	await walk_to_scrap("move_left", func() -> bool: return dreamer.position.x <= 400.0, 180)
	await walk_to_scrap("move_right", func() -> bool: return dreamer.position.x >= 760.0, 300)
	var signs: Dictionary = dream.hub_signs()
	var side := "right" if signs.right == dream.state.target or signs.left == "" else "left"
	did.append("took the %s sign: %s" % [side, signs[side]])
	if side == "left":
		pinch_on()
		await hold_until("move_left", func() -> bool: return false, 600)
	else:
		await walk_out()


## The goal room (SPEC-2): the quiet spot by the door (asleep), then E at
## the idea beside the sleeping villager: the night ends there. On a
## branch already reached (no idea; two scraps in its place) the scraps
## in reach are taken and the night is ended by the self-pinch.
func play_goal() -> void:
	pinch_off()
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 420.0, DRIFT_FRAMES)
	await be_still()
	if not alive():
		return
	await land()
	if dream.goal_idea == "":
		did.append("already dreamed: no idea here")
		await walk_to_scrap("move_right", func() -> bool: return dreamer.position.x >= 900.0, 400)
		await take_scrap()
		did.append("pinched myself awake")
		await self_pinch()
		return
	await walk_until("move_right", func() -> bool: return dream.can_reach(), 400)
	if dream.reach():
		did.append("reached %s" % dream.goal_idea)


## Hold PINCH still on the floor until the dreamer wakes on purpose.
func self_pinch() -> void:
	release_all()
	pinch_on()
	await wait_until(func() -> bool: return dreamer.is_on_floor(), 90)
	var n := 0
	while is_instance_valid(dream) and not dream.woken and n < HOLD_FRAMES:
		await get_tree().physics_frame
		n += 1
	frames_played += n


## The gap: the current across, the far floor (the first loop's room, dealt by hand).
func play_tutorial() -> void:
	await land()
	await take_scrap()
	if clumsy():
		await press("jump")   # the step by the door: up, and off its far end (64 px: a hard fall)
		await hold_until("move_right", func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 200.0 and dreamer.position.y < 520.0, 120)
		await hold_until("move_right", func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 300.0, 120)
		did.append("fell off the step")
		if not alive():
			return
	pinch_off()
	await frames(2)
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 300.0, DRIFT_FRAMES)
	if await wrong_pinch(func() -> bool: return dreamer.position.x >= 480.0):
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 300.0, DRIFT_FRAMES)
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 800.0, DRIFT_FRAMES)
	did.append("carried across")
	await land()
	await walk_out()


## The soft wall: the scrap on the near floor, the wall's wonder, the ledge, the spot.
func play_a() -> void:
	await land()
	await walk_to_scrap("move_right", func() -> bool: return dreamer.position.x >= 300.0, 180)   # short of the near floor's edge (380)
	pinch_off()
	await frames(2)
	if await wrong_pinch(func() -> bool: return dreamer.position.x >= 470.0):
		pass
	if clumsy():
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 680.0, DRIFT_FRAMES)   # into the updraft
		await wait_until(func() -> bool: return dreamer.position.y < 430.0, 300)
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 800.0, DRIFT_FRAMES)
		did.append("rode the updraft and pinched over the ledge: a hard fall")
		await land()
	else:
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 600.0, DRIFT_FRAMES)   # through the soft wall, short of the updraft
		await land()
		await climb_onto(dream.room.get_node("Crisp/Ledge"))
	if not alive():
		return
	await walk_until("move_right", func() -> bool: return dreamer.position.x >= 822.0, 120)
	await be_still()
	await walk_out()


## The goat: the goat's round over the pit to the far floor.
func play_b() -> void:
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	pinch_off()
	await frames(2)
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
	await ride(goat)
	if not alive():
		return
	if await wrong_pinch(func() -> bool: return goat.center().y < 220.0 and goat.center().x > 700.0 and goat.center().x < 760.0):
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
		await ride(goat)
		if not alive():
			return
	if clumsy():
		await wait_until(func() -> bool: return goat.center().y < 220.0 and goat.center().x > 980.0, RIDE_FRAMES)
		did.append("pinched off the goat's top path over the far floor: a hard fall")
	else:
		await wait_until(func() -> bool: return goat.center().x > 1000.0 and goat.center().y > 535.0, RIDE_FRAMES)
	await land()
	await walk_out()


## The climb: the floor runs under the ledges to the exit (clumsy: a fall off the first ledge).
func play_c() -> void:
	await land()
	var ledge1: StaticBody2D = dream.room.get_node("Crisp/Ledge1")
	if clumsy():
		await climb_onto(ledge1)
		await walk_until("move_right", func() -> bool: return dreamer.is_on_floor() and dreamer.position.x > 500.0, 240)
		did.append("fell off the first ledge")
	await walk_out()


## The maze: the lift through the soft walls, the pinch over the island.
func play_d() -> void:
	pinch_off()
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 310.0, 240)
	if clumsy():
		await wait_until(func() -> bool: return dreamer.position.x >= 700.0, 480)
		await land()
		did.append("pinched off the lift over the floor: a hard fall")
		await walk_until("move_left", func() -> bool: return dreamer.position.x <= 290.0, 240)
		pinch_off()
		await frames(2)
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 310.0, 240)
	await wait_until(func() -> bool: return dreamer.position.x >= 880.0, 480)
	await land()
	await take_scrap()
	await walk_out()


## Cold water: the goat over the water to the beam, the scrap, the goat again to the far floor.
func play_e() -> void:
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	pinch_off()
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
	await ride(goat)
	if not alive():
		return
	if await wrong_pinch(func() -> bool: return goat.center().y > 500.0 and goat.center().x > 450.0 and goat.center().x < 700.0):
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 150.0, 120)
		await ride(goat)
		if not alive():
			return
	await wait_until(func() -> bool: return goat.center().x < 820.0 and goat.center().y < 320.0, RIDE_FRAMES)
	await land()
	await walk_to_scrap("move_right", func() -> bool: return dreamer.position.x >= 840.0, 120)   # along the beam (700..900), short of its end
	if not in_room():
		return
	if clumsy():
		await walk_until("move_right", func() -> bool: return not dreamer.is_on_floor(), 200)
		await wait_until(func() -> bool: return dreamer.is_on_floor(), 120)
		did.append("off the beam's end: a hard fall")
	else:
		pinch_off()
		await frames(2)
		await ride(goat)
		if not alive() or not is_instance_valid(goat):
			return
		await wait_until(func() -> bool: return goat.center().y > 500.0 and goat.center().x >= 930.0, RIDE_FRAMES)
		await land()
	await walk_out()


## The draft: up through the soft room, the pinch over the shelf, the
## scrap, the spot, the draft again to the top and the pinch over the perch.
func play_f() -> void:
	pinch_off()
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 200.0, 120)
	if await wrong_pinch(func() -> bool: return dreamer.position.x >= 450.0):
		await hold_until("move_right", func() -> bool: return dreamer.position.x >= 200.0, 120)
	if clumsy():
		await wait_until(func() -> bool: return dreamer.position.x >= 790.0, 480)
		did.append("pinched late over the shelf: a hard fall")
	else:
		await wait_until(func() -> bool: return dreamer.position.x >= 700.0, 480)
	await land()
	await take_scrap()
	await walk_until("move_right", func() -> bool: return dreamer.position.x >= 745.0, 60)
	await be_still()
	if not alive():
		return
	pinch_off()
	await frames(2)
	await wait_until(func() -> bool: return dreamer.position.y <= 125.0 and dreamer.position.x >= 940.0, 480)
	did.append("rode the draft to the top")
	await land()
	await walk_out()


## The ladder: nothing to do but walk under it.
func play_ladder() -> void:
	await land()
	await walk_out()


## Whether the driver would take a scrap now: room at the hip, and (the
## competent player counts; the clumsy one does not) its two points (one
## lucidity, one carried) leave SCRAP_MARGIN under the limit.
func can_take_scrap() -> bool:
	if dream.scraps_carried.size() >= dream.state.carry_scraps:
		return false
	return clumsy() or dream.effective() + 2 + SCRAP_MARGIN <= dream.limit()


## Pinched, walk one way until a scrap is in reach (then take it, with the
## clumsy fumble) or `stop` holds; a scrap taken on the way counts too.
func walk_to_scrap(action: String, stop: Callable, budget: int) -> void:
	var before: int = dream.scraps_carried.size()
	await walk_until(action, func() -> bool: return dream.scrap_in_reach() != null or dream.scraps_carried.size() > before or stop.call(), budget)
	if dream.scraps_carried.size() > before:
		await fumble()   # taken on the way: the clumsy fumble still follows
	else:
		await take_scrap()


## The scrap in reach, if the driver wants it; clumsy: the night's one
## set-down right after the first grab, the scrap picked up again.
func take_scrap() -> void:
	if dream.scrap_in_reach() == null or not in_room() or not can_take_scrap():
		return
	if dream.grab_scrap():
		did.append("took %s" % dream.scraps_carried.back())
		await fumble()


## Clumsy, once per night, right after a scrap is taken: the scrap set
## down (+1) and picked up again (+1).
func fumble() -> void:
	if not clumsy() or set_down_done or not alive() or dream.scraps_carried.is_empty():
		return
	await frames(1)
	if dream.set_down_scrap():
		set_down_done = true
		did.append("fumbled a thought: set down")
		await frames(2)
		if dream.grab_scrap():
			did.append("and picked up again")


## Your bed (the first loop's room, dealt by hand): the quiet spot by the
## door, then the bed (gentle, with everything) or, dealt early, past the
## block and on.
func play_bed() -> void:
	pinch_off()
	await hold_until("move_right", func() -> bool: return dreamer.position.x >= 300.0, DRIFT_FRAMES)
	await be_still()
	if not alive():
		return
	await land()
	var last: bool = dream.room.exit == null
	if last:
		await walk_until("move_right", func() -> bool: return dream.bed_in_reach(), 400)
		if dream.lie_down():
			did.append("lay down in the bed")
		return
	did.append("walked past the early bed")
	await climb_onto(dream.block)   # the jump clears it into the exit: no drop here, clumsy or not
	await walk_out()


# --- moves ----------------------------------------------------------------------

func clumsy() -> bool:
	return mode == "clumsy"


## Pinch and wait for the floor.
func land() -> void:
	if not in_room():
		return
	pinch_on()
	await wait_until(func() -> bool: return dreamer.is_on_floor(), 90)
	await frames(2)


## Clumsy, once per night: pinch when `where` holds (over a gap or the
## water): the screen fails, the blink, back at the door. Returns true
## when it happened (the caller starts the room over).
func wrong_pinch(where: Callable) -> bool:
	if not clumsy() or wrong_pinch_done:
		return false
	var frames_waited := await wait_until(where, DRIFT_FRAMES)
	if frames_waited >= DRIFT_FRAMES or not in_room():
		return false
	wrong_pinch_done = true
	var blinks: int = dream.blinks
	pinch_on()
	await wait_until(func() -> bool: return dream.blinks > blinks, 120)
	did.append("pinched in the wrong place")
	await wait_until(func() -> bool: return not dream.blinking, 100)
	pinch_off()
	release_all()
	await settle()
	return true


## Asleep: wait for the goat to carry the body (the body must overlap its round).
func ride(goat: Area2D) -> void:
	if not is_instance_valid(goat) or not in_room():
		return
	var frames_waited := await wait_until(func() -> bool: return dreamer.carried_by.has(goat) or not alive(), RIDE_FRAMES)
	if frames_waited < RIDE_FRAMES:
		did.append("rode the goat")


## Still for 3 s and a little, asleep (the pinch let go: pinched stillness
## is the self-pinch, day B): a spot's wonder, if the body is in one.
func be_still() -> void:
	release_all()
	pinch_off()
	if in_room():
		await frames(STILL_FRAMES)


## Pinched: walk right and jump when the box's left edge is within 100 px
## and the body is still below its top; until standing on it.
func climb_onto(box: StaticBody2D) -> void:
	var frames_spent := 0
	pinch_on()
	while in_room() and frames_spent < 300 and not (dreamer.is_on_floor() and dreamer.position.x > box.position.x + 20.0 and dreamer.position.y < box.position.y):
		Input.action_press("move_right")
		var ahead: float = box.position.x - (dreamer.position.x + 14.0)
		if dreamer.is_on_floor() and ahead < 100.0 and dreamer.position.y > box.position.y and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		frames_spent += 1
	Input.action_release("move_right")
	Input.action_release("jump")
	await get_tree().physics_frame
	frames_played += frames_spent + 1


## Pinched, walk right until the room changes (the exit is on the right everywhere).
func walk_out() -> void:
	if not in_room():
		return
	pinch_on()
	await hold_until("move_right", func() -> bool: return false, 600)   # until the room changes, or the budget


# --- primitives -----------------------------------------------------------------

func pinch_on() -> void:
	Input.action_press("pinch")


func pinch_off() -> void:
	Input.action_release("pinch")


func release_all() -> void:
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	frames_played += n


func settle() -> void:
	await frames(SETTLE)


## Frames until the condition holds, the room or the night ends, or the budget runs out.
func wait_until(cond: Callable, budget: int) -> int:
	var n := 0
	while not cond.call() and n < budget and in_room():
		await get_tree().physics_frame
		n += 1
	frames_played += n
	return n


## Hold one action until the condition holds, the room or the night ends,
## or the budget runs out; a scrap hanging in reach on the way is taken.
func hold_until(action: String, cond: Callable, budget: int) -> int:
	var n := 0
	while not cond.call() and n < budget and in_room():
		Input.action_press(action)
		await get_tree().physics_frame
		n += 1
		if dreamer.pinched and dream.scrap_in_reach() != null and can_take_scrap() and dream.grab_scrap():
			did.append("took %s on the way" % dream.scraps_carried.back())
	Input.action_release(action)
	await get_tree().physics_frame
	frames_played += n + 1
	return n


## Pinched walking: the same, with the pinch held.
func walk_until(action: String, cond: Callable, budget: int) -> int:
	pinch_on()
	return await hold_until(action, cond, budget)


## Press an action for one physics frame.
func press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame
	frames_played += 2
