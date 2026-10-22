# Toy 4: PINCH, the loop toy

> I believe pinch-to-grab under a closing frame, paid off by one building
> standing on the street per idea each morning, with grey boxes holds a
> confidant 20 minutes because the frame is a bar the body reads without
> being told and the lit window is a reward the eye reads without being
> told, so each half makes the other one matter. (Drafted by the AI; the
> designer's words replace it at the gate.)

Verb: pinch to grab. **Dead if not by 2026-11-10.**

## What it is

A grey street by day and the street's dream by night, side view, grey
boxes. You walk to the bunk in the Long House, press E, and wake upside
down in a dream of rooms, where asleep you drift and currents carry you
through everything, and where holding PINCH makes the world solid: gravity,
ledges, a jump, and ideas, the only crisp things, that you can grab and
carry under your hat. Every act of control (a grab, a push, a hard fall, a
step set down, a screen failed) raises lucidity and closes a black frame
around you; every wonder (drifting through a soft wall, riding the goat,
standing still in a quiet spot) opens it a little; at the limit you wake
with a start and keep one idea, while your bed, somewhere in the dream,
wakes you gently with everything. At breakfast three villagers sit with one
line of want each over their heads, and you put each idea in front of the
one it belongs to: "I dreamed that." A claimed idea is a scaffold on its
plot by day and a building with a lit window the next morning, and the
dark at each end of the street pulls back one tile; an idea nobody claims
becomes a bench, a sign, a lantern. Then you walk, talk, and go back to
bed, and the question is whether you do that a fourth time without being
asked.

## Run it

Pull, open `prototypes/pinch/pinch.tscn` and press F6 (not F5). The full
procedure, and how to read the session log, is in
[`../README.md`](../README.md).

| Key | Does |
| --- | --- |
| A D | walk (street and dream; asleep, a nudge) |
| Shift or K | pinch: hold it and the dream is solid; let go and you hang where you are |
| Space | jump (pinched) |
| E | grab an idea, push the block, lie in the bed; on the street: talk, sleep, make the pills (held), offer an idea at breakfast |
| Q | set the top idea down as a step (pinched, on a floor) |
| 1 2 3 | choose (the idea to keep after a sudden waking; a pill at the bunk) or cycle the idea in the hand at breakfast |
| H | the sleep gauge on or off; the choice holds for the rest of the session |
| Tab | the dev bar (the strip along the bottom: what you can do right now, and the room's hint for its first seconds) off or on; the choice holds for the session |
| Esc | nothing here: the mouse is never taken (the choices can also be clicked) |
| F8 or close the window | end the session (closing writes the log) |

Every word on screen is in `data/*.json`; rewrite those, not the scripts.

## A night, in order

1. **Evening.** E at the bunk (1 first for a pill, once they exist). The
   village goes, the dream comes: four rooms dealt from the deck of seven
   (the tutorial first on night 1), then your bed in the wrong place.
2. **Each room.** Drift in asleep, let the current take you, pinch over a
   floor, take the idea if the hat has room, stand pinched in the exit.
   The frame closes on every act and opens on every wonder; the gauge at
   the bottom left shows the same number as a bar, if it is on.
3. **Waking.** The frame shuts: the ideas float over the bunk and fade,
   one stays (you choose when there were two), Tove marks the wall. Or the
   bed: everything comes home, nothing is marked.
4. **Breakfast.** Ninety seconds, one head drops every thirty. 1 2 3 picks
   the idea in the hand, E at a face offers it. The right face claims it;
   the wrong face shuts its eyes for the rest of the meal. Walk away and
   what is left on the table becomes a small thing.
5. **Day.** A claimed idea is a scaffold today (the crossbars go up one a
   second) and a building tomorrow (its window fades in as the morning
   begins); the dark pulls back a tile; its owner moves out and stands in
   front of it, with something to say. The stove shed and the pills come
   when Tove asks (the morning of day 3); the taller hat when Bo's loft
   stands. Then the bunk.

## Three things to watch

1. **When they turn for the bed.** The moment they stop grabbing and go
   looking for the bed (or walk past it), were they looking at the gauge,
   at the frame, or at neither? Ask afterwards which one they read; the
   hypothesis is the frame. Play the second session with the gauge off
   (H once; it stays off) and ask again.
2. **Breakfast.** Do they read the faces' want lines and carry the idea
   to the one it belongs to, or do they guess and try faces until one
   claims it? A wrong face shuts its eyes: watch whether that lands.
3. **The morning the first window lights.** A building stands where a plot
   was, its window fades in, the dark has moved a tile. Do they say
   anything? Write down the first thing, word for word, and whether they
   walk over to it.

## The question

Do they go to bed a fourth time without being asked, and can they say what
they are going down for? Do not prompt the fourth night. If they stop
before it, ask what they were going down for the last time; if they go,
ask the same thing when they come up.

## Numbers

Measured, not guessed, by `tests/toy_pinch_balance_test.tscn`: a scripted
player on the dream alone, a fresh state each night, limit 8, carry 2, a
competent night (ride the currents, pinch only over a floor within a
body's drop, two grabs, the wonders on the way, the bed) and a clumsy one
(a hard fall where a room offers a drop, at most two a night; one wrong
pinch; one idea set down and picked up again), on nights 1, 2 and 3.

| night | mode | limit | rooms | grab | set | fall | fail | wonder | lucidity | effective | end | home | seconds |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | competent | 8 | tutorial a f b d bed | 2 | 0 | 0 | 0 | 6 | 0 | 2 | bed | 2 | 55.5 |
| 1 | clumsy | 8 | tutorial | 2 | 1 | 1 | 0 | 0 | 6 | 8 | woke | 1 | 2.5 |
| 2 | competent | 8 | ladder e c a bed | 2 | 0 | 0 | 0 | 4 | 1 | 3 | bed | 2 | 46.9 |
| 2 | clumsy | 8 | ladder e c a | 2 | 1 | 2 | 1 | 1 | 8 | 10 | woke | 1 | 25.5 |
| 3 | competent | 8 | c ladder bed f e bed | 2 | 0 | 0 | 0 | 4 | 1 | 3 | bed | 2 | 56.4 |
| 3 | clumsy | 8 | c ladder bed f | 2 | 1 | 2 | 1 | 1 | 7 | 9 | woke | 1 | 32.2 |
| 1 | clumsy | 9 | tutorial a | 3 | 1 | 1 | 1 | 0 | 9 | 12 | woke | 1 | 12.6 |
| 2 | clumsy | 9 | ladder e c a | 2 | 1 | 2 | 1 | 1 | 8 | 10 | woke | 1 | 25.5 |
| 3 | clumsy | 9 | c ladder bed f | 2 | 1 | 2 | 1 | 1 | 7 | 9 | woke | 1 | 32.2 |
| 1 | competent | 7 | tutorial a | 2 | 0 | 0 | 0 | 0 | 4 | 7 | woke | 1 | 8.5 |
| 2 | competent | 7 | ladder e c a | 2 | 0 | 0 | 0 | 1 | 4 | 7 | woke | 1 | 28.6 |
| 3 | competent | 7 | c ladder bed f e bed | 2 | 0 | 0 | 0 | 4 | 1 | 3 | bed | 2 | 56.4 |

What the numbers are:

- A competent night reaches the bed with two ideas every night, lucidity
  0 or 1, effective 2 or 3 of 8, in 47 to 56 seconds of dream. Two grabs
  cost 4, the two ideas under the hat 2, and the newest one counts double
  for two seconds: the second grab puts effective at 7 of 8 by itself.
  The limit is one point above the second grab; every wonder on the way
  buys one mistake back, and a careful night finds four to six.
- A clumsy night never reaches the bed. Night 1 wakes in the tutorial after
  2.5 s (lucidity 6: a grab 2, the set-down 1, the pick-up 2, the step 1;
  plus 1 carried and 1 in hand: effective 8); nights 2 and 3 wake in the
  fourth room at 10 and 9. One idea comes home each time (the picker, when
  two were carried).
- The sixth room, the draft, is solved competently in 11.8 s (one grab,
  the quiet spot, no fall).

What one notch of the limit changes:

- 9 saves none of the three clumsy nights (12, 10 and 9 at the end): one
  notch up is not forgiveness, it is a fourth mistake.
- 7 wakes a competent player at the second grab itself on nights 1 and 2
  (4 + 2 + 1 in hand = 7), before any wonder that counted; only night 3,
  with a wonder first, reaches the bed. One notch down and carrying two
  home is luck.
- So one notch up does not help the careless player and one notch down
  costs the careful one; 8 is the smallest limit at which a careful player
  brings two ideas home. The limit, the carry and the acts table are the
  designer's to move; nothing here was changed.

One room was fixed, not the numbers: the climb's first ledge sat 64 px
above the floor, which left 40 px under it for a 56 px body, so the floor
could not be walked to the exit and every visit cost a hard fall just to
pass; it now sits at 88 px (y 512) and the floor runs under it. The bot's
route is not a person's: it knows where every idea lies and never looks
for the bed; a person will fall at least once a night and read the frame
while doing it, which is the point.

## Where the log lands

`toy_sessions/pinch_<date>T<time>.log` in the project's user data folder
(the Output panel prints the full path when the toy starts, and the whole
summary when it ends; closing the window writes it, and it is rewritten
every 10 seconds while playing):

- macOS: `~/Library/Application Support/Godot/app_userdata/Sakura Walk/toy_sessions/`
- Windows: `%APPDATA%\Godot\app_userdata\Sakura Walk\toy_sessions\`
- Linux: `~/.local/share/godot/app_userdata/Sakura Walk/toy_sessions/`

Milestones: `slept_1` .. `slept_4`, `grabbed`, `woke_sudden`, `woke_gentle`,
`kept:<idea>`, `told:<idea>:<who>`, `built:<plot>`. Actions, with their
time: `sleep` (`pill` when one was taken), `enter`, `grab`, `set_down`,
`force`, `fall`, `fail`, `wonder:<spot>`, `left`, `lost`, `keep`, `lie_down`,
`gauge`, `breakfast`, `told`, `told_wrong`, `small_thing`, `talk:<who>`,
`request`, `made`, `pill`, `dropped`. The fourth `sleep` without a word from
you is the answer to the question; the gap before it is the thinking.

## Known

- Grey boxes, every one. No art, no sound, no blur: soft things are drawn
  pale with a dashed edge and vanish while pinched (within two steps of
  the limit they dim further); a quiet spot is a slowly pulsing ring; a
  current carries a row of small arrows drifting its way; cold water is
  hatched; the goat has horns and wears its name beside it, not under
  the rider.
- The dev bar along the bottom lists only what can be done right now
  (computed from the state, words in `data/devbar.json`); Tab hides it.
  The room's one-line hint shows in its right half for four seconds after
  a room is entered, then fades; the room's name stays at the top left.
- A step set down floats where you put it, even past a ledge's end; that
  is how the climb and the draft are meant to be solved, and it looks like
  a bug.
- On third nights (day 3, 6, ...) the bed is dealt early with an exit past
  it, and again last: the same bed twice. Lie in the first with a full hat
  or walk on; the second has no way past.
- Letting go of the pinch in mid-air stops the fall where you are, and a
  pinch in mid-air starts a new fall from there: a player who notices can
  come down any height for free by tapping. The bot does not do it; a
  person might find it, and that is worth writing down.
- Breakfast's clock runs 90 s; the bot never waits for a head to drop, so
  the measured nights say nothing about the breakfast's pace.
- The gauge is a hypothesis test, not a feature: it is on by default so the
  first session can compare it with the frame, and H turns it off for the
  rest of the session for the second.
- The harness clocks wall time: a headless run says 0 minutes played.

## Files

| Path | What |
| --- | --- |
| `pinch.tscn` / `pinch.gd` | the controller: the state, the harness, the village by day and the dream by night, waking, keep-one |
| `state.gd` | the one state: day, limits, ideas carried, kept, claimed, built, the tally, the flags, the gauge choice |
| `village.tscn` / `.gd` | the street, the bunk, the table, the people, breakfast, the buildings rising |
| `dream.tscn` / `.gd` | the deck of rooms, the frame, lucidity, the gauge, the blink |
| `dreamer.gd` | the body in the dream: asleep drift, pinched physics, the hat stack, the squash and the stretch |
| `rooms/room_*.tscn` | the tutorial, rooms a to f, the ladder, the bed; `room.gd`, `box.gd`, `zone.gd`, `goat.gd` are their parts |
| `data/rooms.json`, `ideas.json`, `characters.json`, `village.json`, `devbar.json` | every word the player reads |
| `devbar.gd`, `label_kit.gd` | the dev bar; the backed labels every scene draws its words with |
| `../../tests/toy_pinch_*_test.gd` | the headless proofs; `pinch_driver.gd` is the scripted player the balance and four-night tests share |

Headless, from the project folder (import first):

```
<godot> --headless --path . --import
<godot> --headless --fixed-fps 60 --path . res://tests/toy_pinch_four_nights_test.tscn --quit-after 200000
```

Four nights like a person who is learning: night 1 clumsy, night 2
competent, the pills made the morning Tove asks and one taken on night 3,
every breakfast sat through; it ends with `slept_4`, two buildings standing
and the summary printed. `RESULT: 0 failure(s)` and exit 0; it leaves one
`pinch_*` log in `toy_sessions/`. The other six pinch tests are run the
same way (`toy_pinch_test`, `_dream_`, `_ideas_`, `_day_`, `_balance_`,
`_readability_`).
