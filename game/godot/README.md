# Sakura Walk (rung 2: Walk)

A Godot 4.6 project that builds the kit's tea house from `kit/scenes/teahouse.json`
and lets you walk it in first person. The question this rung answers: does the
asset pipeline hold up in Godot, and is Godot the engine?

The AI set the project up and proved the walk headless, in the cloud, with no
GPU (verified 2026-10-20 from a clean import cache: every check PASS, exit 0;
see `tests/last_run.log`). Nothing is left running and nothing needed your
machine. The one part only you can do: open it on a computer with a GPU, walk
it, and read the frame rate.

## Open it (10 minutes)

1. Install Godot 4.6.1 stable from godotengine.org (`project.godot` pins 4.6,
   the version you walked it on; 4.3 also opens and runs it, the headless
   proof passed on both). Copy this whole `godot/` folder to that machine.
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
| W A S D | walk, 3.5 m/s |
| Esc | free the mouse; Esc again to capture it |
| F8 or close the window | quit |

No jump, no run, no interaction: walking is the whole game on this rung.

## The walk, and what to look at

Walk the stone path north: it leads straight onto the engawa and through
the middle shoji bay (the open one, at x = 2.5) onto the tatami; the low
table sits at the room's centre with 0.8 m clear around it, cushions on its
west, east and north sides. Then try the closed bays and the pond edge, and
cross the bridge: it leaves the gravel east of the pond, arcs over the
pond's south row and lands on the gravel west of it.

- Frame rate: Debugger > Monitors > Time > FPS in the editor's bottom panel
  while the game runs. Note the number on the path, on the engawa and inside
  the room, where most pieces are in view. Write the three numbers down.
- The palette: flat, clean colour cells, no bleeding at cell edges, no blur at
  distance. If something looks smeared, the texture import changed.
- Edges that should meet: wall to pillar, roof eave pairs at the ridge, floor
  tiles to each other. Gaps or z-fighting are kit snags.
- Collision: you should walk the path, step onto the engawa, pass through the
  open bay, be stopped by the closed bays, the walls and the low table, be
  stopped at the pond's edge, and walk the bridge end to end (its deck rises
  0.47 m at the crest; the capsule climbs it with no step-up logic). The
  cushions (0.08 m tall) are bumps the capsule steps onto.
- Scale: the doorway (2 m) should feel like a doorway at eye height 1.6 m.
  The camera is 90 degrees horizontal (`keep_aspect` KEEP_WIDTH), the capsule
  0.30 m: the scale pass's numbers (kit `breaks.md`, 2026-10-21).

## The headless proof

`tests/run.sh` imports the project and runs `tests/walk_test.tscn` with no GPU,
writing `tests/last_run.log`, exit 0 only if every check passed. It drives the
player through the physics engine (`move_and_slide`, nothing teleported along
the route): path south end (2.5, -6.5) to (2.5, -1.5), onto the engawa
(2.5, -0.5), through the open bay (2.5, 0.0) onto the tatami (2.5, 1.0),
arriving within 0.3 m; then two negative checks: pushing north into the
closed shoji at (0.5, 0.0) must not cross the wall line, pushing west into
the pond from the gravel (1.5, -3.5) must stop at the tile's edge; then the
bridge: from the gravel (1.5, -4.5) west across the bridge to the gravel
(-2.5, -4.5), arriving within 0.3 m with the feet back on the ground.

```
tests/run.sh                                        # macOS/Linux, or Git Bash on Windows
GODOT=/path/to/Godot_v4.6.1-stable tests/run.sh     # another binary (4.3 also passes)
```

`GODOT` defaults to the 4.6.1 Linux binary in the AI's scratchpad.

Last verified run (clean cache, 2026-10-21, Godot 4.6.1.stable.official,
after the scale pass): 141 pieces, walk in 128 of the 900 physics frames
allowed, ends 0.08 m from (2.5, 1.0) with nothing touching the capsule
(the table is 1.08 m away); closed shoji holds at y = -0.32; pond holds at
x = 1.30; the bridge crossing takes 71 frames, ends 0.05 m from (-2.5, -4.5),
feet up to 0.47 m on the crest and back on the gravel at 0.006 m.
`tests/load_test.tscn` checks the build itself: 141 bodies on 141 non-fx
placements, 6 pond blockers (9 water cells, 3 of them decked by the bridge's
footprint), 10 convex and 131 trimesh shapes, rotation sign, palette
128 x 64 lossless, nearest, no mipmaps, sun. Before the scale pass the same
tests passed on the 3 x 2 room on 4.6.1 (110 pieces, 135 frames, 0.20 m)
and on 4.3 on 2026-10-20 (155 frames, 0.24 m, y = -0.37, x = 1.35, with the
old 0.35 m capsule at 3 m/s).

## Files

| Path | What |
| --- | --- |
| `project.godot` | config 5, Godot 4.6, Forward+, default physics, WASD input map, palette import defaults |
| `kit/glb/*.glb`, `kit/scenes/teahouse.json` | byte-identical copies from `/home/user/sakura-kit/build/glb` and `scenes/` |
| `scripts/teahouse_loader.gd` | reads the JSON at `_ready`, places each piece at `(x, z, -y)`, `rotation_degrees.y = rot * 90`, trimesh/convex collision by category, box blocker on `walkable: false` floors except cells under a bridge's `footprint` (a garden piece named `*bridge*`; the footprint turns with `rot`) |
| `scripts/player.gd` | the walker: capsule 0.30 x 1.80 and the camera at 1.60 with a 90-degree horizontal field of view (both in `player.tscn`), 3.5 m/s, mouse look, gravity. `auto_move` is how tests drive it; about 45 lines, read it top to bottom |
| `scenes/main.tscn` | tea house + sun + ambient + player |
| `tests/walk_test.gd` | the scripted walk, the two negative checks and the bridge crossing; `tests/load_test.gd` checks the build, the bridge-footprint blocker rule, rotation sign, palette and sun |

## Snags: where to log them

- A kit piece that is wrong (a gap, a bad pivot, a colour, collision that
  does not match the mesh): `/home/user/sakura-kit/breaks.md`, one line per
  snag, with the measurement. Do not edit the kit from this project.
- Anything about the rung itself (FPS numbers, feel, the engine verdict):
  `/home/user/game/NOTES.md`, a new row in the log table.

Known already, waiting for your call (not fixed, by the rules of this rung):

- Fixed by the scale pass (kit `breaks.md` 2026-10-21), to confirm on the
  re-walk: the room is 5 x 4 with the table at its centre and the walk ends
  clear of it; the 3 m bridge spans the whole pond and the loader leaves no
  blocker on the three water cells under its `footprint`, so the bridge is
  walked end to end in the headless test; the pond water is 0.20 m below
  the rim. The eaves still stop 0.2 m past the wall, so the engawa is not
  under the roof (the decided numbers; a deeper eave is a later call).
- Godot 4.3 does not expose the GLBs' glTF extras as node metadata; the loader
  takes category and walkable from the JSON instead. The kit's scaffold
  `godot/import_scene.gd` reads `get_meta("extras")` and would get nothing.
- Godot extracts the embedded palette once per GLB: 27 identical
  `<piece>_sakura_palette.png` files in `kit/glb/`. Harmless; sharing one
  texture needs the kit to export the palette as a separate file.
