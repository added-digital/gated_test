class_name PinchState
extends Resource
## The one state of toy 4, PINCH (rung 3): what day it is, the limits, which
## ideas are carried, kept and built, the tally of sudden wakings and the
## memory flags. One instance lives in the controller (pinch.gd) and is
## handed to the village and the dream before they enter the tree; nothing
## else holds state.

const TILE := 256.0          # px: one tile of street; the dark recedes one tile per building
const BASE_LIT_TILES := 3    # tiles lit on each side of the Long House before anything stands

var day := 1
var lucidity_limit := 8      # 10 with the better bunk (day 4)
var carry_limit := 2         # 3 with the taller hat (day 4)
var ideas_carried: Array[String] = []   # under the hat, in the dream now
var ideas_kept: Array[String] = []      # carried up and kept at waking, not yet told
var ideas_built := {}                   # plot id -> idea id, standing on the street
var tally := 0                          # nights woken suddenly: one mark each on the wall
var flags := {}                         # memory: name -> value


## Tiles lit on each side of the Long House: three, plus one per building standing.
func lit_tiles() -> int:
	return BASE_LIT_TILES + ideas_built.size()


## Reads one of the toy's data/*.json files; null (and an error) if it cannot.
static func load_json(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("[pinch] cannot read %s" % path)
	return data
