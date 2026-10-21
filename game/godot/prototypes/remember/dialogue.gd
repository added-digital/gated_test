extends RefCounted
## The conversation data of the Remember toy, read from dialogue.json.
## Nothing here touches the scene: it loads the file, checks that every
## "next" points at a node that exists, and picks the node to show for an
## id given what the player has said so far (the flags).
##
## The file: {"character": name, "ui": {hint lines}, "encounters": [{"start":
## node id, "then_walk_to": [x, z]}], "after": the node id that plays once the
## encounters are done, "nodes": [...]}. A node: {"id", "who",
## "text", then one of "next": id | "choices": [{"text", "next", "set":
## [flags]}] | "end": true; optionally "if": [flags] / "unless": [flags]}.
## Several nodes may share an id: the first whose "if" flags are all set and
## whose "unless" flags are all unset is the one shown. Put the conditional
## ones first and a plain one last, as the fallback.

const PATH := "res://prototypes/remember/dialogue.json"

var character := "Someone"
var ui := {}
var encounters: Array = []
var after := ""   # the node once every encounter is done; repeats
var nodes: Array = []
var error := ""   # "" once the file loaded and every link checked out


func load_file(path := PATH) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text != "" else null
	if typeof(data) != TYPE_DICTIONARY:
		error = "cannot read %s as a JSON object" % path
		return false
	character = data.get("character", character)
	ui = data.get("ui", {})
	encounters = data.get("encounters", [])
	after = data.get("after", "")
	nodes = data.get("nodes", [])
	error = _check_links()
	return error == ""


## The node to show for an id: the first with that id whose conditions hold.
func node_for(id: String, flags: Dictionary) -> Dictionary:
	for n in nodes:
		if n.get("id") == id and holds(n, flags):
			return n
	return {}


## True when every "if" flag is set and no "unless" flag is.
static func holds(node: Dictionary, flags: Dictionary) -> bool:
	for f in node.get("if", []):
		if not flags.has(f):
			return false
	for f in node.get("unless", []):
		if flags.has(f):
			return false
	return true


## A line that exists only because of what the player said earlier.
static func is_memory(node: Dictionary) -> bool:
	return node.has("if") or node.has("unless")


## Every encounter start and every "next" must name a node; every id needs
## a plain fallback node; every node needs a way on. One line per problem.
func _check_links() -> String:
	var plain := {}   # id -> has a node with no if/unless
	for n in nodes:
		if not n.has("id") or not n.has("text"):
			return "a node without id or text: %s" % n
		plain[n.id] = plain.get(n.id, false) or not is_memory(n)
	var problems: PackedStringArray = []
	for e in encounters:
		if not plain.has(e.get("start", "")):
			problems.append("encounter start '%s' is not a node" % e.get("start", ""))
	if not plain.has(after):
		problems.append("'after' names '%s', which is not a node" % after)
	for n in nodes:
		var targets := [n.next] if n.has("next") else []
		for c in n.get("choices", []):
			targets.append(c.get("next", ""))
		for t in targets:
			if not plain.has(t):
				problems.append("node '%s' points at '%s', which does not exist" % [n.id, t])
		if targets.is_empty() and not n.get("end", false):
			problems.append("node '%s' has no next, choices or end" % n.id)
	for id in plain:
		if not plain[id]:
			problems.append("id '%s' has no plain fallback node (one without if/unless)" % id)
	return "\n".join(problems)
