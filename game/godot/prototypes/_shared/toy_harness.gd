extends Node
## The session recorder every toy shares (rung 3, Toys). Added to each toy
## scene as a Node named "Harness". It counts what the player does and when,
## and writes one log per session so the designer can read how long a
## confidant stayed and what they did, without watching over their shoulder.
##
## API (the toy phases use it exactly):
##   start(toy_name)            starts the clock; call it once, in the toy's _ready
##   action(kind, detail = "")  counts one thing the player did, with its time
##   milestone(name)            records a first-time-only event with its time
##   summary()                  the session text (the same text the log holds)
##
## When the harness leaves the tree (the window is closed, the game quits,
## the scene changes) it writes user://toy_sessions/<toy>_<timestamp>.log
## and prints the same summary to stdout. It also rewrites that file every
## SAVE_EVERY seconds, so stopping the game from the editor's Stop button
## (which kills the process with no exit) loses at most that much.

const DIR := "user://toy_sessions"
const SAVE_EVERY := 10.0   # s between periodic rewrites of the log

var toy_name := "untitled"
var started_at := ""   # local date-time the clock started, also in the file name
var log_path := ""     # user:// path of this session's log; set at the first write

var _start_ms := 0
var _actions: Array[Dictionary] = []     # {t: ms since start, kind, detail}, in order
var _counts := {}                        # kind -> how many times
var _milestones: Array[Dictionary] = []  # {t: ms since start, name}, first time only
var _since_save := 0.0
var _closed := false   # the final write is done; nothing more is recorded or written


func _ready() -> void:
	if _start_ms == 0:
		_begin()   # a toy that never calls start() still gets a clock and a log


## Names the toy and starts the clock. Anything recorded before is dropped.
func start(name_of_toy: String) -> void:
	toy_name = name_of_toy.strip_edges().replace(" ", "_")
	_begin()
	print("[harness] %s: session started %s; the log will be %s" % [toy_name, started_at, ProjectSettings.globalize_path(_path())])


## One thing the player did: a kind ("choose", "talk", "push"...) and an
## optional detail (which reply, which door). Timestamped since start().
func action(kind: String, detail: String = "") -> void:
	if _closed:
		return
	_actions.append({"t": _elapsed_ms(), "kind": kind, "detail": detail})
	_counts[kind] = _counts.get(kind, 0) + 1


## A named first: recorded with its time the first time only, then ignored.
func milestone(name_of_milestone: String) -> void:
	if _closed:
		return
	for m in _milestones:
		if m.name == name_of_milestone:
			return
	_milestones.append({"t": _elapsed_ms(), "name": name_of_milestone})
	print("[harness] %s  milestone: %s" % [_clock(_elapsed_ms()), name_of_milestone])


## The session as text: minutes played, actions per minute (and per kind),
## the milestones with their times, then every action in order.
func summary() -> String:
	var ms := _elapsed_ms()
	var minutes := ms / 60000.0
	var rate_base := maxf(minutes, 1.0 / 60.0)   # at least one second, so a short run does not divide by zero
	var lines: PackedStringArray = []
	lines.append("toy: %s" % toy_name)
	lines.append("session: %s" % started_at)
	lines.append("played: %.1f minutes (%d s)" % [minutes, ms / 1000])
	lines.append("actions: %d (%.1f per minute)" % [_actions.size(), _actions.size() / rate_base])
	for kind in _counts:
		lines.append("  %s: %d" % [kind, _counts[kind]])
	lines.append("milestones: %d" % _milestones.size())
	for m in _milestones:
		lines.append("  %s  %s" % [_clock(m.t), m.name])
	lines.append("timeline:")
	for a in _actions:
		lines.append("  %s  %s%s" % [_clock(a.t), a.kind, ("  " + a.detail) if a.detail != "" else ""])
	lines.append("log: %s" % ProjectSettings.globalize_path(_path()))
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _closed:
		return
	_since_save += delta
	if _since_save >= SAVE_EVERY:
		_since_save = 0.0
		_write()


func _exit_tree() -> void:
	_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finish()   # the window's close button; the tree exit that follows then does nothing


func _begin() -> void:
	_start_ms = Time.get_ticks_msec()
	started_at = Time.get_datetime_string_from_system(false, false)   # local, "2026-10-21T19:04:05"
	_actions = []
	_counts = {}
	_milestones = []
	_since_save = 0.0


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _start_ms


## mm:ss since start.
static func _clock(ms: int) -> String:
	var s := ms / 1000
	return "%02d:%02d" % [s / 60, s % 60]


func _path() -> String:
	return "%s/%s_%s.log" % [DIR, toy_name, started_at.replace(":", "-")]


## The final write and the stdout summary, once.
func _finish() -> void:
	if _closed:
		return
	_write()
	_closed = true
	print("[harness] session over\n" + summary())


func _write() -> void:
	var err := DirAccess.make_dir_recursive_absolute(DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[harness] cannot create %s (error %d)" % [DIR, err])
		return
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_warning("[harness] cannot write %s (error %d)" % [_path(), FileAccess.get_open_error()])
		return
	f.store_string(summary() + "\n")
	f.close()
	log_path = _path()
