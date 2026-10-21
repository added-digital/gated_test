extends Node3D
## Rung 2's scripted walk, headless, through the physics engine. The player
## (scripts/player.gd) is driven by setting its auto_move every physics frame
## and moves only through move_and_slide: nothing on the route is teleported.
## Coordinates below are Blender's, as in the kit's scene JSON (x east, y
## north); Godot is (x, z, -y). Prints PASS/FAIL per check with positions
## and quits with 0 only if every check passes.
##
## The layout is the scale pass's 5 x 4 room (kit breaks.md 2026-10-21): the
## open shoji bay is the middle of the south wall at x = 2.5, the stone path
## runs up x = 2.5, the table stands at the room's centre (2.5, 2.0), and the
## 3 m bridge spans the pond's south row y = -4.5 from x = -2 to x = 1.
##
## 1. The walk: stone path south end (2.5, -6.5) north to (2.5, -1.5), onto
##    the engawa (2.5, -0.5), through the open bay (2.5, 0.0) onto the tatami
##    (2.5, 1.0). Arrival within 0.3 m in under 900 physics frames. Nothing
##    stands on that line: the table's south edge is at y = 1.6.
## 2. Closed shoji: from the engawa (0.5, -0.5) push north for 3 s; the body
##    must stay south of the wall line (y < 0).
## 3. Pond: from the gravel (1.5, -3.5) push west into the pond; the blocker
##    on the water tile (0.5, -3.5) must stop the body before that cell's
##    centre (its east edge is x = 1.0).
## 4. Bridge: from the gravel (1.5, -4.5) walk west across the bridge to the
##    gravel at (-2.5, -4.5) and arrive within 0.3 m. The deck is a gentle
##    arc (0.07 m at the tips, 0.47 m at the crest); the capsule climbs it
##    with no step-up logic, and the loader leaves no pond blocker on the
##    three water cells under the bridge's footprint.
## 5. The world's edge (re-walk, kit breaks.md 2026-10-21): from the gravel
##    tile at the garden's south-west corner (-2.5, -6.5) walk west for 120
##    frames (2 s, 7 m): off the garden's west edge at x = -3, 0.5 m from
##    the start, 0.30 m down onto the loader's invisible WorldFloor and on.
##    The feet must never go below -0.5 m, must end standing within 0.3 m of
##    ground level (at about -0.30 or above), and must have reached the
##    WorldFloor (below the gravel slab's bottom, -0.10) so the check cannot
##    pass without leaving the garden. West, not the diagonal: heading
##    south-west the capsule slides along the fence on y = -7 to its end and
##    wedges on the slab's corner edge against the last culm, where
##    move_and_slide cancels every frame's motion (scratch run 2026-10-21:
##    stuck at (-3.09, -6.69) from frame 17 on, feet -0.013, never leaving).

const TEAHOUSE := preload("res://scenes/teahouse.tscn")
const PLAYER := preload("res://scenes/player.tscn")

const SPAWN := Vector2(2.5, -6.5)
const ROUTE: Array[Vector2] = [Vector2(2.5, -1.5), Vector2(2.5, -0.5), Vector2(2.5, 0.0), Vector2(2.5, 1.0)]
const TABLE := Vector2(2.5, 2.0)      # the chabudai, 0.8 m square, at the room's centre
const BRIDGE_START := Vector2(1.5, -4.5)
const BRIDGE_END := Vector2(-2.5, -4.5)
const EDGE_START := Vector2(-2.5, -6.5)   # the garden's south-west gravel tile
const EDGE_DIR := Vector2(-1, 0)          # west, Blender: the nearest edge with no fence
const WORLD_FLOOR := -0.30                # teahouse_loader.gd's WorldFloor top
const SLAB_BOTTOM := -0.10                # the gravel slab's underside: below it the body has left the garden
const EDGE_DROP_LIMIT := -0.5             # the feet must never go below this
const GROUND_TOLERANCE := 0.3             # m: how far from ground level the walk may end
const ARRIVE := 0.3        # m: the task's arrival tolerance
const REACHED := 0.1       # m: close enough to steer for the next waypoint (the last one uses ARRIVE)
const WALK_FRAMES := 900   # physics frames allowed for the walk
const BRIDGE_FRAMES := 600 # physics frames allowed for the 4 m bridge crossing
const EDGE_FRAMES := 120   # 2 s heading west off the garden: 7 m at 3.5 m/s
const PUSH_FRAMES := 180   # 3 s of pushing against something that should hold

var teahouse: Node3D
var player: CharacterBody3D
var failures := 0


static func to_godot(b: Vector3) -> Vector3:
	return Vector3(b.x, b.z, -b.y)


static func to_blender(g: Vector3) -> Vector3:
	return Vector3(g.x, -g.z, g.y)


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func where() -> String:
	var b := to_blender(player.position)
	return "Blender (%.2f, %.2f, %.2f)" % [b.x, b.y, b.z]


func _ready() -> void:
	teahouse = TEAHOUSE.instantiate()
	add_child(teahouse)
	player = PLAYER.instantiate()
	player.position = to_godot(Vector3(SPAWN.x, SPAWN.y, 0.0))
	add_child(player)
	print("teahouse: %d pieces; player spawned at %s, Godot %s, facing -z" % [teahouse.placed, where(), player.position])
	await settle()
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "player stands on the stone path after settling, feet at y = %.3f" % player.position.y)

	await walk()

	var reach := await push(Vector2(0.5, -0.5), Vector2(0, 1), "north into the closed shoji at (0.5, 0.0)")
	check(reach.y < 0.0, "closed shoji holds: furthest y = %.2f, never crossed the wall line y = 0" % reach.y)

	reach = await push(Vector2(1.5, -3.5), Vector2(-1, 0), "west into the pond cell (0.5, -3.5), then (-0.5, -3.5)")
	check(reach.x > 0.5, "pond holds: furthest x = %.2f, blocked before the pond cell centre x = 0.5 (cell edge x = 1.0)" % reach.x)

	await cross_bridge()

	await walk_off_edge()

	print("RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


## Let gravity put the capsule on the floor before driving it.
func settle() -> void:
	player.auto_move = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame


## Steer toward each waypoint in turn, one physics frame at a time.
func walk() -> void:
	var frames := 0
	var next := 0
	var moved := 1.0   # metres moved in the last frame; about 0 means something blocks
	while next < ROUTE.size() and frames < WALK_FRAMES:
		var target := to_godot(Vector3(ROUTE[next].x, ROUTE[next].y, 0.0))
		var to := target - player.position
		to.y = 0.0
		var last := next == ROUTE.size() - 1
		# The last waypoint also counts as reached if the body is blocked
		# inside the arrival tolerance (nothing should block it now that the
		# table is 1 m further north, so the hit is printed if it happens).
		var blocked := last and to.length() < ARRIVE and moved < 0.001
		if to.length() < REACHED or blocked:
			print("  frame %3d: waypoint %s reached at %s%s" % [frames, ROUTE[next], where(), " (blocked here, %s)" % hits() if blocked else ""])
			next += 1
			moved = 1.0
			continue
		player.auto_move = to.normalized()
		var before := player.position
		await get_tree().physics_frame
		moved = player.position.distance_to(before)
		frames += 1
		if frames % 60 == 0:
			print("  frame %3d: %s %s" % [frames, where(), hits()])
	player.auto_move = Vector3.ZERO
	var goal := ROUTE[ROUTE.size() - 1]
	var dist := goal.distance_to(blender_xy())
	print("walk ended after %d frames at %s; %.2f m from the last waypoint %s, %.2f m from the table at %s" % [frames, where(), dist, goal, TABLE.distance_to(blender_xy()), TABLE])
	check(next == ROUTE.size(), "every waypoint on the route was reached (%d of %d)" % [next, ROUTE.size()])
	check(dist <= ARRIVE, "arrived on the tatami within %.1f m of %s (%.2f m)" % [ARRIVE, goal, dist])
	check(frames < WALK_FRAMES, "walk took %d physics frames, under %d" % [frames, WALK_FRAMES])
	check(hits() == "", "nothing blocks the walk's end (hits: '%s')" % hits())


## Place the player on the east approach, settle, then steer west over the
## bridge until the west approach is reached or the frames run out.
func cross_bridge() -> void:
	player.position = to_godot(Vector3(BRIDGE_START.x, BRIDGE_START.y, 0.0))
	await settle()
	print("bridge: from %s west to %s" % [where(), BRIDGE_END])
	var target := to_godot(Vector3(BRIDGE_END.x, BRIDGE_END.y, 0.0))
	var frames := 0
	var highest := 0.0   # the capsule's highest feet height on the way: proof it climbed the deck
	var furthest_west := BRIDGE_START.x
	var last_hit := ""
	while frames < BRIDGE_FRAMES:
		var to := target - player.position
		to.y = 0.0
		if to.length() < REACHED:
			break
		player.auto_move = to.normalized()
		await get_tree().physics_frame
		frames += 1
		highest = maxf(highest, player.position.y)
		furthest_west = minf(furthest_west, blender_xy().x)
		if hits() != "":
			last_hit = hits()
		if frames % 60 == 0:
			print("  frame %3d: %s %s" % [frames, where(), hits()])
	player.auto_move = Vector3.ZERO
	await settle()
	var dist := BRIDGE_END.distance_to(blender_xy())
	print("bridge crossing ended after %d frames at %s; %.2f m from %s; highest feet %.2f m; furthest west x = %.2f; %s" % [frames, where(), dist, BRIDGE_END, highest, furthest_west, "last hit " + last_hit if last_hit else "nothing pushed against"])
	check(dist <= ARRIVE, "bridge is walkable: arrived within %.1f m of %s (%.2f m)" % [ARRIVE, BRIDGE_END, dist])
	check(highest > 0.3, "the capsule climbed the deck's arc (highest feet %.2f m, the crest is 0.47 m)" % highest)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "back on the gravel after the bridge, feet at y = %.3f" % player.position.y)
	check(frames < BRIDGE_FRAMES, "crossing took %d physics frames, under %d" % [frames, BRIDGE_FRAMES])


## Place the player on the south-west gravel tile, settle, then walk west for
## EDGE_FRAMES frames: off the garden's west edge and onto the WorldFloor.
## Tracks the lowest feet height on the way and when the body left the garden.
func walk_off_edge() -> void:
	player.position = to_godot(Vector3(EDGE_START.x, EDGE_START.y, 0.0))
	await settle()
	print("edge: from %s west off the garden's south-west corner (edge x = -3) for %d frames" % [where(), EDGE_FRAMES])
	var dir := to_godot(Vector3(EDGE_DIR.x, EDGE_DIR.y, 0.0)).normalized()
	var lowest := player.position.y
	var left_garden_at := -1   # the frame the feet first went below the slab's bottom
	var respawned_at := -1     # the frame the body was put back at the spawn point
	var prev_y := player.position.y
	for i in EDGE_FRAMES:
		player.auto_move = dir
		await get_tree().physics_frame
		lowest = minf(lowest, player.position.y)
		if left_garden_at < 0 and player.position.y < SLAB_BOTTOM:
			left_garden_at = i + 1
			print("  frame %3d: below the slab's bottom at %s" % [i + 1, where()])
		if respawned_at < 0 and prev_y < -0.2 and player.position.y > -0.05 and player.position.distance_to(player.spawn_point) < 0.5:
			respawned_at = i + 1
			print("  frame %3d: back at the spawn point, %s" % [i + 1, where()])
		prev_y = player.position.y
		if (i + 1) % 30 == 0:
			print("  frame %3d: %s on floor: %s %s" % [i + 1, where(), player.is_on_floor(), hits()])
	player.auto_move = Vector3.ZERO
	await settle()
	print("edge walk ended after %d frames at %s; lowest feet %.3f m; %s; %s" % [EDGE_FRAMES, where(), lowest, "left the garden at frame %d" % left_garden_at if left_garden_at > 0 else "never left the garden", "respawned at frame %d" % respawned_at if respawned_at > 0 else "never respawned"])
	check(lowest >= EDGE_DROP_LIMIT, "the world's edge holds: feet never dropped below %.1f m (lowest %.3f m)" % [EDGE_DROP_LIMIT, lowest])
	check(lowest < SLAB_BOTTOM, "the body really left the garden (lowest feet %.3f m, below the slab's bottom %.2f)" % [lowest, SLAB_BOTTOM])
	check(respawned_at > 0, "stepping off the garden returned the walker to the start (respawned at frame %d)" % respawned_at)


## Place the player at start, settle, then push in a Blender direction for
## PUSH_FRAMES frames. Returns the furthest Blender position along the push.
func push(start: Vector2, dir: Vector2, what: String) -> Vector3:
	player.position = to_godot(Vector3(start.x, start.y, 0.0))
	await settle()
	print("push %s from %s" % [what, where()])
	var furthest := to_blender(player.position)
	var best := -INF
	var blocked_by := ""
	for i in PUSH_FRAMES:
		player.auto_move = to_godot(Vector3(dir.x, dir.y, 0.0))
		await get_tree().physics_frame
		var b := to_blender(player.position)
		var along := Vector2(b.x, b.y).dot(dir)
		if along > best:
			best = along
			furthest = b
		if hits() != "":
			blocked_by = hits()
	player.auto_move = Vector3.ZERO
	print("  after %d frames: furthest %s, ended at %s, %s" % [PUSH_FRAMES, furthest, where(), "blocked by " + blocked_by if blocked_by else "nothing in the way"])
	return furthest


func blender_xy() -> Vector2:
	var b := to_blender(player.position)
	return Vector2(b.x, b.y)


## Names of the kit pieces the capsule pushed against this frame (not the floor).
func hits() -> String:
	var names := []
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y > 0.7:
			continue   # the floor under the feet
		var node: Node = col.get_collider()
		while node.get_parent() != teahouse and node.get_parent() != null:
			node = node.get_parent()
		if not names.has(node.name):
			names.append(node.name)
	return "hit " + ", ".join(names) if names.size() > 0 else ""
