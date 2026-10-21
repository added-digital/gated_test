# Breaks

The only path that changes a number in `sakura_kit/contract.py`. One entry per snag:
date · where it was seen · the measurement · the contract line it touches · what changed.

| Date | Seen in | Measurement | Contract line | Change |
| --- | --- | --- | --- | --- |
| 2026-10-20 | first tatami render | border strips rendered black: coincident corner verts merged across shells, flipping normals | finish() | no `remove_doubles` across shells; shells stay separate |
| 2026-10-20 | first tatami render | palette colours rendered dark: 8-bit `pixels` take sRGB bytes, not linear | write_palette_image | hex values written as-is |
| 2026-10-20 | plan audit | wall thickness cap 0.30 m but the pillar post is 0.15 m: a 0.30 wall would poke 7.5 cm past its post | CATEGORY_RULES wall/door | `WALL_T_MAX = PILLAR_POST - 0.01` (0.14 m) |
| 2026-10-20 | plan audit | palette written at 1 px per cell; engines block-compress in 4x4 blocks and bleed neighbours | write_palette_image | 16 px per cell (128 x 64) |
| 2026-10-20 | plan audit | preview ground at z = -0.001 hides the pond tile's water surface at z = -0.02 | render_previews | ground at piece min z - 1 mm |
| 2026-10-20 | plan audit | custom properties (category, footprint) not in the GLBs | every glTF export | `export_extras=True`; added walkable, contract version, sockets |
| 2026-10-20 | plan audit | `check.py` exported a GLB for a failing piece | check.py | export only on pass; stale GLB removed |
| 2026-10-20 | assemble.py | the tea room has no open bay: every shoji is a closed panel | manifest | `door_shoji_1m_open` added |
| 2026-10-20 | assemble.py | both roof eaves placed at y = 1.0 with a bottom-centred pivot overlap into an X | roof pivot | roof origin moved to the ridge edge; `roof_origin_on_ridge` replaces the centred check for roofs |
| 2026-10-20 | first scene render | preview ground plane at z = -0.001 hid the pond in the assembled scene too | assemble.render | ground at -FLOOR_T - 0.02 |
| 2026-10-20 | mapcheck, first run | the only open bay was on the east wall, with no floor outside it: no tatami cell reachable from the path | layout rule | the open bay faces the engawa; mapcheck's flood fill is now the gate for every scene |
| 2026-10-20 | mapcheck, first run | two floors in cell (2, -2): an explicit path tile over a looped moss tile | layout rule | one floor per cell is checked; the path is one rule in the loop |
| 2026-10-20 | Godot 4.3 import (rung 2) | glTF node extras are not exposed as node metadata after import; the README claimed engines could read them | README, scene JSON | the JSON carries category and walkable per placement; README corrected; the untested editor-script scaffold removed (the real loader lives in the game repo) |
| 2026-10-20 | Godot 4.3 import (rung 2) | the embedded palette is extracted once per GLB: 27 identical 746-byte PNGs | export | harmless; a shared texture needs the palette exported as a separate file. Parked until a rung needs it |
| 2026-10-20 | headless walk (rung 2) | the 2 m bridge at x -2..0 spans a 3-cell pond (x -2..1): its east end lands in water, and pond blockers on every water cell make the bridge unwalkable | layout + collision rule | confirmed by the human walk 2026-10-21: bridge sits on the pond, pond not walkable. Decision: 3 m bridge spanning the whole pond, no blocker under a bridge footprint |
| 2026-10-21 | human walk, Godot 4.6.1, Apple M5 Pro | the room is too small to pass between the table and the door; the bridge "feels super small"; "everything is too close, not walkable" | scale: camera FOV (Godot default 75 vertical), capsule 0.35, room 3 x 2 m with a 0.8 m table and 4 cushions | OPEN, scale pass before Toys: FOV ~90 horizontal, capsule 0.30, room 5 x 4 tiles, 0.8 m clear around furniture, bridge 3 m. Re-walk to confirm |
| 2026-10-21 | human walk | pond water sits only 2 cm below the rim: "no height difference between water and the things around" | floor_water, pond edge | OPEN: water 15-25 cm below the bank, a visible bank or coping; needs a pond-edge piece family (demand-driven, parked until a rung asks) |
| 2026-10-21 | human walk | gravel garden and pond read as squares: the 1 m grid shows | kit coverage | OPEN, kit gap: organic edge and corner pieces (gravel-to-moss blends, curved pond edges). Parked until a toy or the slice needs them |
| 2026-10-21 | human walk | the world is static: no flowing water, falling petals, wind, chimes, koi, or sound | feel (foundation) | OPEN: "the garden moves and sounds" is a candidate first toy; motion and audio are not kit pieces. Parked in IDEAS.md with that note |
| 2026-10-21 | human walk | the project opened and ran on Godot 4.6.1 (pinned to 4.3) | engine pin | pin moves to the version the human runs, 4.6, at the scale pass |
