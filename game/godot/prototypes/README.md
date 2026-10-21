# Toys (rung 3)

Question: which single interaction is worth repeating? Proof: three grey-box
toys, three verbs, each played by a confidant. Gate: one toy holds a confidant
5 minutes and their words match the Goal ("The player feels accomplished":
calm is the home state, something breaks it, the feeling arrives when the
calm is put back; never repetitive, never a chore).

Rules of this rung: grey boxes only, no kit pieces, no art, no polish, no
menus, no goals or scores beyond what the toy's own interaction needs, one
verb per toy. Playable in 5 minutes by a friend who has never seen it; every
word the player reads lives in a text file you can rewrite without touching
code.

## The three toys

| Toy | Folder | Hypothesis (designer's words) | Verb | Dead if not by |
| --- | --- | --- | --- | --- |
| 1 Remember | `remember/` | I believe choosing replies to a character who remembers what you said holds a confidant 5 minutes because it makes your decisions feel important. | choose, with consequence | 2026-10-24 |
| 2 Help | `help/` | I believe helping someone in a rush holds a confidant 5 minutes because it makes you feel like something important is happening. | help, under urgency | 2026-10-28 |
| 3 Far sound | `far_sound/` | I believe hearing something interesting far away but being blocked from getting there holds a confidant 5 minutes because it turns on brain activity to find a way there. | find the way | 2026-10-31 |

Each toy folder holds `<toy>.tscn` (the scene to run), its scripts, its text
file(s), and a `README.md` sheet: the hypothesis and kill date verbatim, how
to run, controls, three things to watch while the confidant plays, and where
the session log lands.

## Run a toy

1. Open the project in Godot 4.6 (`project.godot`, as for the walk).
2. In the FileSystem dock open `prototypes/<toy>/<toy>.tscn`.
3. Press F6 (Run Current Scene). F5 would run the tea house, not the toy.
4. Hand over the keyboard and say nothing. Keys every toy shares: W A S D
   walk, mouse looks, Esc frees or recaptures the mouse, E does the toy's
   verb where the hint says so, 1 2 3 pick a reply (or click it with the
   mouse freed), F8 or the window's close button ends the session.
5. End the session by closing the window (or F8), not with the editor's
   Stop button: closing writes the log. The log is also rewritten every
   10 seconds while playing, so a Stop loses at most 10 seconds.

## Read a session log

Each session writes one file, `toy_sessions/<toy>_<date>T<time>.log`, in the
project's user data folder (the editor opens it: Project > Open User Data
Folder; the Output panel also prints the full path when the toy starts and
the whole summary when it ends):

- macOS: `~/Library/Application Support/Godot/app_userdata/Sakura Walk/toy_sessions/`
- Windows: `%APPDATA%\Godot\app_userdata\Sakura Walk\toy_sessions\`
- Linux: `~/.local/share/godot/app_userdata/Sakura Walk/toy_sessions/`

A log looks like this:

```
toy: remember
session: 2026-10-23T19:04:05
played: 6.2 minutes (372 s)
actions: 41 (6.6 per minute)
  talk: 12
  choose: 29
milestones: 3
  00:14  first_talk
  01:02  first_callback
  04:40  all_rooms
timeline:
  00:09  talk
  00:14  choose  I'm sorry
  ...
log: /Users/.../toy_sessions/remember_2026-10-23T19-04-05.log
```

How to read it against the gate:

- `played`: the number the gate asks for. Under 5 minutes, the toy did not
  hold them; the timeline shows where they stopped.
- `actions ... per minute`: engagement. A rate that is healthy in the first
  minute and collapses later means the toy ran out, not the player.
- `milestones`: how far they got and how fast. A milestone that never shows
  up is a part of the toy nobody reached.
- `timeline`: look for gaps of 30 seconds or more with no action. A gap is
  either thinking (good: ask them what they were doing there) or being lost
  (bad: the sheet's "three things to watch" should have caught it).
- The log is the numbers. The words are what matters for the gate: write
  down what the confidant says, unprompted, the moment they stop.

## For the toy builders: the shared harness

`_shared/` is used by all three toys and must not be changed by a toy.

- `_shared/toy_harness.gd`: a Node added to the toy scene as `Harness`.
  `start(toy_name)` in the toy's `_ready`; `action(kind, detail = "")` for
  each thing the player does; `milestone(name)` for a first (recorded the
  first time only); `summary()` returns the session text. It writes the log
  described above when it leaves the tree (window closed, quit, scene
  change) and every 10 seconds in between.
- `_shared/text_panel.tscn` (+ `.gd`): a CanvasLayer instantiated in the toy
  scene. `say(text)` puts a sentence at the bottom of the screen;
  `choices(options)` shows up to three numbered options and emits
  `chosen(index)` when the player presses 1/2/3 or clicks; `prompt(text)`
  is the small hint line ("E to talk"); `hide_all()` clears them. Clicking
  needs the mouse freed (Esc); the number keys work either way.
- Input actions in `project.godot`: `interact` (physical E), `choice_1`,
  `choice_2`, `choice_3` (keys 1, 2, 3), plus the walk's `move_*`.
- Each toy scene instantiates `res://scenes/player.tscn` (the first-person
  capsule from the walk: `auto_move` drives it in tests, feet below
  `FALL_LIMIT` respawn it) and starts the harness.

Headless check of the harness and panel (no toy), from the project folder:

```
<godot> --headless --fixed-fps 60 --path . res://tests/toys_harness_test.tscn --quit-after 600
```

PASS/FAIL per check, `RESULT: 0 failure(s)`, exit 0; it writes two logs to
`toy_sessions/` (`harness_test_*` and `harness_test_quit_*`).
