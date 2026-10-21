# Sakura kit — style contract

One page. Every piece obeys all of it; `sakura_kit/validate.py` checks what a
script can check, and the contact sheet is how you check the rest by eye.

## Theme

Japanese garden and tea house in blossom season. Calm, low-poly, flat-shaded.
Pink is the accent, not the base: most of the kit is paper, pale wood, gravel
and moss, so a single sakura tree reads as the event in the scene.

## Scale and grid

| Rule | Value |
| --- | --- |
| Units | 1 Blender unit = 1 m. glTF export is Y-up (engine default). |
| Floor tile | exactly 1 × 1 m; walking surface at z = 0, slab hangs ≤ 0.1 m below (`FLOOR_T`; the pond tile ≤ 0.3 m, `FLOOR_T_MAX`: its water surface lies 0.20 m below the rim, 2026-10-21), surface detail (ridges, borders) may rise ≤ 0.02 m above |
| Wall / door segment | exactly 1 m wide (X), 2.5 m tall, ≤ 0.3 m thick, centred on Y = 0 |
| Shoji opening | 2 m tall; the top 0.5 m is lintel |
| Pillar | ≤ 0.25 × 0.25 m, exactly 2.5 m tall |
| Roof segment | exactly 1 m wide (X), ≤ 2.5 m deep, ≤ 1.5 m tall (the eave is 2.2 m deep with a 1.1 m rise, 2026-10-21: from the ridge at y = 2.0 of the 5 × 4 room one eave reaches 0.2 m past the wall); origin on the ridge edge (mesh from y = 0 to y = depth, sloping down toward +Y); placed at z = 2.5 on the ridge line by the assembler, two rows of 5 at rot 0 and rot 2 making a gable |
| Wall thickness vs post | `WALL_T_MAX = PILLAR_POST − 0.01` (0.14 m): a wall never pokes past the 0.15 m post it meets; built walls are 0.12 m |
| Props, garden pieces | fit inside one 1 × 1 m tile unless the piece declares a larger footprint; a garden piece may declare up to 3 × 2 m (the bridge is 3.0 × 1.2 m, 2026-10-21) |
| Trees | ≤ 3 × 3 m footprint, ≤ 5 m tall |
| Fine grid | 0.25 m for detailing; pieces snap at 1 m, rotate in 90° steps |

## Player and room

The body the kit is scaled for, from the first human walk (2026-10-21, `breaks.md`;
`contract.py` carries the same numbers as `PLAYER_*` and `CLEARANCE`).

| Rule | Value |
| --- | --- |
| Camera | first person, 90° **horizontal** field of view (Godot: Camera3D `keep_aspect = KEEP_WIDTH`, `fov = 90`); eye at 1.60 m |
| Body | capsule radius 0.30 m, height 1.80 m; walks at 3.5 m/s; no jump, no step-up, so a ledge it steps onto is under 0.09 m (a 0.30 capsule meets anything taller at more than 45°, a wall) |
| Tea room | 5 × 4 tiles (x 0..5, y 0..4); the table at the centre with ≥ 0.8 m clear on every side; engawa 5 tiles along the south edge; the open shoji bay in the middle of the south wall (x 2.5), closed shoji on the rest of it, plain walls elsewhere, pillars at the four corners; two rows of 5 eaves on the ridge line y = 2.0 |
| Bridge | `garden_bridge_3m`: 3.0 m along X, 1.2 m wide, deck arc 0.40 m (deck 0.07 m above the ground at the tips, 0.47 m at the crest), rails 1.0 m above the deck, footprint (3.0, 1.2); it spans the whole 3-cell pond (cells x −2..1, rows y −5..−3; bridge centred at (−0.5, −4.5)) |
| Pond | `floor_water`: water surface 0.20 m below the rim, slab to −0.30 m, `walkable: false`; no pond blocker on a water cell under a bridge footprint (`assemble.py` writes `footprint: [w, d]` into each placement that has one; mapcheck treats such a cell as walkable) |

## Origin

Bottom-centre of the footprint for everything that stands on the ground
(walls included: centre of the base edge). Floors: centre of the **top**
face, so a prop and a floor placed at the same grid point sit correctly.
Roofs: the centre of the **ridge edge**, the one exception, so eaves pair up
on a ridge line.

## Triangle budgets

floor 48 · wall 120 · door 300 · pillar 60 · roof 160 · prop 450 · garden 600 · tree 1400 · fx 12.
A piece may declare its own `sakura_tris_max` if it has a reason; say why in its docstring.

## Material and colour

One material for the whole kit, `sakura_palette`: a flat 8 × 4 palette
texture with nearest filtering. A face is coloured by pointing all its UVs at
one palette cell. No other textures, no vertex colours, no emission.

Palette names, in cell order (never reorder; append only):
sakura_light, sakura, sakura_deep, sakura_bud · wood_light, wood, wood_dark, bark ·
paper, paper_shadow, lattice, plaster · tatami, tatami_edge, cushion, cushion_dark ·
gravel, gravel_line, stone, stone_dark · moss, moss_dark, bamboo, bamboo_node ·
water, water_deep, roof_tile, roof_dark · vermilion, ink, gold, white.

Rules of use: wood for structure, paper for panels, lattice for frames and
dark trims. Pink only on blossoms, petals and one accent per prop at most.
Vermilion is for a single shrine-type accent in a scene, not for furniture.

## Form

- Flat shading. Silhouette first: a piece must be recognisable as a 48-px icon.
- Quads and tris only, no n-gons; no loose vertices; no unapplied modifiers; transforms identity.
- Detail is geometry, never texture: lattice bars, bamboo nodes, gravel ridges are modelled.
- Thin things have thickness (paper 0.01 m, lattice bars 0.02 m) so they do not vanish edge-on.
- Round things use 6 to 10 segments; canopies are subdivision-1 icospheres, scaled unevenly.
- Nothing floats: every part of a prop touches the ground or another part.

## Naming

`sakura_<category>_<name>[_<variant>]`, lowercase snake_case.
Categories: floor, wall, door, pillar, roof, prop, garden, tree, fx.
Variants are letters (`_a`, `_b`), sizes (`_1m`, `_2m`) or states (`_open`).

## Files

`pieces/<category>_<name>.py` exposes `build()` and returns the object through
`contract.Piece(...).finish()`. `python -m sakura_kit.build` validates, exports
`build/glb/*.glb`, `build/sakura_kit.glb`, `build/sakura_kit.blend`, renders
`build/previews/*.png` and `build/contact_sheet.png`, and writes `build/report.json`.
