# Toy 3: Far sound

> I believe hearing something interesting far away but being blocked from
> getting there holds a confidant 5 minutes because it turns on brain
> activity to find a way there.

Verb: find the way. **Dead if not by 2026-10-31.**

A grey courtyard, 12 m wide, walls 2.5 m tall, open behind you. Ahead,
through the walls, a wind chime rings: faint where you stand, clear once
you are close. You cannot see it. Straight ahead the wall has an obvious
gap; it leads into an alley that bends twice and ends. Out the open back
and around the outside of the whole block works, the long way. In the east
wall, behind a baffle standing a metre off it, a 0.9 m slit you can just
squeeze through is the short way. Walk up to the chime (a light grey box
18 m from the spawn) and the ringing stops, one resolved chord plays, and
one line appears. That is all: no goal text, no score, nothing to press.

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
that?`) shows for 4 seconds and goes; the arrived line stays.

## Three things to watch

1. **The dead end.** Nearly everyone will take the obvious gap first. Watch
   the moment they reach the stub and understand it ends: do they say
   anything, and what do they do in the next ten seconds: look at the walls
   (the hypothesis working), walk out the back to go around (fine, the
   long way), or stand still (lost: note how long). The log's `dead_end`
   time against `left_courtyard` says how fast the trap took them.
2. **The listening.** Does the sound steer them? Watch for stops, head
   turns, walking toward the louder side. If they wander with no relation
   to the sound, the attenuation is wrong or the chime is too soft for
   their speakers (knobs below). The slit: note whether they find it by
   looking (the baffle is a strange object; curiosity) or by chance; and
   the words when they realise they fit through.
3. **The arrival.** The chime stops and the chord plays: that is where
   "accomplished" lands, if it lands. Watch their face; write down the
   first thing they say, unprompted. Then watch what they do with the
   calm: turn back to try the other way (good), explore the empty block
   (fine), or stop playing (the toy ended there; note the time).

A kill signal: a confidant who leaves the courtyard only once and gives
up at the dead end, or who never notices the sound. A tuning signal: if
nobody finds the slit, shorten the baffle in `layout.gd`.

## The log

`toy_sessions/far_sound_<date>T<time>.log` in the user data folder (paths
in [`../README.md`](../README.md); the Output panel prints the full path
when the toy starts). Actions: `gap_used` with `obvious out` / `obvious
back` (the gap in the north wall) and `narrow out` / `narrow back` (the
slit). Milestones: `left_courtyard` (the first time they are outside the
walled square, by any way), `dead_end` (standing in the alley's last
stub), `arrived`. A session that is all `obvious out` / `obvious back`
pairs is someone re-checking the dead end: watch them.

## The words and the map

- `lines.json`: `start` (shown for 4 s at the spawn) and `arrived`.
  Rewrite it, not the script.
- `layout.gd`: the walls, one line each (`name, from (x, z), to (x, z)`
  on the ground; x east, z south, you start at (0, 0) facing north, -z),
  with an ASCII map at the top; also the courtyard, the two gaps and the
  dead-end stub as numbers the toy reads. Move a wall's end points and the
  toy follows; the two gap lines are used to count `gap_used`, so move
  those numbers with their walls.
- The chime box: the `Source` node in the scene, at (0, 0.5, -18). The
  `Chime` player under it: attenuation inverse square, `unit_size` 7 (full
  volume within 7 m, about -16 dB at the spawn), `max_db` 3. Louder at
  the spawn: raise `unit_size`; a steeper "getting closer": lower it.
- The sounds: `chime.wav` (20 s of soft chime strikes around 880, 1320 and
  1760 Hz at irregular intervals, with loop points over the whole file so
  it loops end to end) and `chord.wav` (one A major chord, 3 s).
  `make_sounds.py` makes both again (`python make_sounds.py`, needs
  numpy); change the frequencies, the spacing or the length there.

## Files

| Path | What |
| --- | --- |
| `far_sound.tscn` | the scene: ground, the `Walls` node (built by `layout.gd`), the chime box with its two players, the player from `scenes/player.tscn`, the shared text panel and harness |
| `far_sound.gd` | the toy: the start line and its timer, the arrival, the gap crossings and the milestones for the harness |
| `layout.gd` | the map: the wall table, the box builder, the courtyard, gap and dead-end numbers |
| `lines.json` | the two lines |
| `chime.wav`, `chord.wav`, `make_sounds.py` | the sounds and the script that makes them |
| `../../tests/toy_far_sound_test.gd` | the headless proof |

Headless check, from the project folder (import first, so the WAVs exist
as resources):

```
<godot> --headless --path . --import
<godot> --headless --fixed-fps 60 --path . res://tests/toy_far_sound_test.tscn --quit-after 6000
```

It checks the two WAVs load and the chime's loop points came through, the
players exist and the chime plays, a ray from the eye at the spawn to the
chime hits a wall; then drives the player through the obvious gap to the
dead end and back (`dead_end`, `gap_used obvious out`/`back`), then behind
the baffle, through the slit (`gap_used narrow out`, proof the capsule
fits), round the outside to the chime: `arrived`, the loop stopped, the
chord playing, the arrived line up. Sound itself cannot play headless.
`RESULT: 0 failure(s)` and exit 0; it leaves one `far_sound_*` log in
`toy_sessions/`.
