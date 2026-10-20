# NOTES

Read this first, every session. Rung, question, evidence, kill date.

## Goal (rung 1)

**2026-10-20 — The player feels accomplished.**

Written by the designer after a 15-minute interview, before Godot was opened.
Gate: names a feeling, not an activity; no "and". Passed on reading aloud.

Texture from the interview, for later rungs (not part of the sentence):
calm is the home state; something breaks it; the feeling arrives when the
calm is put back. Must never feel repetitive, stagnant, or like a chore to
continue.

## Log

| Date | Rung | Question | Evidence this week | Kill date still true? |
| --- | --- | --- | --- | --- |
| 2026-10-20 | 1 Goal | What should the player feel? | The sentence above, read aloud | n/a |
| 2026-10-20 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | setup started by the AI | 2 evenings (6 h) from the first evening |
| 2026-10-20 | 2 Walk | Does the pipeline hold up in Godot, and is Godot the engine? | Verified headless in the cloud from a clean import cache (Godot 4.3.stable.official.77dcf97d8): tests/run.sh exit 0, ALL PASS; 110 of 110 pieces instanced, 110 StaticBody3D on 110 non-fx placements, 9 pond blockers on 9 walkable:false floors; walk path -> engawa -> open bay -> tatami in 155 of 900 physics frames, ends 0.24 m from (1.5, 0.5); closed shoji holds at y = -0.37 (never crossed y = 0); pond holds at x = 1.35 (east edge x = 1.0); player.gd/tscn use radius 0.35, height 1.8, camera 1.6, 3 m/s; palette 27 x lossless (compress/mode=0), no mipmaps, nearest, 128 x 64; kit git status clean (only the pre-existing untracked build/sakura_kit_glb.zip from 16:54). Still open: the human walk at target FPS on a GPU machine. | yes, 2 evenings: evening 1 used by the AI setup, evening 2 is the human walk |
