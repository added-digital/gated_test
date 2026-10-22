# Toy 4b: PINCH, the loop toy, second loop

> I believe choosing a villager's dream on the wall, reaching its idea
> through branching rooms under a closing frame, and developing it at the
> desk before the light goes, with grey boxes, holds a confidant 20 minutes
> because every night is a bet you chose and every morning is work that
> only pays for what you reached; dead if not by 2026-11-10. (Drafted by
> the AI; the designer's words replace it at the gate.)

Verb: the player chooses a dream and pinches their way to its idea.
**Dead if not by 2026-11-10.**

## What it is

A grey street by day and the street's dream by night, side view, grey
boxes, one body in both. By day you talk to three villagers, and each
one's dream goes up on the Long House wall as a row of boxes ending in a
question mark; at the wall you choose whose dream tonight is, then lie
in the bunk. The dream starts in the hub, where two signed exits lead
down two villagers' branches; down the chosen one lie two rooms and then
the villager asleep beside their idea, and along the way hang thoughts,
small crisp things you grab while pinched and carry three at a time.
Holding PINCH makes the dream solid (gravity, ledges, a jump), every act
of control (a grab, a set-down, a hard fall, a failed screen) raises
lucidity and closes a black frame around you, every wonder (drifting
through a soft wall, riding the goat, three seconds still in a quiet
spot, asleep) opens it a little, and at the limit you wake with a start
and keep one thought, while E at the idea, pinched, ends the night gently
with the idea and every thought, and holding PINCH still for three
seconds pinches you awake on purpose with the thoughts and not the idea.
The next morning the idea lies on the Desk as an outline of three to
five shaped slots and the thoughts are shaped cards; for the blue hour,
seventy-five seconds of light draining from the window, you fit cards
into slots, a wrong shape costs five seconds, and what you fit stays in
the outline morning after morning until the last slot fills and the
thing is developed: Bo's pills raise the limit for good, Jorun's Sixteen
Stairs rise on their plot, Tove's lantern names every room on the wall.
Then you talk, choose at the wall and go to bed again, and the question
is whether you choose a fourth night's target without being asked, and
can say why that one.

## Run it

Pull, open `prototypes/pinch/pinch.tscn` and press F6 (not F5). The full
procedure, and how to read the session log, is in
[`../README.md`](../README.md).

## Controls

| Key | Does |
| --- | --- |
| A D | walk (street and dream; asleep, a nudge); at the Desk, the hand one slot along (a held key walks away from the table) |
| Shift or K | pinch: hold it and the dream is solid; let go and you hang where you are; held still on a floor for 3 s, you wake yourself |
| Space | jump (pinched) |
| E | on the street: talk, choose at the wall, sleep at the bunk, fit the picked card at the Desk; in the dream: grab a thought, reach the idea |
| Q | set the top thought down as a step (pinched, on a floor) |
| 1 2 3 | choose (tonight's dream at the wall; the thought to keep after a sudden waking; the branch that grows a room); at the Desk 1 to 6 pick a card |
| H | the sleep gauge on or off; the choice holds for the session |
| Tab | the dev bar (the strip along the bottom: what you can do right now, and the room's hint for its first seconds) off or on; the choice holds for the session |
| Esc | nothing here: the mouse is never taken (the choices can also be clicked) |
| F8 or close the window | end the session (closing writes the log) |

Every word on screen is in `data/*.json`; rewrite those, not the scripts.

## A night, in order

1. **The wall.** Talk to someone first: their branch appears on the map
   in the Long House, a row of boxes ending in a question mark. E under
   the map, 1 2 3 chooses: "Tonight: Bo's dream". The chosen row
   brightens and the others dim; a question mark's box pulses until its
   idea is reached, then the idea's name stands there, with the outline's
   count ("2 / 4") beside it while it waits on the desk. The target stays
   until changed. Then E at the bunk (it refuses until a dream is chosen,
   once there is one to choose).
2. **The hub's signs.** The Long House, below: one floor, two thoughts,
   two exits with signs, "Bo →" on the right for tonight's dream and
   "← Jorun" on the left for another villager's. Walk pinched into
   either; the other sign retargets the night.
3. **The rooms.** Two per branch, always the same two (Jorun: the soft
   wall, the climb; Bo: the draft, the maze; Tove: the goat, cold water),
   two thoughts each at hand height, one exit each, on the right. Drift
   in asleep, let the currents take you, pinch over a floor, take a
   thought if the hip has room (three), stand pinched in the exit. The
   frame closes on every act and opens on every wonder; the gauge at the
   bottom left shows the same number as a bar, if it is on.
4. **The goal.** The villager asleep, a snoring capsule twice your size,
   and the idea beside them. E at it, pinched: the snore grows, the
   idea's name rises, the frame opens to full, and you wake gently with
   the idea and every thought. A branch already reached holds two
   thoughts where the idea lay, and a line that says so.
5. **The self-pinch.** Hold Shift still on any floor for three seconds
   (the frame flickers from one second in): you wake on purpose, every
   thought with you, no idea, nothing on the tally. The frame shutting
   instead, at the limit: one thought stays (you choose when two or
   more), the rest fade over the bunk, and Tove marks the wall.
6. **The morning Desk.** You are put at the table. The outline (the idea
   reached first, if two wait) with any slots filled on earlier mornings,
   your thoughts as numbered cards, the window full of light. 1 to 6
   picks a card, A D moves the hand, E fits it: the card slides into the
   slot and the slot flashes; a wrong shape shakes you and costs five
   seconds of light. The light going, or walking away, keeps what is
   filled for tomorrow. The last slot: the outline flashes under the
   thing's name, and it is developed: a scaffold today and a building
   with a lit window tomorrow (the dark pulls back a tile, Jorun moves
   out), the jar by the bunk and the limit 10 from the next night on, the
   lantern lit by the door and every room named on the wall. Then talk
   (the one whose thing you developed has a new line; Tove asks for the
   pills on the third morning), the wall, the bunk.

## Three things to watch

1. **At the wall.** When they choose, do they choose by want (whose idea
   they were told about, whose outline is waiting on the desk) or by what
   is nearest (the first name in the list, the branch they walked last
   night)? Ask afterwards why that one; write the answer down word for
   word.
2. **In the dream.** Do they pinch themselves awake in time, or get thrown
   out by the frame? Watch for the first time they hold still on purpose,
   and what they say the moment the frame shuts without their say-so.
   The dev bar counts the hold down; note whether they read it or the
   flicker.
3. **At the Desk.** Do they count the light? Watch whether they look at
   the window before a fit, whether a fumble changes their pace, and
   whether they walk away with cards still on the desk or sit the light
   out. Ask afterwards how long they thought the blue hour was.

## The question

Do they choose a fourth night's target without being asked, and can they
say why that one? Do not prompt the fourth night. If they stop before it,
ask which dream they would have chosen next and why; if they go, ask the
same thing at the wall, before they lie down.

## Numbers

Measured, not guessed, by `tests/toy_pinch_balance_test.tscn`: a scripted
player on the dream alone, limit 8, carry 3, six thoughts a night, the
three branches, a competent night (ride the currents asleep, pinch only
over a floor within a body's drop, take a thought while effective plus
its two points stays two under the limit, take the wonders on the way,
reach the idea) and a clumsy one (every thought in reach, one set down
and picked up again, one wrong pinch, a hard fall in every room that
offers a drop), with the thoughts actually taken on the way; then the
clumsy player at 10 (the pill's nights).

| night | branch | mode | limit | rooms | home | wonder | lucidity | effective | end | seconds |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Jorun | competent | 8 | hub a c goal | round, square, long | 3 | 0 | 3 | reached | 31.4 |
| 1 | Jorun | clumsy | 8 | hub a | round | 0 | 5 | 8 | woke | 4.9 |
| 2 | Bo | competent | 8 | hub f d goal | round, square, long | 3 | 0 | 3 | reached | 33.2 |
| 2 | Bo | clumsy | 8 | hub f | round | 1 | 6 | 9 | woke | 19.8 |
| 3 | Tove | competent | 8 | hub b e goal | round, square, square | 3 | 0 | 3 | reached | 39.9 |
| 3 | Tove | clumsy | 8 | hub b | round | 1 | 6 | 9 | woke | 20.3 |
| 1 | Jorun | clumsy | 10 | hub a c goal | round, square, long | 3 | 4 | 7 | reached | 45.2 |
| 2 | Bo | clumsy | 10 | hub f d goal | round, square, long | 3 | 5 | 8 | reached | 45.3 |
| 3 | Tove | clumsy | 10 | hub b e goal | round, square, long | 3 | 5 | 8 | reached | 38.2 |

The Desk's arithmetic, with carry 3 and six thoughts a night. By the pure
sums, when every shape matches, three cards fit a morning: the pills (3
slots) in one morning, Sixteen Stairs (4) in two, the lantern (5) in two.
Measured, each branch played competently with one state carried across
its mornings (the thoughts home fitted where their shapes match, the
leftovers kept, the next night's deal favouring what is missing):

| branch | morning | home | fitted | outline | left over |
| --- | --- | --- | --- | --- | --- |
| Bo | 2 | round, square, long | 3 | 3 / 3, developed | |
| Jorun | 2 | round, square, long | 3 | 3 / 4 | |
| Jorun | 3 | round, round, round | 1 | 4 / 4, developed | round, round |
| Tove | 2 | round, square, square | 2 | 2 / 5 | square |
| Tove | 3 | long, long, long | 2 | 4 / 5 | square, long |
| Tove | 4 | round, round, round | 1 | 5 / 5, developed | square, long, round, round |

What the numbers are:

- A competent night reaches the idea on every branch with three thoughts,
  lucidity 0 and effective 3 of 8 (the three at the hip), in 31 to 40
  seconds of dream, taking the three wonders of its branch on the way
  (Jorun's: the soft wall, the quiet spot in the soft wall's room, the
  quiet spot in his room; Bo's: the quiet spot by the draft's door, the
  maze's soft wall, the spot in his room; Tove's: the two goats and the
  spot in hers). Three thoughts cost 6 of 8; the wonders pay them back.
- A clumsy night at 8 is thrown out in the second room every time (5 or
  6 lucidity, 8 or 9 effective: the set-down and the pick-up, the wrong
  pinch, the hard fall, with three thoughts at the hip) and brings one
  thought home. The same clumsy night at 10 reaches every idea with three
  thoughts: the pill is worth two mistakes, and on these branches two
  mistakes is the difference between reaching and not.
- The pills develop on the first morning: the hub's round and square and
  the draft's long are exactly the three shapes Bo's outline wants.
  Sixteen Stairs takes two mornings (three of four, then the round). The
  lantern takes three: the first night down Tove's branch brings round,
  square, square (the hub's two, and the one on the beam; the goat rooms
  never put a long in the way), so two fit; the second brings three longs
  of which two fit; the third brings rounds. Every outline completes
  within three competent mornings.
- One rule was changed for that, not a number: with the plain deal (the
  shapes cycling round, square, long over the hub and the two rooms)
  Tove's branch never yields a long to a player who takes the hub's two
  thoughts and the beam's, so the lantern never completed (measured:
  round, square, square every night). Now, down a branch whose idea is
  reached and whose outline still waits on the desk, the six thoughts
  dealt cycle through the outline's missing shapes instead
  (`dream.gd deal_scraps`, `missing_shapes`); the first night down a
  branch is the plain deal as before. The limit (8), the carry (3), the
  six thoughts a night and the slot counts (3, 4, 5) are the designer's
  and were not touched.
- One zone was moved, not a number: room f's quiet spot sat inside the
  draft, which moves a body asleep, so its wonder could never be had and
  Bo's branch yielded two wonders, not three; it sits by the door now,
  outside the draft, and the branch yields three again (the room is
  solved competently in 11.9 s, the wonder first).
- The bot's route is not a person's: it takes the hub's two thoughts and
  one more, always the same ones, and never looks at a shape; a person
  who reads the outline on the wall ("2 / 4") and goes down that branch
  for its missing shapes will do better than the table, which is the
  point of the rule.

## Where the log lands

`toy_sessions/pinch_<date>T<time>.log` in the project's user data folder
(the Output panel prints the full path when the toy starts, and the whole
summary when it ends; closing the window writes it, and it is rewritten
every 10 seconds while playing):

- macOS: `~/Library/Application Support/Godot/app_userdata/Sakura Walk/toy_sessions/`
- Windows: `%APPDATA%\Godot\app_userdata\Sakura Walk\toy_sessions\`
- Linux: `~/.local/share/godot/app_userdata/Sakura Walk/toy_sessions/`

Milestones: `slept_1` .. `slept_4`, `grabbed_scrap`, `reached:<who>`,
`kept:<idea>`, `self_pinch`, `retarget:<who>`, `woke_sudden`,
`woke_gentle`, `desk_full:<idea>`, `desk_reveal:<who>`, `built:<plot>`.
Actions, with their time: `talk:<who>`, `request`, `wall`, `target`,
`refused`, `sleep`, `enter`, `grab_scrap`, `set_down_scrap`, `fall`,
`fail`, `wonder:<spot>`, `left`, `reach`, `self_pinch`, `retarget`,
`keep`, `keep_scrap`, `lost`, `gauge`, `devbar`, `desk` (start, light,
filled, walked), `pick`, `fit`, `fumble`, `desk_kept`, `desk_full`,
`desk_reveal`. The fourth `target` without a word from you is the answer
to the question; the gap before it is the thinking.

## Known

- Grey boxes, every one. No art, no sound, no blur: soft things are drawn
  pale with a dashed edge and vanish while pinched; a quiet spot is a
  pulsing ring; a current carries a row of small arrows; cold water is
  hatched; the goat has horns. The feel is motion and timing of grey
  shapes: the card's slide, the slot's flash, the light's drain, the
  frame's opening at a reach, the wall's rows brightening and dimming.
- A thought set down as a step floats where you put it, even past a
  ledge's end; that is how the climb and the draft are meant to be
  solved, and it looks like a bug.
- Branch rooms have one exit, on the right; only the hub has two. The
  choice is made at the wall and, at most, once more at the hub's signs;
  after that a night is navigation under the frame, not a search.
- The lantern names every room on the wall, on every branch, for good;
  three thoughts alone name one more room on one branch. The names are
  the rooms' (rooms.json); nothing else is revealed.
- The target persists: tonight's dream stays chosen until you choose
  another, across nights, and the bunk never asks again.
- The Desk works on one outline a morning (the one reached first, when
  two wait); the other waits its turn. An outline with no card that fits
  it is ended by walking away, not by the light: the dev bar says so.
- The gauge is a hypothesis test, not a feature: it is on by default so
  the first session can compare it with the frame, and H turns it off
  for the rest of the session for the second.
- The harness clocks wall time: a headless run says 0 minutes played.
- The first loop (days 1 to 5): one continuous dream dealt from a deck of
  rooms, ideas caught under a hat, a bed to find, breakfast with three
  faces; its spec is `SPEC.md` beside this page, and its rooms, physics,
  frame and gauge are the ones this loop runs on. `SPEC-2.md` is this
  loop; where they differ, `SPEC-2.md` wins.

## Files

| Path | What |
| --- | --- |
| `pinch.tscn` / `pinch.gd` | the controller: the state, the harness, the village by day and the dream by night, waking, keep-one |
| `state.gd` | the one state: day, limits, the target, reached, the outlines on the desk, the things developed, claimed and built, the thoughts kept, the tally, the flags, the two settings |
| `village.tscn` / `.gd` | the street, the bunk, the table and the Desk, the people, the wall, the buildings rising |
| `wall.gd`, `desk.gd` | the map on the wall; the Desk at the table |
| `dream.tscn` / `.gd` | the branch dealer, the scraps, the goal rooms, the frame, lucidity, the gauge, the self-pinch, the reach |
| `dreamer.gd` | the body in the dream: asleep drift, pinched physics, the hip, the squash and the stretch |
| `rooms/room_*.tscn`, `goal_*.tscn` | the hub, rooms a to f, the three goal rooms; `room.gd`, `box.gd`, `zone.gd`, `goat.gd`, `sleeper.gd` are their parts; the tutorial, the ladder and the bed are the first loop's, dealt by hand only |
| `data/*.json` | every word the player reads: `village`, `characters`, `ideas`, `rooms`, `branches`, `scraps`, `devbar` |
| `devbar.gd`, `label_kit.gd` | the dev bar; the backed labels every scene draws its words with |
| `../../tests/toy_pinch_*_test.gd` | the headless proofs; `pinch_driver.gd` is the scripted player the balance and four-night tests share |

Headless, from the project folder (import first):

```
<godot> --headless --path . --import
<godot> --headless --fixed-fps 60 --path . res://tests/toy_pinch_four_nights_test.tscn --quit-after 200000
```

Four nights without a thought placed by hand: Bo's pills reached and
developed on the second morning, Jorun's stairs reached, three of four
fitted and the fourth the morning after (a scaffold, then the building),
Tove's lantern reached and its outline started, Tove's branch walked
again for its thoughts and the self-pinch; it ends with `slept_4`, the
milestones listed and the summary printed. `RESULT: 0 failure(s)` and
exit 0; it leaves one `pinch_*` log in `toy_sessions/`. The other eight
pinch tests are run the same way (`toy_pinch_test`, `_dream_`, `_ideas_`,
`_day_`, `_balance_`, `_readability_`, `_loop2_`, `_desk_`).
