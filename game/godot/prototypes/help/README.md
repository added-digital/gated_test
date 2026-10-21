# Toy 2: Help

> I believe helping someone in a rush holds a confidant 5 minutes because it
> makes you feel like something important is happening.

Verb: help, under urgency. **Dead if not by 2026-10-28.**

Grey ground, a light strip of path between two grey posts 30 m apart, and a
capsule with a nose (the runner, someone in a rush) hurrying along it at
5 m/s, back and forth. Get within 3 m and they stop, turn to you and ask for
a crate: a 0.5 m grey box with its name floating above it, somewhere on the
field. A clock starts the moment they ask. Walk to the box, E picks it up
(it floats in front of you), bring it back, E hands it over. In time: they
thank you and hurry on; the next request comes once they have run to a post
and come back past you. Too late: they leave without it, and the next
request is still offered. Three requests, escalating: one crate close by
(40 s), one crate far past the end of the path (60 s), then two crates one
at a time in opposite directions on one tighter clock (45 s). After the
third, approaching them only gets a closing line.

## Run it

Open `prototypes/help/help.tscn` and press F6 (not F5). The full procedure,
and how to read the session log, is in [`../README.md`](../README.md).

| Key | Does |
| --- | --- |
| Mouse | look |
| W A S D | walk (3.5 m/s; the runner does 5) |
| E | pick up the crate when the hint says so; hand it over near the runner |
| Esc | free or recapture the mouse |
| F8 or close the window | end the session (closing writes the log) |

Nothing to press to talk: standing near the runner is the ask. The bottom
line is what they say; the small line under it is the clock (`40 s`) and
what to do next (where the box is, `E to pick up NOTES`, `Bring NOTES back
to them`, `E to hand over NOTES`).

## Three things to watch

1. **Do they hurry?** The clock is the toy. Watch whether the walk to the
   crate changes when the number is small: a confidant who keeps strolling
   at 25 s has not felt the urgency; one who turns and runs has. Note the
   second at which it changes, if it does.
2. **The hand-over.** The moment the crate is gone and the thanks line is up
   is where "accomplished" should land, if it lands. Watch their face and
   write down the first thing they say. Then watch what they do in the calm
   that follows while the runner is away: wait on the path, wander, or go
   looking for the next box early.
3. **The miss.** If a clock runs out, watch whether they go again. Someone
   who shrugs and walks off the field is a kill signal for the hypothesis;
   someone who waits for the runner to come back is the opposite. If nobody
   ever misses, the clocks in `requests.json` are too loose.

## The log

`toy_sessions/help_<date>T<time>.log` in the user data folder (paths in
[`../README.md`](../README.md); the Output panel prints the full path when
the toy starts). Actions: `pickup` and `deliver`, each with the crate's
name. Milestones: `request_1_done`, `request_2_done`, `request_3_done`,
and `too_late` the first time a clock runs out. A hand-over long after the
pickup in the timeline is a lost player, not a slow one.

## The words

Two files next to the scene; rewrite them, not the scripts.

- `requests.json`: the requests in order, each `ask` (what they say when
  they stop), `item` (the name on the box), `where` (the hint under the
  clock), `at` (the box's `[x, z]` on the field; the path runs along x from
  -15 to 15 at z = 0, you start at z = 6, the ground reaches 30 each way),
  `seconds` (the clock), `thanks`, `too_late`. A request may carry `then`:
  `{ask, item, where, at}` for a second box asked for after the first is
  handed over, on the same clock. Add a fourth request and it is offered
  after the third, with the milestone `request_4_done`.
- `words.json`: `start` (the first line on screen), `countdown` (`{seconds}`
  is filled in), `pick_up`, `bring_back`, `hand_over` (`{item}` is filled
  in), `after` (said when they are approached once every request is done).

## Files

| Path | What |
| --- | --- |
| `help.tscn` | the scene: ground, path, posts, runner, the player from `scenes/player.tscn`, the shared text panel and harness |
| `help.gd` | the toy: loads the two files, offers requests, spawns the crates, the clock, E, the harness calls |
| `runner.gd` | the runner: back and forth between two points, stops facing the player while a request is open, may stop again only after reaching an end |
| `../../tests/toy_help_test.gd` | the headless proof |

Headless check, from the project folder (import first):

```
<godot> --headless --path . --import
<godot> --headless --fixed-fps 60 --path . res://tests/toy_help_test.tscn --quit-after 20000
```

It drives the player to the runner, reads request 1, fetches the crate,
presses E, brings it back, hands it over and expects `request_1_done`;
meets the runner again, lets request 2 run out and expects `too_late`; then
meets them once more and expects request 3 still offered. `RESULT: 0
failure(s)` and exit 0; it leaves one `help_*` log in `toy_sessions/`.
