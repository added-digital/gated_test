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
| 2026-10-20 | headless walk (rung 2) | the 2 m bridge at x -2..0 spans a 3-cell pond (x -2..1): its east end lands in water, and pond blockers on every water cell make the bridge unwalkable | layout + collision rule | OPEN, human decision at the walk: a 3 m bridge, a 2-cell pond, or no blocker under a bridge footprint |
