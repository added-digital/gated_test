# PINCH, the loop toy — spec

Rung 3, toy 4. Grey boxes. One hypothesis, one kill date, one question.
The concept it tests: `game/concepts/pass-2/1-pinch.md` (chosen by the designer
2026-10-22 from two concept passes). This page is what gets built; the concept
is what it might become. Where they differ, this page wins.

## The sentences

- Goal (rung 1, the designer's): **The player feels accomplished.**
- Hypothesis (the designer's words will replace these at the gate):
  **I believe pinch-to-grab under a closing frame, paid off by one building
  standing on the street per idea each morning, with grey boxes holds a
  confidant 20 minutes because the frame is a bar the body reads without
  being told and the lit window is a reward the eye reads without being told,
  so each half makes the other one matter; dead if not by 2026-11-10.**
- The verb: *the player pinches themself to grab an idea before the dream
  dissolves.*
- The 20-minute question: **does the player go to bed a fourth time without
  being asked, and can they say what they are going down for?**

## The loop, one night

1. **Evening, the street.** Side view. Walk to the Long House, press E at the
   bunk. Sleep.
2. **The dream.** Yawn upside down under the ice. Rooms, one screen each.
   Asleep you drift: no gravity, currents carry you, you pass through soft
   things, your hand passes through everything. Hold PINCH and the world snaps
   sharp: gravity, solid ledges, you can jump, grab, set down, push. Ideas are
   the only crisp things. Every act of control raises lucidity; wonder lowers
   it; the frame (a dark vignette) closes as lucidity rises. At the limit you
   wake. Your bed is somewhere in the dream, in the wrong place: lie in it and
   you wake gently with everything.
3. **Waking.** Sudden: the ideas you carried float over the bunk and fade; you
   keep ONE. Gentle (the bed): you keep all. Tove marks the wall.
4. **Breakfast.** Ninety seconds. Three villagers at the table, eyelids
   drooping. Put each idea in front of the one who would want it, judged from
   one line of want. Right face: "I dreamed that." Wrong face: "that's not
   mine." When the last head drops, the telling is over.
5. **Day.** A claimed idea rises as a building on its plot (scaffold by day,
   standing with a lit window by the next morning; the dark at the end of the
   street pulls back one tile). An unclaimed idea becomes a small thing (a
   bench, a sign). Walk, talk, then back to the bunk.

## What is in the toy (counts)

| Thing | Count | Detail |
| --- | --- | --- |
| Street | 1 | side view, about 4 screens wide; the dark mask at each end recedes one tile per building |
| Standing buildings | 3 | Long House (bunk, table, tally wall), Jorun's hut, stove shed |
| Buildable plots | 3 | Sixteen Stairs (Jorun), Bo's loft (Bo), a lantern post (unclaimed small thing) |
| Dream screens | 8 | 1 tutorial room, 6 rooms, 1 locked ladder ("you don't know this story yet") |
| Rooms dealt per night | 4 | plus the bed room, placed last; order shuffled per night |
| Ideas | 6 | Sixteen Stairs, A Door That Is Also a Boat, The Smell of Bread, Bo's Big Needle, A Window Facing Yesterday, A Spoon |
| Characters | 3 | Tove (the Long House, keeps the tally), Jorun (heckles, remembers), Bo (hats) |
| Creature | 1 | the goat: a rideable current. In from the start so that staying asleep is a verb |
| Upgrades | 2 | a better bunk (lucidity limit +2, Tove's request after night 2), a taller hat (carry 2 to 3, Bo's request after his loft stands) |
| Lines | about 40 | plus memory lines keyed to flags |

## Lucidity, exactly

Lucidity is an integer. It moves only on acts, never while the button is held.

| Act | Change |
| --- | --- |
| grab an idea | +2 |
| set an idea down (to stand on it) | +1 |
| force (push a block, open a door) | +1 |
| fall onto a floor while pinched (a drop taller than one body) | +1 |
| wonder (drift through a soft wall; ride the goat; stand still 3 s in a marked spot) | −1, once per wonder per visit |

`effective = lucidity + ideas carried`. Limit: 8 (10 with the better bunk).
`effective >= limit` → sudden waking. The frame's aperture is
`1 − effective / limit`. Nothing else is shown: no number, no bar. A screen
failed (fall off the bottom, touch a hazard) blinks shut and reopens at the
room's door one second later, +1 lucidity; nothing else is lost.

Carry: 2 ideas under the hat (3 with the taller hat). An idea in the hand
counts double while held. Set-down puts it on the floor as a solid step.

## Breakfast, exactly

Three seats, three faces, each with one line of want shown above the head
("Jorun: wants to get down to the lake without the ladder"). The player
carries each kept idea to a face and presses E. The right face claims it
(the idea's `whose`); the wrong face says no and keeps its eyes shut for the
rest of breakfast. A head drops every 30 s; three heads, ninety seconds. An
idea nobody claimed at the end becomes a small thing. The player can skip
breakfast (walk away): every carried idea becomes a small thing.

## Out of scope (returns only as a character's request, only after the fourth unprompted bedtime)

Coin and Pim the peddler. Layer 2 and the Village As It Was. Someone's Auntie
and the reveal. The sun on the horizon and the end of winter. Seasons. The
Swallow. Per-villager sound leaks (one sound leak only: the stove). Shaders
beyond one blur toggle. Art of any kind. A second verb. Music.

## Presentation

Godot 4.6, 2D, side view, in the existing project under
`game/godot/prototypes/pinch/`. Grey boxes: ColorRects and simple polygons.
Ideas are white with a black outline and a drop shadow, the only crisp things
in the dream; everything else in the dream is drawn through one blur toggle
(or, headless, flagged `soft`). The frame is four black ColorRects on a
CanvasLayer closing inward, or a vignette shader; either is fine, headless
tests read the aperture value, not pixels.

## Files

```
prototypes/pinch/
  SPEC.md                 this page
  README.md               run instructions, controls, three things to watch (written day 5)
  pinch.tscn / pinch.gd   the controller: day counter, state, swaps village and dream, waking, keep-one
  state.gd                one Resource: day, lucidity limit, carry limit, ideas (carried / kept / built), flags, tally
  village.tscn / .gd      the street, plots, bunk, table, tally wall, characters, breakfast
  dream.tscn / .gd        the room dealer, the frame, lucidity, the bed room
  dreamer.gd              the player in the dream: asleep drift and pinched physics
  walker.gd               the player on the street
  rooms/room_*.tscn       one screen each; tutorial, six rooms, the ladder; each declares its soft and crisp layers, its currents, wonders, idea spawn points, door and exit
  data/ideas.json         id, name, whose, becomes (building plot or small thing), one line
  data/characters.json    name, want (one line), lines keyed to flags, request (upgrade) and when
tests/toy_pinch_test.gd/.tscn   headless play-through
```

The harness `prototypes/_shared/toy_harness.gd` logs milestones:
`slept_1`, `grabbed`, `woke_sudden`, `woke_gentle`, `kept:<idea>`,
`told:<idea>:<who>`, `built:<plot>`, `slept_2` … `slept_4`.

## Verification (every day ends with something the designer can play)

- Headless, from a clean import, before anything is called done: the toy
  scene runs 300 frames clean; `toy_pinch_test` passes: sleep, the dream
  loads with 4 rooms and a bed, lucidity counts match the acts table, the
  frame's aperture matches `effective`, sudden waking keeps exactly one,
  gentle waking keeps all, breakfast assigns by `whose`, a claimed idea's
  plot shows a scaffold that day and a building the next morning, the dark
  mask recedes, the tally increments, `slept_4` is reachable by script.
- The designer plays each evening (Gated - local) and writes three
  observations in NOTES.
- One confidant, week of 2026-11-03, twenty minutes, the question above.

## Build, five Claude days

| Day | Lands | Playable as |
| --- | --- | --- |
| 1 | controller, state, the street with buildings and plots and the dark mask, the walker, the bunk, sleep → a stub dream (one empty room) → the frame → waking → keep-one → morning, day counter, tally; headless test for all of it | walk the street, sleep, watch the frame close, wake, see day 2 |
| 2 | dreamer physics: asleep drift with currents, pinched gravity and jump, soft and crisp layers, the goat; lucidity table; the tutorial room and two rooms | drift, pinch, climb, ride the goat, wake |
| 3 | ideas: found, taken, carried (hat stack), set down as a step, lost on waking; the bed room; wonder spots; three more rooms; the ladder | grab an idea and bring it home, or push and lose it |
| 4 | breakfast; buildings rise; Tove, Jorun, Bo with wants, lines, memory; the two requests and upgrades | the whole loop, four nights |
| 5 | the sixth room, balance of the lucidity numbers, README, the three things to watch, the harness log, a full headless run of four nights | the toy as the confidant will see it |

Each day: pull, build, headless verify from a clean import, commit, push,
hand-off line in NOTES. The local session plays the evening after.
