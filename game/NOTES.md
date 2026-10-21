# NOTES

Read this first, every session. Rung, question, evidence, kill date.

## Decisions

- 2026-10-21 · Engine: Godot stays (4.6). Re-decided only through a written kill line.
- 2026-10-21 · Walk: walkable after the scale pass. Rung 2 passed.

## Goal (rung 1)

**2026-10-20 — The player feels accomplished.**

Written by the designer after a 15-minute interview, before Godot was opened.
Gate: names a feeling, not an activity; no "and". Passed on reading aloud.

Texture from the interview, for later rungs (not part of the sentence):
calm is the home state; something breaks it; the feeling arrives when the
calm is put back. Must never feel repetitive, stagnant, or like a chore to
continue.

## Toys (rung 3)

Question: which single interaction is worth repeating? Proof: three grey-box toys, three verbs, each played by a confidant. Gate: one toy holds a confidant 5 minutes and their words match the Goal.

| Toy | Hypothesis (designer's words) | Verb | Dead if not by |
| --- | --- | --- | --- |
| 1 Remember | I believe choosing replies to a character who remembers what you said holds a confidant 5 minutes because it makes your decisions feel important. | choose, with consequence | 2026-10-24 |
| 2 Help | I believe helping someone in a rush holds a confidant 5 minutes because it makes you feel like something important is happening. | help, under urgency | 2026-10-28 |
| 3 Far sound | I believe hearing something interesting far away but being blocked from getting there holds a confidant 5 minutes because it turns on brain activity to find a way there. | find the way | 2026-10-31 |

Rules in force: grey boxes only; a kit piece only if a line names it as the verb's object; no goals, menus, polish, or a second verb in one toy; two sessions per toy; a confidant plays each one.

## Log

| Date | Rung | Question | Evidence this week | Kill date still true? |
| --- | --- | --- | --- | --- |
| 2026-10-21 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | GATE PASSED. Human re-walk after the scale pass: "walkable" and "Godot stays for now" (designer's words). Pipeline holds in Godot 4.6.1. Open feel items carried into breaks.md: pond tiling, canopy contrast, prop scale, world edge, roundness of pond and garden. | n/a |
| 2026-10-20 | 1 Goal | What should the player feel? | The sentence above, read aloud | n/a |
| 2026-10-20 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | setup started by the AI | 2 evenings (6 h) from the first evening |
| 2026-10-21 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | Human walk done on Godot 4.6.1 / Apple M5 Pro: the project ran; pipeline holds. Findings in breaks.md (scale is the foundation break; bridge/pond as predicted; the world is static). Engine decision not yet written. | yes: evening 2 used; one re-walk after the scale pass |
| 2026-10-20 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | Verified headless in the cloud from a clean import cache (Godot 4.3.stable.official.77dcf97d8): tests/run.sh exit 0, ALL PASS; 110 of 110 pieces instanced, 110 StaticBody3D on 110 non-fx placements, 9 pond blockers on 9 walkable:false floors; walk path -> engawa -> open bay -> tatami in 155 of 900 physics frames, ends 0.24 m from (1.5, 0.5); closed shoji holds at y = -0.37 (never crossed y = 0); pond holds at x = 1.35 (east edge x = 1.0); player.gd/tscn use radius 0.35, height 1.8, camera 1.6, 3 m/s; palette 27 x lossless (compress/mode=0), no mipmaps, nearest, 128 x 64; kit git status clean (only the pre-existing untracked build/sakura_kit_glb.zip from 16:54). Still open: the human walk at target FPS on a GPU machine. | yes, 2 evenings: evening 1 used by the AI setup, evening 2 is the human walk |
| 2026-10-21 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | Headless re-verification in the cloud after the scale pass, from a clean import cache (Godot 4.6.1.stable.official.14d19694e): kit build 27/27 PASS with 0 warning lines (roof eave 140 tris 1.0 x 2.2 x 1.112; bridge_3m 816 tris 3.0 x 1.2 x 1.49; floor_water 36 tris 1.0 x 1.0 x 0.3), validator fixtures 4/4 fail as expected, mapcheck PASS (141 placements, 1 bridge decking 3 pond cells, 73 cells reachable); tests/run.sh exit 0, ALL PASS: 141 of 141 pieces instanced, walk path -> engawa -> open bay (2.5, 0.0) -> tatami (2.5, 1.0) in 128 of 900 physics frames, ends 0.08 m from the goal with nothing touching the capsule (table 1.08 m away); closed shoji holds at y = -0.32; pond holds at x = 1.30; the bridge is walked from (1.5, -4.5) to (-2.5, -4.5) in 71 frames, 0.05 m from the goal, feet up to 0.47 m on the crest, back on the gravel at 0.006 m; load_test 0 failures: 141 StaticBody3D, 6 pond blockers (9 water cells, 3 decked by the bridge footprint), 10 convex + 131 trimesh, rotation sign, palette 128 x 64 lossless nearest no mipmaps, sun; player.tscn radius 0.30, height 1.8, camera 1.6, keep_aspect KEEP_WIDTH, fov 90; SPEED 3.5; project.godot features 4.6. Nothing committed. Still open: the human re-walk on the GPU machine and the engine verdict. | yes: one re-walk after the scale pass |
