# Toy 3: Far sound

> I believe hearing something interesting far away but being blocked from
> getting there holds a confidant 5 minutes because it turns on brain
> activity to find a way there.

Verb: find the way. **Dead if not by 2026-10-31.**

Fix round (2026-10-21, after the designer's own play: arrived at 0:20, the
blocked part held about fifteen seconds, then 40 s of wandering with
nothing left to find): the verb now repeats as **three searches in
sequence, each longer than the last**. Still one verb, still grey boxes,
still nothing to press. Only one chime rings at a time.

1. **The courtyard** (as before). You start in a grey courtyard, 12 m wide,
   walls 2.5 m tall, open behind you. Ahead, through the walls, a wind
   chime: faint where you stand, clear once close, never seen. Straight
   ahead the wall has an obvious gap; it leads into an alley that bends
   twice and ends. Out the open back and round the outside works, the
   long way. In the east wall, behind a baffle a metre off it, a 0.9 m
   slit you can just squeeze through is the short way. Chime 1 is a light
   grey box 18 m from the spawn. Walk up to it: the ringing stops, one
   resolved chord plays, a line appears.
2. **The yard.** Three seconds later a second chime starts, 27 m away to
   the south-west, inside a walled 12 m square whose only opening faces
   west, away from everything. The chime sits just behind the yard's east
   wall: in the corridor between the courtyard and the yard it is three
   metres from you and you cannot get to it. The slit is no help this
   time. The way is round the outside of the yard, either side, to the
   far opening, then back in to the chime.
3. **The pen.** Three seconds after that, a third chime, 26 m away to the
   east, inside a 14 by 16 m pen. It rings three metres behind a lighter
   grey slab set in the pen's west wall: a gate, and it does not move
   from your side. The way is round the pen to its opening on the east
   wall, in, and across: stepping into the pen's west half slides the
   slab aside, and it stays open. The chime stops, the chord, the last
   line; the gate is now the short way back. That is the end of the toy.

## Run it

Open `prototypes/far_sound/far_sound.tscn` and press F6 (not F5). The full
procedure, and how to read the session log, is in
[`../README.md`](../README.md). Headphones or decent speakers: the sound
is the toy. It is a 3D sound, so it sits left or right as you turn.

| Key | Does |
| --- | --- |
| Mouse | look |
| W A S D | walk (3.5 m/s) |
| Esc | free or recapture the mouse |
| F8 or close the window | end the session (closing writes the log) |

No E, no numbers: walking is the whole verb. The first line (`Do you hear
that?`) shows for 4 seconds and goes; each arrived line shows until the
next chime starts, and the last one stays.

## Three things to watch

1. **The three blocked moments.** Each search has one place where the
   chime is close and the wall is in the way: the alley's dead end (search
   1), the corridor along the yard's east wall (search 2), the closed gate
   (search 3). Note what they do in the ten seconds after each: look at
   the walls and set off round (the hypothesis working), or stand still
   (lost: note how long). The log has the time of each: `dead_end`,
   `gate_found`, and for the yard the `route west corridor going south`
   action against `arrived_2`. The designer's own blocked part held about
   fifteen seconds; what we want to see is whether the second and third
   hold longer, and whether the player speeds up or slows down from one
   search to the next.
2. **The listening and the turn-arounds.** Does the sound steer them? Stops,
   head turns, walking toward the louder side. If they wander with no
   relation to the sound, the attenuation is wrong or the chime is too
   soft for their speakers (knobs below). Watch the moment each new chime
   starts, three seconds after a chord: do they hear it, where do they
   turn, and do they go at once? In the yard search, watch whether they
   try the slit again out of habit (the log shows `narrow out` after
   `arrived_1`). In the pen search, watch what they do at the closed gate:
   push, walk its length, or go round at once; and their face when it
   slides open from the inside.
3. **The three arrivals and the end.** The chime stops and the chord plays:
   that is where "accomplished" lands, if it lands, three times. Write
   down the first thing they say at each, unprompted, and whether the
   third lands harder, the same, or less than the first (the gate asks
   about accomplishment, and the sequence is the bet that it grows). After
   the last chord there is nothing more: watch whether they walk back out
   through the open gate (the shortcut they earned; `gate out` in the
   log), explore, or stop; note the time they stop against `played`.

A kill signal: a confidant who gives up at the dead end or in the
corridor by the yard, or who never notices the sound. A tuning signal: if
nobody finds the slit, shorten the baffle in `layout.gd`; if the yard or
the pen is found too fast, move its opening (the numbers in `layout.gd`
and the `Gate` and `GateTrigger` nodes).

## The log

`toy_sessions/far_sound_<date>T<time>.log` in the user data folder (paths
in [`../README.md`](../README.md); the Output panel prints the full path
when the toy starts).

Actions:

- `gap_used`: `obvious out` / `obvious back` (the gap in the courtyard's
  north wall), `narrow out` / `narrow back` (the slit), `yard in` /
  `yard out` (the yard's west opening), `pen in` / `pen out` (the pen's
  east opening), `gate in` / `gate out` (through the gate once it is open).
- `route`: which way round they went: `west corridor` or `east corridor`
  (between the courtyard and the yard or the pen) `going north` /
  `going south`; `north of the yard`, `south of the yard`, `north of the
  pen`, `south of the pen` `going west` / `going east`.

Milestones: `left_courtyard` (the first time they are outside the walled
square, by any way), `dead_end` (standing in the alley's last stub),
`arrived_1`, `arrived_2`, `arrived_3` (each chime reached), `gate_found`
(standing at the closed gate on the corridor side), `gate_opened` (the
trigger on the far side fired). A session that is all `obvious out` /
`obvious back` pairs is someone re-checking the dead end: watch them. The
gap between `gate_found` and `gate_opened` is how long the third blocked
part held them.

## The words and the map

- `lines.json`: `start` (shown for 4 s at the spawn), `arrived_1`,
  `arrived_2`, `arrived_3` (one each, shown at the chime; the first two
  clear when the next chime starts). Rewrite it, not the script.
- `layout.gd`: the walls, one line each (`name, from (x, z), to (x, z)`
  on the ground; x east, z south, you start at (0, 0) facing north, -z),
  with an ASCII map of the three blocks at the top; also the courtyard,
  the dead-end stub, the five openings, the gate's gap and slide, and the
  crossing lines the toy counts (`CROSSINGS`), as numbers the toy reads.
  Move a wall's end points and the toy follows; an opening's numbers are
  used to count `gap_used`, so move those with their walls.
- The chime boxes: `Source1` (0, 0.5, -18), `Source2` (-12, 0.5, 6),
  `Source3` (13, 0.5, 0) in the scene, each with a `Chime` player
  (attenuation inverse square, `unit_size` 7: full volume within 7 m,
  about -16 dB at 18 m, -24 dB at 27 m; `max_db` 3) and a `Chord` player.
  Louder from afar: raise `unit_size`; a steeper "getting closer": lower
  it. Chime 2 must be 25 to 35 m from chime 1 (the test checks).
- The gate: the `Gate` node (an `AnimatableBody3D`, 3.2 m wide, 0.35 m
  inside the pen's west wall, in the gap `GATE_Z` that `layout.gd` leaves
  there) and the `GateTrigger` node (an `Area3D`, the pen's west half, a
  metre clear of the slab). Stepping into the trigger slides the slab by
  `GATE_SLIDE` (3.5 m north, 1.2 s) and it stays there. Move the gap, the
  slab and the trigger together.
- The sounds: `chime.wav` (20 s of soft chime strikes around 880, 1320 and
  1760 Hz at irregular intervals, with loop points over the whole file so
  it loops end to end; the three sources share it) and `chord.wav` (one A
  major chord, 3 s). `make_sounds.py` makes both again (`python
  make_sounds.py`, needs numpy); change the frequencies, the spacing or
  the length there.

## Files

| Path | What |
| --- | --- |
| `far_sound.tscn` | the scene: ground, the `Walls` node (built by `layout.gd`), the three chime boxes with their players, the gate slab and its trigger, the player from `scenes/player.tscn`, the shared text panel and harness |
| `far_sound.gd` | the toy: the start line and its timer, the three searches in sequence and the pause between them, the gate, the crossings and the milestones for the harness |
| `layout.gd` | the map: the wall table, the box builder, the courtyard, dead end, openings, gate and crossing-line numbers |
| `lines.json` | the four lines |
| `chime.wav`, `chord.wav`, `make_sounds.py` | the sounds and the script that makes them |
| `../../tests/toy_far_sound_test.gd` | the headless proof |

Headless check, from the project folder (import first, so the WAVs exist
as resources):

```
<godot> --headless --path . --import
<godot> --headless --fixed-fps 60 --path . res://tests/toy_far_sound_test.tscn --quit-after 20000
```

It checks the two WAVs load and the chime's loop points came through, the
three sources and their players exist, chime 1 plays alone, chime 2 is 25
to 35 m from chime 1, chime 3 sits behind the gate, and a ray from the eye
at the spawn to chime 1 hits a wall; then drives the player through all
three searches along waypoints: the obvious gap to the dead end and back,
the slit and round the block to chime 1 (`arrived_1`, the loop stopped,
the chord playing, the line up, chime 2 starting 3 s later alone, its
direct line blocked by a wall); round the north of the yard and in
(`arrived_2`, chime 3 alone, blocked by a wall); out of the yard, round
its south, up the east corridor to the gate (`gate_found`, the ray hits
the slab, 45 frames of pushing get nowhere); round the pen, in at the far
side (`gate_opened` before `arrived_3`, the slab slid clear, the line
through the gate clear); and back out through the gate (`gate out`). It
also checks that no frame ever had two chimes playing and that each
scripted search took more frames than the one before. Sound itself cannot
play headless. `RESULT: 0 failure(s)` and exit 0; it leaves one
`far_sound_*` log in `toy_sessions/`.
