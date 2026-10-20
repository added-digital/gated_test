# Sakura kit

A low-poly, flat-shaded modular game kit: a Japanese tea house and garden in
blossom season. 27 pieces, one palette, one material, 1 m grid, Y-up glTF.
Built by code against a style contract, so every piece is a short script and
the whole kit rebuilds from source in about a minute, no Blender install
needed.

## What is here

| Path | What |
| --- | --- |
| `CONTRACT.md` | the style contract, one page; `sakura_kit/contract.py` is the same rules as code |
| `pieces/*.py` | one script per piece; `build()` returns the object |
| `sakura_kit/validate.py` | the validator: 20 hard checks, 4 warnings |
| `sakura_kit/check.py` | check one piece: validate, export, preview |
| `sakura_kit/build.py` | build everything: GLBs, `.blend`, previews, contact sheet, report |
| `assemble.py` | the test scene (tea house + garden), rendered and exported, plus `scenes/teahouse.json` |
| `tests/` | broken pieces that must fail, and their runner |
| `PIECE_PROMPT.md` | what to paste into a fresh model session to author one more piece |
| `DECISIONS.md`, `breaks.md` | taste verdicts, and the only path that changes a contract number |
| `build/` | outputs (regenerated; `glb/` per piece, `sakura_kit.glb`, `contact_sheet.png`, `scene_teahouse.png`) |

## Build

```
python3.13 -m venv .venv && .venv/bin/pip install bpy==5.2.2 pillow
.venv/bin/python -m sakura_kit.build          # everything -> build/
.venv/bin/python -m sakura_kit.check prop_tea_set   # one piece
.venv/bin/python assemble.py                  # the test scene
.venv/bin/python -m tests.run_broken          # the validator's own test
```

## Using the GLBs in an engine

- Units are metres; do not rescale on import (Unreal: glTF import scale 100).
- Floors are 1 x 1 m with the walking surface at the origin; everything else
  has its origin at the bottom centre; roofs at the ridge edge. Snap at 1 m,
  rotate in 90-degree steps.
- One texture, `sakura_palette` (128 x 64). Import it Lossless, filter
  Nearest, mipmaps off (Godot); Point filter, no compression (Unity); no
  compression, nearest (Unreal). Bilinear filtering or compression will bleed
  the palette cells.
- Every GLB node carries glTF extras: `sakura_category`, `sakura_contract_version`,
  `sakura_walkable` (floors), `sakura_footprint` (pieces larger than a tile)
  and `sakura_socket_px/nx/py/ny` (what each side expects to meet). Godot 4.3
  does not expose them after import, so take category and walkability from
  `scenes/teahouse.json`, which carries both per placement. Derive collision
  from the category: trimesh for floor, wall, door, pillar, roof and garden;
  convex for prop and tree; none for fx.
- The working Godot project is in the game repo (`game/godot/`): a loader that
  builds the scene from the JSON with collision, a first-person capsule, and
  headless tests that prove the walk.
- `scenes/teahouse.json` is the assembled scene as `{piece, x, y, z, rot,
  category}` in Blender's z-up metres. Godot position is `(x, z, -y)`.

## Status (2026-10-20)

Contract v0.2. All 27 pieces pass the validator; the test scene assembles
with nothing missing. Not yet walked in an engine: that is Phase 1 of the
plan, and `breaks.md` is where what the walk finds goes.
