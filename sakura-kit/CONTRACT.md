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
| Floor tile | exactly 1 × 1 m; walking surface at z = 0, slab hangs ≤ 0.1 m below, surface detail (ridges, borders) may rise ≤ 0.02 m above |
| Wall / door segment | exactly 1 m wide (X), 2.5 m tall, ≤ 0.3 m thick, centred on Y = 0 |
| Shoji opening | 2 m tall; the top 0.5 m is lintel |
| Pillar | ≤ 0.25 × 0.25 m, exactly 2.5 m tall |
| Roof segment | exactly 1 m wide (X), ≤ 1.5 m deep, ≤ 1.5 m tall; origin on the ridge edge (mesh from y = 0 to y = depth, sloping down toward +Y); placed at z = 2.5 on the ridge line by the assembler, rot 0 and rot 2 making a gable |
| Wall thickness vs post | `WALL_T_MAX = PILLAR_POST − 0.01` (0.14 m): a wall never pokes past the 0.15 m post it meets; built walls are 0.12 m |
| Props, garden pieces | fit inside one 1 × 1 m tile unless the piece declares a larger footprint |
| Trees | ≤ 3 × 3 m footprint, ≤ 5 m tall |
| Fine grid | 0.25 m for detailing; pieces snap at 1 m, rotate in 90° steps |

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
