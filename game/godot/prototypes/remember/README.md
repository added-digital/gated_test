# Toy 1: Remember

> I believe choosing replies to a character who remembers what you said holds
> a confidant 5 minutes because it makes your decisions feel important.

**Dead if not by 2026-10-24.** Verb: choose, with consequence.

## What it is

A grey 30 x 30 m ground, you, and Pim: a grey capsule with a name over it,
waiting for painters who said Tuesday. Walk up, press E, talk. Three
encounters: after each, Pim says goodbye and glides 8 to 10 m away; follow
and press E for the next. Everything you say is kept. Encounter 2 greets you
by the name you gave. Encounter 3 quotes you back (the day, the promise),
changes mood by the colour you guessed, decides by what you told Pim to do,
and holds you to the promise you made, or didn't, in encounter 1, which
nothing in encounter 2 mentions. After the third goodbye Pim has one more
line that depends on how you ended it. Target: 4 to 6 minutes; the scripted
play shows 25 lines and 7 choices, plus three walks.

## Run it

Open `prototypes/remember/remember.tscn` and press F6. The full procedure
(hand over the keyboard, end by closing the window so the log writes, where
the log lands on each OS) is in [`../README.md`](../README.md).

## Controls

| Key | Does |
| --- | --- |
| Mouse | look |
| W A S D | walk |
| E | talk when the hint says so; next line while talking |
| 1 2 3 | pick a reply (or Esc to free the mouse and click one) |
| Esc | free or recapture the mouse |
| F8 or close the window | end the session (writes the log) |

## Three things to watch

1. **Encounter 3, when Pim quotes them.** The day they named, the promise,
   the name: do they react (a laugh, "oh, it remembered", leaning in)? That
   reaction is the hypothesis. No reaction means the memory is not landing:
   the quote is too subtle, or they forgot what they said.
2. **At each choice: do they pause, or press 1 at once?** A pause means the
   decision feels like it matters. Note which choices they hesitate on (the
   promise? the name?) and which they do not.
3. **Between encounters.** When Pim walks off, do they follow at once or
   wander? After the third goodbye, do they go back and press E again
   unprompted? Going back is wanting more; wandering off is the toy running
   out.

Write down what they say, unprompted, the moment they stop.

## The session log

`toy_sessions/remember_<date>T<time>.log` in the project's user data folder
(the paths are in [`../README.md`](../README.md); the Output panel prints
the full path when the toy starts and the whole summary when it ends).
Milestones: `memory_shown` (the first line picked by an earlier reply, at
the latest the start of encounter 2), `encounter_1_done`, `encounter_2_done`,
`encounter_3_done`. Actions: `talk` (each E that opens a conversation, with
the encounter's number) and `choice` with the reply's words, so the timeline
reads as what they said and when.

## The words: `dialogue.json`

Every word the player reads is in `dialogue.json`; rewrite it freely, no
code changes needed, the toy reads it at start.

- `"character"`: the name over the capsule and before each line.
- `"ui"`: the hint lines (`talk`, `continue`, `choose`, `walking`).
- `"encounters"`: one entry per encounter, in order: `"start"` is the id of
  its first line, `"then_walk_to": [x, z]` where Pim goes afterwards (keep
  the spots 8 to 10 m apart; the ground is 30 x 30 m centred on 0, 0).
  `"after"` is the id of the line that plays once every encounter is done.
- `"nodes"`: the lines. Each has an `"id"`, a `"who"` (shown before the
  text), a `"text"`, and one of: `"next": id` (E goes on), `"choices"`
  (up to three `{"text", "next", "set": [flags]}`: picking one sets its
  flags and goes to its next), or `"end": true` (E ends the encounter).
- Memory: a node may carry `"if": [flags]` and/or `"unless": [flags]`.
  Several nodes may share an id; the first one in the file whose `if` flags
  are all set and whose `unless` flags are all unset is the one shown. Put
  the conditional versions first and a plain one last as the fallback.
  Flags are plain words you invent in a choice's `set`; the ones here are
  prefixed by the encounter that sets them (`e1_promised`, `e2_guess_blue`).

A broken link (a `next` that names no node, an id with no fallback, a node
with no way on) is printed as a warning in the Output panel when the toy
starts, naming the node; the toy still runs.

## Files

| File | What |
| --- | --- |
| `remember.tscn` | the ground (a 30 x 30 m box, top at y = 0), a sun, the player at (0, 7) facing Pim at the origin, the text panel, the harness |
| `remember.gd` | the toy, about 100 lines: the talk hint within 2 m, E, the flow through the nodes, the flags, the harness calls |
| `character.gd` | Pim: the name label and the glide to a spot at 1.6 m/s |
| `dialogue.gd` | reads `dialogue.json`, checks its links, picks the node for an id given the flags |
| `dialogue.json` | the words: 68 nodes, 43 ids, 11 choice points |

## Headless check

```
<godot> --headless --fixed-fps 60 --path . res://tests/toy_remember_test.tscn --quit-after 20000
```

`tests/toy_remember_test.gd` plays the toy twice through the real scene:
the player is driven to Pim through the physics engine, E and the number
keys go through the input system. The first play picks reply 1 at every
choice, the second reply 2. Each must walk to Pim (within 2 m), see the
hint, open each encounter with E, get to its end, see Pim walk 8 to 10 m,
and in encounter 3 reach a line whose `if` names an encounter-1 flag
(`e3_promise[e1_promised]`, then `e3_promise[e1_no_promise]`); the two
plays must reach different encounter-3 lines; the log must be written.
Last run (2026-10-21, Godot 4.6.1 headless): 69 PASS, 0 FAIL, exit 0, 1.1 s;
walks of 96, 151 and 134 frames; glides of 351 and 367 frames (9.4 and
9.8 m); 9 + 7 + 9 lines per play. It leaves a `remember_*` log in
`toy_sessions/`; delete it before reading real sessions.
