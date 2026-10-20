extends Node3D
## Rung 2's scripted walk, headless, through the physics engine. The player
## (scripts/player.gd) is driven by setting its auto_move every physics frame
## and moves only through move_and_slide: nothing on the route is teleported.
## Coordinates below are Blender's, as in the kit's scene JSON (x east, y
## north); Godot is (x, z, -y). Prints PASS/FAIL per check with positions
## and quits with 0 only if every check passes.
##
## 1. The walk: stone path south end (2.5, -6.5) north to (2.5, -1.5), onto
##    the engawa (2.5, -0.5), west to (1.5, -0.5), north through the open
##    shoji bay (1.5, 0.0) onto the tatami. The task names (1.5, 1.0) as the
##    end, but the kit's scene puts the 0.8 m chabudai exactly there (its
##    south edge at y = 0.6), so the last waypoint is (1.5, 0.5), the centre
##    of the tatami cell inside the bay; the distance to (1.5, 1.0) is
##    printed too. Arrival within 0.3 m in under 900 physics frames.
## 2. Closed shoji: from the engawa (0.5, -0.5) push north for 3 s; the body
##    must stay south of the wall line (y < 0).
## 3. Pond: push west from the gravel into the pond; the blocker on the water
##    tile must stop the body before the first pond cell's centre. The task's
##    start (0.5, -4.5) is itself a water cell and (1.5, -4.5) holds the stone
##    lantern, so the push runs along row -3.5: from (1.5, -3.5) toward
##    (-0.5, -3.5), blocked before x = 0.5.

const TEAHOUSE := preload("res://scenes/teahouse.tscn")
const PLAYER := preload("res://scenes/player.tscn")

const SPAWN := Vector2(2.5, -6.5)
const ROUTE: Array[Vector2] = [Vector2(2.5, -1.5), Vector2(2.5, -0.5), Vector2(1.5, -0.5), Vector2(1.5, 0.0), Vector2(1.5, 0.5)]
const ROOM_CENTRE := Vector2(1.5, 1.0)   # the task's named end point, under the table
const ARRIVE := 0.3        # m: the task's arrival tolerance
const REACHED := 0.1       # m: close enough to steer for the next waypoint (the last one uses ARRIVE)
const WALK_FRAMES := 900   # physics frames allowed for the walk
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
	print("teahouse: %d pieces; player spawned at %s, Godot %s, facing -z" % [teahouse.get_child_count(), where(), player.position])
	await settle()
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "player stands on the stone path after settling, feet at y = %.3f" % player.position.y)

	await walk()

	var reach := await push(Vector2(0.5, -0.5), Vector2(0, 1), "north into the closed shoji at (0.5, 0.0)")
	check(reach.y < 0.0, "closed shoji holds: furthest y = %.2f, never crossed the wall line y = 0" % reach.y)

	reach = await push(Vector2(1.5, -3.5), Vector2(-1, 0), "west into the pond cell (0.5, -3.5), then (-0.5, -3.5)")
	check(reach.x > 0.5, "pond holds: furthest x = %.2f, blocked before the pond cell centre x = 0.5 (cell edge x = 1.0)" % reach.x)

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
		# The last waypoint is under the table's edge, so it also counts as
		# reached when the body is blocked inside the arrival tolerance.
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
	print("walk ended after %d frames at %s; %.2f m from the last waypoint %s, %.2f m from the room centre %s (the table)" % [frames, where(), dist, goal, ROOM_CENTRE.distance_to(blender_xy()), ROOM_CENTRE])
	check(next == ROUTE.size(), "every waypoint on the route was reached (%d of %d)" % [next, ROUTE.size()])
	check(dist <= ARRIVE, "arrived on the tatami within %.1f m of %s (%.2f m)" % [ARRIVE, goal, dist])
	check(frames < WALK_FRAMES, "walk took %d physics frames, under %d" % [frames, WALK_FRAMES])


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
