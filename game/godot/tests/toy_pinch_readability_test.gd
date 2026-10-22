extends Node2D
## The readability pass of toy 4, PINCH, headless: what the designer's GPU
## screenshots asked for. The dream (dream.tscn alone) and the village
## (village.tscn alone) are driven through the input actions and their own
## API; labels, rects and texts are read back. Sections: (A) the dev bar in
## the dream: a layer over the frame along the bottom, on by default,
## devbar_text() for asleep, asleep in a current, pinched by an idea, with
## an idea to set down, near the exit, at the bed, by the block, over a
## quiet spot; the room's hint in its right half (full for 4 s, faded by
## 5), the room's name alone at the top left, the controls line gone; Tab
## hides it, the state remembers, the next night starts hidden, Tab shows
## it; the gauge above the strip; (B) the door's word left of the door,
## never on a line with a gauge label at the limit 8 or 10; (C) every
## Label in every room scene, the dream and the village has autowrap or
## fits its box and sits inside its screen; every hint in rooms.json is
## under 18 words and wraps to at most two lines of the bar; (D) the
## breakfast want lines at three distinct heights (the left face lowest,
## the right highest, 22 px apart), no two rects overlapping, a leader from
## each down to its head, a backing behind each, the "table" word hidden
## while breakfast is on, the faces' names on their bodies; (E) Bo's want
## is his "moved" line once his loft stands, on the street and at the
## table, Jorun's still his want; (F) the frame rects have whole-pixel
## positions and sizes and the side rects overlap the top and bottom by
## 1 px; (G) a claim is two say lines, the owner's first, the idea's own
## 1.5 s later; (H) the goat's word sits above its body, clear of a rider
## with a full hat; (I) the looks: soft things pale with a dashed edge,
## spots a pulsing ring (0.95..1.05 over 2 s), currents 3 to 5 arrows
## drifting 40 px/s along the flow and wrapping inside the box, hazards
## hatched, crisp boxes plain; (J) an idea's name above its box on a
## backing with a leader, kept inside the room by a wall; (K) the bed's
## and the block's words above them; (L) the lantern labelled once; (M)
## the dev bar on the street: walk, talk, sleep, a pill, make, breakfast;
## Tab there too, and the choice carried into the dream. SPEC-2 (day A):
## the night opens on the hub now, so (A) deals the tutorial, a and the
## bed by hand and places the tutorial's idea by hand; a pinched line of
## the dev bar ends with the self-pinch's hold (devbar.json self_pinch,
## the seconds left counting) on every floor outside a quiet spot;
## rooms.json holds 13 rooms (the hub and three goal rooms joined). Prints
## PASS/FAIL per check and quits with 0 only if every check passes.

const DREAM := preload("res://prototypes/pinch/dream.tscn")
const VILLAGE := preload("res://prototypes/pinch/village.tscn")
const DREAM_SCRIPT := preload("res://prototypes/pinch/dream.gd")
const ROOMS_FILE := "res://prototypes/pinch/data/rooms.json"
const DEVBAR_FILE := "res://prototypes/pinch/data/devbar.json"
const CHARACTERS_FILE := "res://prototypes/pinch/data/characters.json"
const VILLAGE_FILE := "res://prototypes/pinch/data/village.json"
const SCREEN := Rect2(0, 0, 1152, 648)
const STREET := Rect2(0, 0, 4608, 648)
const SETTLE := 20
const WALK_FRAMES := 900
const MAX_HINT_WORDS := 18

var failures := 0
var dream: Node2D = null
var dreamer: CharacterBody2D
var state: PinchState
var acts: Array = []
var rooms_json: Dictionary
var devbar_json: Dictionary
var people_json: Dictionary
var village_json: Dictionary


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	rooms_json = PinchState.load_json(ROOMS_FILE)
	devbar_json = PinchState.load_json(DEVBAR_FILE)
	people_json = PinchState.load_json(CHARACTERS_FILE)
	village_json = PinchState.load_json(VILLAGE_FILE)
	var dw: Dictionary = devbar_json.dream
	var sw: Dictionary = devbar_json.street
	var sep: String = str(devbar_json.separator)
	var words: Dictionary = rooms_json.words

	# ---------------------------------------------------------------- (A) the dev bar in the dream
	await fresh(1)
	dream.redeal(["tutorial", "a", "bed"] as Array[String], false)   # SPEC-2: the night opens on the hub; the tutorial by hand, as before
	dream.place_idea(dream.ideas_pool()[0], Vector2(60, 588))        # where the first loop's dealer laid its idea
	await get_tree().physics_frame
	var bar: CanvasLayer = dream.devbar
	check(bar != null and bar.layer > dream.frame_top.get_parent().layer and bar.layer < 10, "the dev bar is its own layer (%d) over the frame's (%d), under the text panel" % [bar.layer, dream.frame_top.get_parent().layer])
	check(bar.visible and dream.devbar_visible and state.devbar_visible, "on by default, and the state says so")
	check(is_equal_approx(bar.strip.position.y + bar.strip.size.y, 648.0) and bar.strip.size.y <= 40.0 and is_equal_approx(bar.strip.size.x, 1152.0), "a strip along the bottom edge: y %.0f..648, %.0f px tall" % [bar.strip.position.y, bar.strip.size.y])
	check(bar.actions_label.position.x < 576.0 and bar.hint_label.position.x >= 576.0 and bar.toggle_label.text == str(devbar_json.toggle), "the actions in the left half, the hint in the right, '%s' at the far right" % bar.toggle_label.text)
	check(dream.devbar_text() == str(dw.asleep) and bar.actions_text() == dream.devbar_text(), "asleep at the door: '%s'" % dream.devbar_text())
	var tut: Dictionary = dream.room_words("tutorial")
	check(dream.hint_text() == str(tut.hint) and bar.hint_label.visible and is_equal_approx(bar.hint_alpha(), 1.0), "the room's hint in the bar's right half: '%s'" % dream.hint_text())
	check(dream.room_label.text == str(tut.name) and not dream.room_label.text.contains(str(tut.hint)) and dream.room_label.position.x < 40.0 and dream.room_label.position.y < 40.0 and dream.room_label.size.x <= 420.0, "the room's name alone, small at the top left: '%s'" % dream.room_label.text)
	check(not dream.has_node("Hud/HelpLabel") and not rooms_json.has("help"), "the fixed controls line is gone from the scene and from rooms.json")
	var frames := await hold_until("move_right", func() -> bool: return not dreamer.carried_by.is_empty(), 600)
	check(frames < 600 and not dreamer.pinched and dream.devbar_text() == sep.join([str(dw.asleep), str(dw.current)]), "asleep in the current: '%s'" % dream.devbar_text())
	Input.action_press("pinch")
	dreamer.respawn(Vector2(138, 572))   # 40 px from the tutorial's idea, as the ideas test stands
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor() and dream.idea_in_reach() != null and dream.devbar_text() == sep.join([str(dw.pinched), str(dw.grab), hold_line()]), "pinched on the floor by an idea: '%s'" % dream.devbar_text())
	check(dream.grab() and dream.carried.size() == 1, "(took it)")
	await settle()
	check(dream.devbar_text() == sep.join([str(dw.pinched), str(dw.set_down), hold_line()]), "an idea under the hat, on the floor: '%s'" % dream.devbar_text())
	dreamer.respawn(Vector2(980, 572))   # on the far floor, short of the exit zone (x 1040)
	await settle()
	check(dream.current_room_id() == "tutorial" and dream.exit_near() and dream.devbar_text().begins_with(str(dw.pinched)) and dream.devbar_text().ends_with(str(dw.exit)), "near the exit, not in it: '%s'" % dream.devbar_text())
	Input.action_release("pinch")
	await get_tree().physics_frame
	check(dream.devbar_text() == sep.join([str(dw.asleep), str(dw.exit)]), "let go there: '%s'" % dream.devbar_text())
	check(dream.jump_to_room("bed") and dream.bed != null and dream.room.exit == null, "(the bed room, dealt last: no exit)")
	dreamer.respawn(Vector2(820, 572))
	await settle()
	check(not dreamer.pinched and dream.bed_in_reach() and dream.devbar_text() == sep.join([str(dw.asleep), str(dw.bed)]), "at the bed, asleep: '%s'" % dream.devbar_text())
	Input.action_press("pinch")
	dreamer.respawn(Vector2(940, 572))
	await settle()
	check(dreamer.pinched and dreamer.is_on_floor() and dream.block_in_reach() and not dream.bed_in_reach() and dream.devbar_text() == sep.join([str(dw.pinched), str(dw.set_down), str(dw.push), hold_line()]), "pinched by the block: '%s'" % dream.devbar_text())
	check(dream.force(), "(pushed it)")
	await get_tree().physics_frame
	check(dream.devbar_text() == sep.join([str(dw.pinched), str(dw.set_down), hold_line()]), "pushed once, the push is gone: '%s'" % dream.devbar_text())
	Input.action_release("pinch")
	dreamer.respawn(Vector2(320, 540))   # inside the bed room's quiet spot
	await settle()
	check(not dreamer.pinched and dream.spot_in_reach() != null and dream.devbar_text() == sep.join([str(dw.asleep), str(dw.wonder)]), "over a quiet spot, asleep: '%s'" % dream.devbar_text())
	check(not acts.has(["devbar", "off"]), "(no toggle yet)")
	await press_key(KEY_TAB)
	check(not bar.visible and not dream.devbar_visible and not state.devbar_visible and acts.has(["devbar", "off"]), "Tab hid the dev bar; the state remembers")
	var kept: PinchState = state
	await fresh(1, false, kept)
	dream.redeal(["tutorial", "a"] as Array[String], false)   # two rooms, so the next room's hint can be read below
	bar = dream.devbar
	check(not bar.visible and not dream.devbar_visible, "the next night starts with the bar hidden")
	await press_key(KEY_TAB)
	check(bar.visible and kept.devbar_visible and acts.has(["devbar", "on"]), "Tab again: shown, and remembered")
	check(dream.frame_top.visible and dream.gauge.visible, "the frame and the gauge are untouched by it")
	var waited := await wait_seconds(4.5)
	check(bar.hint_label.visible and bar.hint_alpha() > 0.2 and bar.hint_alpha() < 0.8, "%.1f s after entering the room the hint is fading (alpha %.2f)" % [waited, bar.hint_alpha()])
	waited = await wait_until_seconds(func() -> bool: return not bar.hint_label.visible, 2.0)
	check(waited < 1.0 and is_zero_approx(bar.hint_alpha()), "and gone %.2f s later (5 s in all)" % waited)
	check(dream.next_room() and bar.hint_label.visible and is_equal_approx(bar.hint_alpha(), 1.0) and dream.hint_text() == str(dream.room_words(dream.current_room_id()).hint), "the next room brings its own hint back in full: '%s'" % dream.hint_text())
	check(is_equal_approx(dream.gauge.position.y, 600.0) and dream.gauge.position.y <= bar.strip.position.y, "the gauge's bottom (y %.0f) sits above the dev bar (y %.0f)" % [dream.gauge.position.y, bar.strip.position.y])

	# ---------------------------------------------------------------- (B) the door's word and the gauge
	for limit in [8, 10]:
		await fresh(1, limit == 10)
		var door_rect: Rect2 = dream.room.door_label_rect()
		var door_at: Vector2 = dream.room.door.position
		var door_label: Label = dream.room.door_label
		check(dream.limit() == limit and door_label.text == str(words.door) and door_rect.end.x <= door_at.x - 14.0 and door_rect.position.y >= door_at.y + 28.0 and door_rect.position.x >= 0.0, "limit %d: the door's word '%s' sits left of the door, under the body's feet: %s (the door at %s)" % [limit, door_label.text, door_rect, door_at])
		var shared := []
		for label in [dream.gauge_labels.deep, dream.gauge_labels.light, dream.gauge_labels.waking, dream.ideas_label]:
			var rect := Rect2(dream.GAUGE_AT + label.position, label.size)
			if rect.intersects(door_rect):
				shared.append(label.text)
		check(shared.is_empty(), "limit %d: no gauge label shares a line with it (%s)" % [limit, shared])
		check(door_label.has_node("Backing") and door_label.get_node("Backing").visible, "the door's word has a backing")

	# ---------------------------------------------------------------- (C) every label fits
	for id in DREAM_SCRIPT.ROOM_SCENES:
		var room: Node2D = DREAM_SCRIPT.ROOM_SCENES[id].instantiate()
		room.words = words
		add_child(room)
		await get_tree().process_frame
		var bad := labels_that_do_not_fit(room, SCREEN)
		var n := room.find_children("*", "Label", true, false).size()
		check(bad.is_empty() and n >= 2, "room %s: all %d labels have autowrap or fit their box inside the screen %s" % [id, n, bad])
		remove_child(room)
		room.queue_free()
	await fresh(1)
	for i in 3:
		await get_tree().physics_frame
	var dream_bad := labels_that_do_not_fit(dream, SCREEN)
	check(dream_bad.is_empty(), "the dream's own labels (the room's name, the gauge, the dev bar, the idea) fit %s" % [dream_bad])
	var hint_bad := []
	for entry in rooms_json.rooms:
		var hint := str(entry.hint)
		var n_words := hint.split(" ", false).size()
		dream.devbar.show_hint(hint)
		await get_tree().process_frame
		var lines: int = dream.devbar.hint_label.get_line_count()
		if n_words >= MAX_HINT_WORDS or lines > 2:
			hint_bad.append("%s: %d words, %d lines" % [entry.id, n_words, lines])
	check(hint_bad.is_empty() and rooms_json.rooms.size() == 13, "every hint in rooms.json (13 rooms: SPEC-2 added the hub and three goal rooms) is under %d words and wraps to at most two lines of the bar %s" % [MAX_HINT_WORDS, hint_bad])
	await free_dream()
	var full := PinchState.new()
	full.day = 3
	full.tally = 3
	full.ideas_built["sixteen_stairs"] = "sixteen_stairs"
	full.ideas_claimed["bos_loft"] = "bos_big_needle"
	full.small_things.assign(["spoon", "door_boat", "window_yesterday"])
	full.ideas_kept.assign(["smell_of_bread"])
	var village: Node2D = await new_village(full)
	check(village.breakfast_on and village.seats.size() == 3 and village.table_idea_ids() == ["smell_of_bread"], "(a full street: a building, a scaffold, three small things, breakfast on)")
	var village_bad := labels_that_do_not_fit(village, STREET)
	var village_n: int = village.find_children("*", "Label", true, false).size()
	check(village_bad.is_empty() and village_n >= 20, "the village: all %d labels have autowrap or fit their box inside the street %s" % [village_n, village_bad])

	# ---------------------------------------------------------------- (D) the breakfast want lines
	var seat_ids: Array = ["tove", "jorun", "bo"]
	var want_rects: Array[Rect2] = []
	var backing_rects: Array[Rect2] = []
	var ys: Array[float] = []
	for who in seat_ids:
		var seat: Node2D = village.seats[who]
		var want: Label = seat.get_node("Want")
		want_rects.append(want.get_global_rect())
		backing_rects.append(Rect2(want.get_global_position() + want.get_node("Backing").position, want.get_node("Backing").size))
		ys.append(want.get_global_position().y)
	check(want_rects[0].position.x < want_rects[1].position.x and want_rects[1].position.x < want_rects[2].position.x, "the three faces sit left to right: Tove, Jorun, Bo")
	check(ys[0] > ys[1] and ys[1] > ys[2] and is_equal_approx(ys[0] - ys[1], 22.0) and is_equal_approx(ys[1] - ys[2], 22.0), "their want lines sit at three heights, the left lowest, the right highest, 22 px apart: y %.0f, %.0f, %.0f" % [ys[0], ys[1], ys[2]])
	var overlap := false
	for i in 3:
		for j in 3:
			if i != j and (want_rects[i].intersects(want_rects[j]) or backing_rects[i].intersects(backing_rects[j])):
				overlap = true
	check(not overlap, "no two want lines (nor their backings) overlap: %s" % [want_rects])
	var leaders_ok := true
	var fits_ok := true
	for who in seat_ids:
		var seat: Node2D = village.seats[who]
		var want: Label = seat.get_node("Want")
		var leader: ColorRect = seat.get_node_or_null("Leader")
		leaders_ok = leaders_ok and leader != null and is_equal_approx(leader.position.y, want.position.y + want.size.y) and is_equal_approx(leader.position.y + leader.size.y, -village.CAPSULE.y) and absf(leader.position.x) < 1.0
		fits_ok = fits_ok and want.visible and want.has_node("Backing") and PinchLabel.text_width(want) <= village.WANT_WIDTH and want.get_line_count() == 1
	check(leaders_ok, "each want line has a leader from its bottom straight down to its face's head")
	check(fits_ok, "each want line is one line on a backing")
	var names_ok := true
	for who in seat_ids:
		var name_label: Label = village.seats[who].get_node("Name")
		names_ok = names_ok and name_label.position.y >= -village.CAPSULE.y and name_label.position.y + name_label.size.y <= 0.0
	check(names_ok, "at the table a face's name sits on its body, under the pieces on the table")
	check(not village.table_label.visible and village.table_label.text == str(village_json.markers.table), "the 'table' word is hidden while breakfast is on")
	for piece in village.table_ideas.get_children():
		check(not piece.get_node("Name").visible and village.hand.get_child(0).get_node("Name").visible, "the table's piece names are hidden at breakfast; the hand's shows")
	var walk_away := await walk_walker_to(village, village.BUNK.get_center().x)
	check(walk_away < WALK_FRAMES and not village.breakfast_on and village.table_label.visible, "walked away: breakfast over, the 'table' word back")

	# ---------------------------------------------------------------- (E) Bo's want after his loft stands
	var bo: Dictionary = person("bo")
	var jorun: Dictionary = person("jorun")
	var want_format: String = str(people_json.want_line)
	check(village.people.bo.get_node("Want").text == want_format.format({"name": bo.name, "want": bo.want}), "Bo's want while his plot waits: '%s'" % village.people.bo.get_node("Want").text)
	full.ideas_built["bos_loft"] = "bos_big_needle"
	full.ideas_claimed.clear()
	village.refresh()
	var bo_want: String = village.people.bo.get_node("Want").text
	check(bo_want == want_format.format({"name": bo.name, "want": bo.moved}) and not bo_want.contains(str(bo.want)) and str(bo.moved) != "", "his loft stands: his want is absent and his moved line shows: '%s'" % bo_want)
	check(village.people.jorun.get_node("Want").text == want_format.format({"name": jorun.name, "want": jorun.moved}), "Jorun's too (Sixteen Stairs stands): '%s'" % village.people.jorun.get_node("Want").text)
	full.ideas_kept.assign(["window_yesterday"])
	village.start_breakfast()
	check(village.breakfast_on and village.seats.bo.get_node("Want").text == bo_want and village.seats.tove.get_node("Want").text == want_format.format({"name": person("tove").name, "want": person("tove").want}), "at the table the same: Bo's moved line, Tove's want")
	village.end_breakfast("skipped")
	await free_village(village)

	# ---------------------------------------------------------------- (F) the frame's rects
	await fresh(1)
	dreamer.respawn(Vector2(576.4, 324.3))   # off the pixel grid on purpose
	for i in 3:
		dream.fall()
	for i in 30:
		await get_tree().physics_frame
	var rects: Array[Rect2] = dream.frame_rects()
	var whole := true
	for rect in rects:
		whole = whole and rect.position == rect.position.round() and rect.size == rect.size.round()
	check(whole and dream.frame_open.position == dream.frame_open.position.round() and dream.frame_open.size == dream.frame_open.size.round(), "every frame rect has whole-pixel position and size: %s" % [rects])
	var top: Rect2 = rects[0]
	var bottom: Rect2 = rects[1]
	var left: Rect2 = rects[2]
	var right: Rect2 = rects[3]
	var open: Rect2 = dream.frame_open
	check(is_equal_approx(left.position.y, top.end.y - 1.0) and is_equal_approx(right.position.y, top.end.y - 1.0) and is_equal_approx(left.end.y, bottom.position.y + 1.0) and is_equal_approx(right.end.y, bottom.position.y + 1.0), "the side rects reach 1 px into the top and bottom rects: no seam")
	check(is_equal_approx(top.end.y, open.position.y) and is_equal_approx(bottom.position.y, open.end.y) and is_equal_approx(left.end.x, open.position.x) and is_equal_approx(right.position.x, open.end.x), "the opening itself is untouched: %s" % [open])
	check(is_equal_approx(top.size.y + open.size.y + bottom.size.y, 648.0) and is_equal_approx(left.size.x + open.size.x + right.size.x, 1152.0) and open.size == Vector2(720, 405), "the four rects and the opening tile the screen (5/8: %s)" % [open.size])
	await free_dream()

	# ---------------------------------------------------------------- (G) a claim is two lines
	var claim_state := PinchState.new()
	claim_state.day = 2
	claim_state.keep("sixteen_stairs")
	village = await new_village(claim_state)
	var panel: CanvasLayer = village.panel
	check(village.breakfast_on and village.hand_idea() == "sixteen_stairs", "(breakfast with Sixteen Stairs in the hand)")
	frames = await walk_walker_to(village, village.seats.jorun.position.x)
	check(frames < WALK_FRAMES and village.seat_in_reach() == "jorun", "at Jorun's seat")
	var stairs_line: String = str(village.idea_entry("sixteen_stairs").get("line", ""))
	check(village.offer() and panel.say_label.text == str(jorun.claims) and not panel.say_label.text.contains(stairs_line), "E: Jorun's own short line first: '%s'" % panel.say_label.text)
	check(village.lines_waiting().size() >= 1 and village.lines_waiting()[0] == stairs_line, "the idea's own line waits behind it: '%s'" % stairs_line)
	waited = await wait_until_seconds(func() -> bool: return panel.say_label.text == stairs_line, 3.0)
	check(waited > 1.3 and waited < 1.7 and panel.say_label.text == stairs_line, "it followed as a second line %.2f s later (1.5)" % waited)
	await free_village(village)

	# ---------------------------------------------------------------- (H) the goat's word
	await fresh(1)
	dream.redeal(["b", "bed"] as Array[String])
	var goat: Area2D = dream.room.get_node("Currents/Round/Follow/Goat")
	var goat_label: Rect2 = goat.label_rect()
	var rider: Rect2 = goat.rider_rect(dreamer.BODY_SIZE, 3, dreamer.HAT_PIECE)
	check(goat.label.text == str(words.goat) and goat_label.end.y <= 0.0 and goat_label.end.y <= -goat.HORN.y, "the goat's word '%s' sits above its body (and its horns): %s" % [goat.label.text, goat_label])
	check(not goat_label.intersects(rider) and goat_label.end.x < rider.position.x, "a rider with a full hat (%s) never covers it" % [rider])
	check(goat.has_node("Fill") and goat.horns != null and goat.horns.get_child_count() == 2 and goat.horns.get_child(0) is Polygon2D, "a filled rect with two horn triangles")

	# ---------------------------------------------------------------- (I) the looks
	dream.redeal(["a", "bed"] as Array[String])
	var wall: Area2D = dream.room.get_node("Wonders/Wall")
	var soft_look: Node2D = wall.get_node_or_null("SoftLook")
	check(wall.is_in_group("soft") and soft_look != null and int(soft_look.get_meta("dashes")) >= 20 and is_equal_approx(soft_look.get_node("Fill").color.a, 0.45), "a soft wall is pale (alpha 0.45) with a dashed outline of %d dashes" % (int(soft_look.get_meta("dashes")) if soft_look else 0))
	var floor_box: StaticBody2D = dream.room.get_node("Crisp/FloorNear")
	check(floor_box.get_node("Fill").color.a == 1.0 and not floor_box.has_node("SoftLook"), "a crisp box is a plain filled rect")
	var spot: Area2D = dream.room.get_node("Wonders/Quiet")
	check(spot.ring != null and spot.ring.get_child_count() == 4 and spot.ring.position == spot.size / 2.0 and spot.get_node("Fill").color.a < 0.2, "a quiet spot is a ring of four thin rects about its middle, over a very faint fill")
	var lo := 2.0
	var hi := 0.0
	for i in 130:
		await get_tree().physics_frame
		lo = minf(lo, spot.ring.scale.x)
		hi = maxf(hi, spot.ring.scale.x)
	check(lo < 0.955 and lo >= 0.95 - 0.001 and hi > 1.045 and hi <= 1.05 + 0.001, "it pulses: scale %.3f..%.3f over 2 s" % [lo, hi])
	var updraft: Area2D = dream.room.get_node("Currents/Updraft")
	var arrow_count: int = updraft.arrow_positions().size()
	var dir: Vector2 = updraft.velocity.normalized()
	var rotation_ok := true
	for arrow in updraft.arrows.get_children():
		rotation_ok = rotation_ok and is_equal_approx(arrow.rotation, dir.angle()) and arrow is Polygon2D
	check(arrow_count >= 3 and arrow_count <= 5 and rotation_ok, "the updraft carries %d arrow triangles pointing along its velocity %s" % [arrow_count, updraft.velocity])
	var before: Array[Vector2] = updraft.arrow_positions()
	for i in 30:
		await get_tree().physics_frame
	var after: Array[Vector2] = updraft.arrow_positions()
	var drift_ok := true
	var span: float = updraft.lane_length()
	for i in before.size():
		var moved: float = (after[i] - before[i]).dot(dir)
		drift_ok = drift_ok and (absf(moved - 20.0) < 1.0 or absf(moved - (20.0 - span)) < 1.0)
	check(drift_ok, "in half a second each drifted 20 px (40 px/s) along the flow, or wrapped: %s" % [after])
	var inside_ok := true
	var counts_ok := true
	var any_wrapped := false
	for id in DREAM_SCRIPT.ROOM_SCENES:
		var room: Node2D = DREAM_SCRIPT.ROOM_SCENES[id].instantiate()
		room.words = words
		add_child(room)
		for current in room.find_children("*", "Area2D", true, false):
			if current.role != "current" or current.kind == "goat":
				continue
			var n: int = current.arrow_positions().size()
			counts_ok = counts_ok and n >= 3 and n <= 5
			var box := Rect2(Vector2.ZERO, current.size)
			var flow: Vector2 = current.velocity.normalized()
			var along_prev: float = current.arrow_positions()[0].dot(flow)
			for step in 400:
				current._move_arrows(1.0 / 60.0)   # 6.7 s of flow: longer than any lane at 40 px/s
				var along: float = current.arrow_positions()[0].dot(flow)
				any_wrapped = any_wrapped or along < along_prev - 1.0
				along_prev = along
				for at in current.arrow_positions():
					inside_ok = inside_ok and box.grow(1.0).has_point(at)
		remove_child(room)
		room.queue_free()
	check(counts_ok and inside_ok and any_wrapped, "every current in every room has 3 to 5 arrows that stay inside its box and wrap")
	dream.redeal(["b", "bed"] as Array[String])
	var pit: Area2D = dream.room.get_node("Hazards/Pit")
	check(pit.is_in_group("hazard") and pit.has_node("Hatch") and int(pit.get_node("Hatch").get_meta("lines")) >= 10 and pit.get_node("Hatch").get_child(0).rotation < 0.0, "a hazard is hatched with %d thin diagonal rects" % int(pit.get_node("Hatch").get_meta("lines")))
	dream.redeal(["d", "bed"] as Array[String])
	var wall1: StaticBody2D = dream.room.get_node("Soft/Wall1")
	check(wall1.soft and wall1.is_in_group("soft") and wall1.has_node("SoftLook") and int(wall1.get_node("SoftLook").get_meta("dashes")) > 0, "a soft box is drawn with the same dashed helper")

	# ---------------------------------------------------------------- (J) an idea's name above its box
	dream.redeal(["a", "bed"] as Array[String])
	var idea: StaticBody2D = dream.place_idea("spoon", Vector2(240, 588))
	await get_tree().physics_frame
	var name_rect: Rect2 = idea.label_rect()
	check(name_rect.end.y <= idea.rect().position.y - 28.0 and idea.label.has_node("Backing") and idea.label.get_node("Backing").visible, "the name sits %.0f px above the box's top (clear of a body beside it) on a backing" % (idea.rect().position.y - name_rect.end.y))
	check(idea.leader != null and is_equal_approx(idea.leader.position.y, idea.label.position.y + PinchLabel.LINE) and idea.leader.size.y > 20.0, "with a leader down to the box")
	var by_wall: StaticBody2D = dream.place_idea("door_boat", Vector2(40, 588))
	var by_right: StaticBody2D = dream.place_idea("window_yesterday", Vector2(1120, 588))
	await get_tree().physics_frame
	check(SCREEN.encloses(by_wall.label_rect()) and SCREEN.encloses(by_right.label_rect()) and by_wall.label_rect().position.x >= 0.0, "an idea by a wall keeps its name inside the room: %s, %s" % [by_wall.label_rect(), by_right.label_rect()])

	# ---------------------------------------------------------------- (K) the bed's and the block's words
	check(dream.jump_to_room("bed") and dream.bed != null and dream.block != null, "(the bed room)")
	var bed_name: Label = dream.bed.get_node("Name")
	var block_word: Label = dream.block.label
	check(bed_name.text == str(words.bed) and bed_name.position.y + bed_name.size.y <= -28.0 and bed_name.has_node("Backing"), "the bed's word '%s' sits above the bed, on a backing" % bed_name.text)
	check(block_word.text == str(words.block) and block_word.position.y + block_word.size.y <= -28.0, "the block's word '%s' above the block" % block_word.text)
	await free_dream()

	# ---------------------------------------------------------------- (L) the lantern, once; (M) the dev bar on the street
	var street_state := PinchState.new()
	street_state.day = 2
	street_state.small_things.assign(["spoon"])
	village = await new_village(street_state)
	var lantern_word: String = str(village_json.small_things.lantern_post)
	var lantern_labels := 0
	for label in village.find_children("*", "Label", true, false):
		if label.text == lantern_word:
			lantern_labels += 1
	check(lantern_labels == 1 and village.plot_node("lantern_post").get_meta("state") == "small_thing", "the lantern on its post is labelled once: '%s'" % lantern_word)
	bar = village.devbar
	check(bar != null and bar.visible and village.devbar_text() == str(sw.walk) and bar.actions_text() == village.devbar_text(), "on the street: '%s'" % village.devbar_text())
	frames = await walk_walker_to(village, village.DOOR_X)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.character_in_reach() == "jorun" and village.devbar_text() == sep.join([str(sw.walk), str(sw.talk)]), "by Jorun: '%s'" % village.devbar_text())
	frames = await walk_walker_to(village, village.BUNK.get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.bunk_in_range() and village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep)]), "at the bunk: '%s'" % village.devbar_text())
	street_state.has_pills = true
	await get_tree().process_frame
	check(village.devbar_text() == sep.join([str(sw.walk), str(sw.sleep), str(sw.pill)]), "with pills in the house: '%s'" % village.devbar_text())
	street_state.has_pills = false
	street_state.set_flag("asked:pills")
	frames = await walk_walker_to(village, village.plot_rect("stove_shed").get_center().x)
	await get_tree().process_frame
	check(frames < WALK_FRAMES and village.can_make() and village.devbar_text() == sep.join([str(sw.walk), str(sw.make)]), "at the stove shed with the request: '%s'" % village.devbar_text())
	street_state.ideas_kept.assign(["sixteen_stairs", "spoon"])
	village.start_breakfast()
	await get_tree().process_frame
	check(village.breakfast_on and village.devbar_text() == str(sw.breakfast).format({"idea": village.idea_name("sixteen_stairs")}) and village.devbar_text().contains("1 2 3"), "at breakfast with two on the table: '%s'" % village.devbar_text())
	village.set_hand(1)
	await get_tree().process_frame
	check(village.devbar_text() == str(sw.breakfast).format({"idea": village.idea_name("spoon")}), "2: '%s'" % village.devbar_text())
	street_state.ideas_kept.assign(["spoon"])
	village.hand_index = 0
	await get_tree().process_frame
	check(village.devbar_text() == str(sw.breakfast_one).format({"idea": village.idea_name("spoon")}) and not village.devbar_text().contains("1 2 3"), "with one: '%s'" % village.devbar_text())
	await press_key(KEY_TAB)
	check(not bar.visible and not street_state.devbar_visible, "Tab on the street hides the bar; the state remembers")
	village.end_breakfast("skipped")
	await free_village(village)
	await fresh(1, false, street_state)
	check(not dream.devbar.visible, "and the dream that night starts with it hidden")
	await press_key(KEY_TAB)
	check(dream.devbar.visible and street_state.devbar_visible, "Tab brings it back")
	await free_dream()

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


# --- helpers -------------------------------------------------------------------

## The dev bar's self-pinch line as it reads now (SPEC-2), the seconds left counting.
func hold_line() -> String:
	return str(devbar_json.dream.self_pinch).format({"s": "%.1f" % (dream.SELF_PINCH - dream.hold_seconds())})


## A new dream on `day` (with a pill if asked) on a fresh state, or on `with_state`; the old one gone.
func fresh(day: int, pill := false, with_state: PinchState = null) -> void:
	await free_dream()
	state = with_state if with_state != null else PinchState.new()
	state.day = day
	state.pill_tonight = pill
	dream = DREAM.instantiate()
	dream.state = state
	add_child(dream)
	dreamer = dream.dreamer
	acts = []
	dream.acted.connect(func(kind: String, detail: String) -> void: acts.append([kind, detail]))
	await get_tree().physics_frame


func free_dream() -> void:
	if dream != null:
		remove_child(dream)
		dream.queue_free()
		dream = null
		await get_tree().physics_frame


## A village on `with_state`, alone (its own panel), a few frames in.
func new_village(with_state: PinchState) -> Node2D:
	var village: Node2D = VILLAGE.instantiate()
	village.state = with_state
	add_child(village)
	for i in 3:
		await get_tree().physics_frame
	return village


func free_village(village: Node2D) -> void:
	remove_child(village)
	village.queue_free()
	await get_tree().physics_frame


func person(who: String) -> Dictionary:
	for c in people_json.characters:
		if c.id == who:
			return c
	return {}


## The labels under `root` that have no autowrap and whose text is wider
## than their box, or whose rect leaves `world` (the screen for a label on
## a CanvasLayer): "name 'text' (why)".
func labels_that_do_not_fit(root: Node, world: Rect2) -> Array[String]:
	var bad: Array[String] = []
	for label in root.find_children("*", "Label", true, false):
		var bounds := SCREEN if on_a_layer(label) else world
		var rect: Rect2 = label.get_global_rect()
		var inside := bounds.grow(0.5).encloses(rect)
		var fits := true
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			fits = PinchLabel.text_width(label) <= PinchLabel.box_width(label) + 0.5
		if not (inside and fits):
			bad.append("%s '%s' (%s%s %s)" % [label.name, label.text, "" if inside else "outside ", "" if fits else "too wide", rect])
	return bad


func on_a_layer(node: Node) -> bool:
	var p: Node = node
	while p != null and p != self:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false


func settle() -> void:
	for i in SETTLE:
		await get_tree().physics_frame


## Frames until the condition holds, or the budget runs out.
func wait_until(cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		await get_tree().physics_frame
		frames += 1
	return frames


## Hold one action until the condition holds, or the budget runs out.
func hold_until(action: String, cond: Callable, budget: int) -> int:
	var frames := 0
	while not cond.call() and frames < budget:
		Input.action_press(action)
		await get_tree().physics_frame
		frames += 1
	Input.action_release(action)
	await get_tree().physics_frame
	return frames


## Real seconds, accumulated from process delta, so the wait is the same at any refresh rate.
func wait_seconds(seconds: float) -> float:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited


## Real seconds until the condition holds or the timeout passes.
func wait_until_seconds(cond: Callable, timeout: float) -> float:
	var waited := 0.0
	while not cond.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited


## Walk the walker to within `near` px of x, or until the frames run out.
func walk_walker_to(village: Node2D, x: float, near := 8.0) -> int:
	var frames := 0
	while absf(village.walker.position.x - x) > near and frames < WALK_FRAMES:
		Input.action_press("move_right" if village.walker.position.x < x else "move_left")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_right")
	Input.action_release("move_left")
	await get_tree().physics_frame
	return frames


## Press and release a key through the input system, as a player would.
func press_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
