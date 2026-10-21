# Working in two sessions

Two Claude sessions work on this game. They share one repository and one set
of notes, and they never work on the same file at the same time.

| Session | Runs | Owns |
| --- | --- | --- |
| **Gated - cloud** | a cloud container | the kit (`sakura-kit/`), research and multi-agent passes, the *gated* page, headless tests, the docs (ladder, plan, Mission Control) |
| **Gated - local** | your computer | everything that must see or hear the game: playing, screenshots, audio, the Godot editor, confidant sessions, the render loop of the *gated* page's version 2 |
| **You** | both | every gate, every verdict, the Goal, the verb, scope and kill lines |

## Shared ground

- The repository: `github.com/added-digital/gated_test`, branch `main`.
- The shared memory, all append-only, all in the repo:
  `game/NOTES.md` (rung, question, evidence, decisions), `game/IDEAS.md`
  (the parking lot), `sakura-kit/breaks.md` (the contract's changelog),
  `sakura-kit/DECISIONS.md` (taste verdicts).
- The ladder: the doc *How a game gets made*. Both sessions follow it.

## Pull and push

1. **Pull before you start, push when a unit is done.** One commit per unit
   of work, named for the rung it serves. Nothing waits in a working tree
   overnight.
2. **One owner per task.** Before touching files, write the task under
   `## Now` in `game/NOTES.md` with the session's name. The other session
   pulls and does not edit those files until the row says done.
3. **Append, don't rewrite,** in the shared notes. Two sessions appending to
   the same file merge cleanly; two sessions rewriting the same paragraph do
   not. If git still reports a conflict in a notes file, keep both sides.
4. **Nothing generated is tracked.** Godot's `.import`, `.uid`, `.godot/`,
   extracted textures and the test run log are ignored, so opening the
   project writes nothing git can see. If a pull is ever refused anyway:
   `git checkout -- . && git clean -fd game/godot && git pull`
   (throws away only what the editor generated).
5. **Branches:** `main` only, until something is uncertain enough to deserve
   a short-lived branch; then merge it the same day or delete it.
6. **Evidence goes in `NOTES.md`, not in chat.** A headless run, a session
   log, a screenshot path, a frame rate: one row, dated, with the session's
   name. The other session reads it on its next pull.

## Hand-off note

When one session finishes a unit the other must pick up, it appends to
`## Hand-offs` in `game/NOTES.md`:

```
- <date> · <from> -> <to> · done: <one line> · next: <one line> · run: <command or scene>
```

Sessions can also message each other directly (Mission Control lists both);
a message is a nudge, the note is the record.

## Now

- 2026-10-21 · Gated - cloud · the *gated* page, version 1 (Design, World, Kit, Characters, Decisions), from the files as they stand.
- 2026-10-21 · Gated - local · first run: pull, open `game/godot/project.godot` in Godot 4.6, play the three toys in `game/godot/prototypes/` (F6 / Cmd+R on each scene), listen to the three chimes in Far sound in sequence, log three observations per toy in `NOTES.md`; then book the confidants.

## Hand-offs

- 2026-10-21 · Gated - cloud -> Gated - local · done: three toys built, fix pass verified (`2d8342d`) · next: play them on the GPU, listen to the chimes, confidant sessions · run: `git pull`, then each `prototypes/*/*.tscn` with Cmd+R

## The gated page

`tools/gated_page.py` reads the repo (scene JSON, kit report and previews,
NOTES, IDEAS, breaks, the toys' JSON) and writes `build/gated.html`, which is
ignored by git. Gated - cloud publishes it as the artifact; the page's own
database holds the decision states and its comments wake Gated - cloud. Either
session may run the generator; only Gated - cloud republishes.
