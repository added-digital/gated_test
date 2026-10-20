# Sakura Walk (rung 2: Walk)

A Godot 4.3 project that builds the kit's tea house from `kit/scenes/teahouse.json`
and lets you walk it in first person. The question this rung answers: does the
asset pipeline hold up in Godot, and is Godot the engine?

The AI set the project up and proved the walk headless, in the cloud, with no
GPU (verified 2026-10-20 from a clean import cache: every check PASS, exit 0;
see `tests/last_run.log`). Nothing is left running and nothing needed your
machine. The one part only you can do: open it on a computer with a GPU, walk
it, and read the frame rate.

## Open it (10 minutes)

1. Install Godot 4.3 stable from godotengine.org (the version is pinned in
   `project.godot`; if 4.4 or later offers to convert the project, say no and
   use 4.3). Copy this whole `godot/` folder to that machine.
2. Project Manager > Import > pick `project.godot` > Import & Edit. The first
   open imports the 27 GLBs (a few seconds). Do not change any import setting:
   `project.godot` forces the palette to Lossless, no mipmaps, and the GLBs
   carry nearest filtering.
3. Press F5 (Run Project). `scenes/main.tscn` is the main scene: the tea house,
   the contract sun (elevation 40, azimuth 35, warm ambient) and the player at
   the south end of the stone path, facing the house.

## Controls

| Key | Does |
| --- | --- |
| Mouse | look (the mouse is captured while you play) |
| W A S D | walk, 3 m/s |
| Esc | free the mouse; Esc again to capture it |
| F8 or close the window | quit |

No jump, no run, no interaction: walking is the whole game on this rung.

## The walk, and what to look at

Walk the stone path north, step onto the engawa, turn left, go through the
middle shoji bay (the open one) onto the tatami. Then try the closed bays and
the pond edge.

- Frame rate: Debugger > Monitors > Time > FPS in the editor's bottom panel
  while the game runs. Note the number on the path, on the engawa and inside
  the room, where most pieces are in view. Write the three numbers down.
- The palette: flat, clean colour cells, no bleeding at cell edges, no blur at
  distance. If something looks smeared, the texture import changed.
- Edges that should meet: wall to pillar, roof eave pairs at the ridge, floor
  tiles to each other. Gaps or z-fighting are kit snags.
- Collision: you should walk the path, step onto the engawa, pass through the
  open bay, be stopped by the closed bays, the walls and the low table, and
  be stopped at the pond's edge. The bridge is not walkable yet (see snags).
  A small bump inside the bay is the cushion (0.08 m tall); the capsule steps
  onto it.
- Scale: the doorway (2 m) should feel like a doorway at eye height 1.6 m.

## The headless proof

`tests/run.sh` imports the project and runs `tests/walk_test.tscn` with no GPU,
writing `tests/last_run.log`, exit 0 only if every check passed. It drives the
player through the physics engine (`move_and_slide`, nothing teleported along
the route): path south end to the engawa, through the open bay onto the
tatami, then two negative checks: pushing into a closed shoji must not cross
the wall line, pushing into the pond must stop at the tile's edge.

```
GODOT=/path/to/Godot_v4.3-stable tests/run.sh      # macOS/Linux, or Git Bash on Windows
```

Last verified run (clean cache, 2026-10-20): 110 pieces, walk in 155 of the
900 physics frames allowed, ends 0.24 m from the tatami cell centre; closed
shoji holds at y = -0.37; pond holds at x = 1.35. `tests/load_test.tscn`
checks the build itself: 110 bodies on 110 non-fx placements, 9 pond
blockers, rotation sign, palette 128 x 64 lossless, nearest, no mipmaps, sun.

## Files

| Path | What |
| --- | --- |
| `project.godot` | config 5, Godot 4.3, Forward+, default physics, WASD input map, palette import defaults |
| `kit/glb/*.glb`, `kit/scenes/teahouse.json` | byte-identical copies from `/home/user/sakura-kit/build/glb` and `scenes/` |
| `scripts/teahouse_loader.gd` | reads the JSON at `_ready`, places each piece at `(x, z, -y)`, `rotation_degrees.y = rot * 90`, trimesh/convex collision by category, box blocker on `walkable: false` floors |
| `scripts/player.gd` | the walker: capsule 0.35 x 1.80 (in `player.tscn`), camera at 1.60, 3 m/s, mouse look, gravity. `auto_move` is how tests drive it; about 45 lines, read it top to bottom |
| `scenes/main.tscn` | tea house + sun + ambient + player |
| `tests/walk_test.gd` | the scripted walk; `tests/load_test.gd` checks the build, rotation sign, palette and sun |

## Snags: where to log them

- A kit piece that is wrong (a gap, a bad pivot, a colour, collision that
  does not match the mesh): `/home/user/sakura-kit/breaks.md`, one line per
  snag, with the measurement. Do not edit the kit from this project.
- Anything about the rung itself (FPS numbers, feel, the engine verdict):
  `/home/user/game/NOTES.md`, a new row in the log table.

Known already, waiting for your call (not fixed, by the rules of this rung):

- The task's walk ended at the room centre (1.5, 1.0); the scene puts the
  0.8 m table exactly there, so the test ends at (1.5, 0.5), the tatami cell
  inside the open bay, and the body stops 0.24 m short of it against the
  table. Accept the tatami cell as the goal, or move the table (level design,
  a later rung).
- The pond is 3 x 3 cells (x = -1.5, -0.5, 0.5) but the bridge at x = -1
  spans only x = -2..0, so its east end lands in the water cell (0.5, -4.5),
  and the pond blockers stand on both cells the bridge crosses: the bridge
  cannot be walked. The pond check therefore runs along row y = -3.5. For
  breaks.md: 3 m bridge, 2-wide pond, or blockers that skip cells under a bridge.
- Godot 4.3 does not expose the GLBs' glTF extras as node metadata; the loader
  takes category and walkable from the JSON instead. The kit's scaffold
  `godot/import_scene.gd` reads `get_meta("extras")` and would get nothing.
- Godot extracts the embedded palette once per GLB: 27 identical
  `<piece>_sakura_palette.png` files in `kit/glb/`. Harmless; sharing one
  texture needs the kit to export the palette as a separate file.
