# Piece prompt (v0)

Paste this, then the brief, into a fresh model session. One piece per session.

---

You are authoring ONE piece of a low-poly Japanese sakura-garden game kit in
Blender, as a Python module. Read, in this order, before writing anything:

1. `CONTRACT.md` — the style contract. Every rule applies.
2. `sakura_kit/contract.py` — the `Piece` API you must build through:
   `box`, `cylinder`, `cone`, `sphere`, `plane`, `prism`, `wedge`, `mirror_x`,
   `paint`, `faces_facing`, `highest_faces`, `finish`. Raw `bmesh.ops` on
   `p.bm` are allowed if you `p.paint(new_faces, colour)` afterwards.
3. `pieces/wall_plain_1m.py` — a finished, approved piece. Match its shape:
   a docstring naming the real object, named constants, a `build()` that
   returns `Piece(...).finish()`.

Rules that trip people up (the "drift sheet"):

- Everything stands on z = 0 with its origin at the bottom centre. Floors are
  the exception: the walking surface is z = 0 and the slab hangs below.
- `box(..., anchor="bottom")` is the default: `at` is the base centre.
- Primitives are separate closed shells; let them overlap, never try to merge
  them. Overlapping volume is fine; coplanar exterior faces are not.
- Colours are palette names only (`PALETTE` in `contract.py`). Pink only on
  blossoms and at most one accent per prop.
- Walls and doors are exactly 1.0 m wide and 2.5 m tall and at most
  `WALL_T_MAX` thick (the pillar post is 0.15 m; walls are 0.12 m).
- Random only via `random.Random(<fixed seed>)`.

Loop: write `pieces/<name>.py`, run
`python -m sakura_kit.check <name> --no-render`, fix every failing line,
repeat until PASS (at most 6 runs). Then run the check with rendering and look
at `build/previews/sakura_<name>.png`. Fix anything floating, inside out, off
proportion or off palette (at most 3 render rounds). Return the validator's
last report and a one-line note on what was hard.

Never edit `sakura_kit/`, `CONTRACT.md` or another piece.
