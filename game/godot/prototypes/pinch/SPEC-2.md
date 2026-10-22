# PINCH, the loop toy, second loop — spec

Rung 3, toy 4b. The designer played the first loop (days 1 to 5, `SPEC.md`)
and asked for a different one (IDEAS, 2026-10-22, their words):

> What I dislike about it is that ideas must be caught. In Dave the Diver you
> can swim upwards to the surface at any time to end the swim, but it comes
> at a cost. Rather than a continuous dream, each room has options (the
> ideas) to traverse further into. If the idea is Bo's pills you have to
> actively travel towards that idea, and that shapes the next room. With a
> visible map that's a choice for a night. If you don't succeed you don't
> return with anything valuable. The surface must be more contained, like a
> sushi bar night: "study sleep".

This page is what gets built on top of the first loop. Where it differs
from `SPEC.md`, this page wins. What it does not mention stays as built
(the two dreamer states, the frame, the gauge, the dev bar, the rooms'
problems, the feel pass, the characters and their memory).

## The sentences

- Goal (rung 1, the designer's): **The player feels accomplished.**
- Hypothesis (drafted; the designer's words replace it at the gate):
  **I believe choosing a villager's dream on the wall, reaching its idea
  through branching rooms under a closing frame, and developing it at the
  desk before the light goes, with grey boxes, holds a confidant 20 minutes
  because every night is a bet you chose and every morning is work that only
  pays for what you reached; dead if not by 2026-11-10.**
- The verb: *the player chooses a dream and pinches their way to its idea.*
- The 20-minute question: **does the player choose a fourth night's target
  without being asked, and can they say why that one?**

## The loop, one night

1. **Evening, the wall.** In the Long House a map of the dream hangs on the
   wall: the Long House's own reflection at the top (the hub), and under it
   one branch per villager you have talked to, each ending in that villager's
   idea, drawn as a question mark until reached. E at the wall chooses
   tonight's target ("Tonight: Bo's dream"). Then the bunk.
2. **The dream.** You start in the hub. Every room has two exits, each with a
   sign saying whose dream lies that way ("Bo →", "Jorun ↑"). The path to a
   target is fixed per villager (learnable: Bo's dream is always the draft,
   then the climb, then his room), so a night is navigation under the frame,
   not a search. Along the way lie **scraps**: small crisp things, half
   thoughts, grabbed pinched (+1 lucidity each), carried up to three. The
   **goal room** holds the villager's idea, one crisp thing: E at it, pinched,
   and the night ends there, gently, with the idea and every scrap. There is
   no bed to find any more; reaching is the gentle waking.
3. **The free exit.** At any moment, hold PINCH for three seconds while
   standing still: you pinch yourself awake. You keep every scrap. You do
   not have the idea unless you reached it. This is surfacing in Dave:
   always allowed, never free, because the morning only pays for what you
   brought.
4. **The forced exit.** When the frame shuts you wake with ONE scrap of your
   choice; the rest fall back into the dream. So pinching yourself in time
   is always better than being thrown out.
5. **Morning, the Desk.** The contained activity, at the opposite pace. See
   "The Desk, exactly". It turns an idea plus scraps into a developed thing,
   or scraps alone into map knowledge, before the blue hour ends.
6. **Day.** A developed building rises (scaffold today, lit window tomorrow,
   the dark pushed back a tile, the villager moves out). A developed pill is
   kept and raises the limit by 2 on every night after. Map knowledge opens
   a branch one room deeper. Talk, then the wall, then the bunk.

## The Desk, exactly

The Desk is the Long House table by day, and it is a timed, hands-on burst:
the blue hour, 75 s, with the light draining visibly from the window.

- A reached idea is laid on the desk as an **outline** of three to five
  **slots**; each slot has a shape (round, square, long). The outline
  **stays on the desk, morning after morning, until it is complete**,
  with whatever is fitted still in it: nothing is lost (day C). With two
  outlines waiting, the one reached first is on the desk; the wall shows
  each outline's progress on its branch row ("2 / 4").
- Your scraps are **cards** beside it, each with a shape. 1 2 3 picks a
  card; A D moves the hand along the slots; E fits the card. A wrong shape
  does not fit and costs 5 s of fumbling. A fitted card is used up, and
  kept in the outline from that moment.
- Each morning's blue hour limits **how many cards you can fit**; the light
  going, or walking away, keeps what is filled. The thing is **developed
  the moment the last slot fills**, in full only (the building; the pill
  at +2; the lantern): there is no weak version and no "nothing" (the one
  grade is whole). Leftover scraps are kept for tomorrow (up to six).
- A reached branch keeps giving two scraps where its idea lay; the idea
  itself is never lost. Down a reached branch whose outline still waits,
  the scraps dealt favour the shapes the outline is missing.
- With **no outline** on the desk (none reached yet, or all developed),
  the Desk takes scraps alone: three scraps of any shape, fitted to the
  map's blank outline, reveal one more room on one branch of your choice
  (the map grows from what you found below).

## What changes in the toy (counts)

| Thing | Count | Detail |
| --- | --- | --- |
| The wall map | 1 | the hub and three branches (Tove, Jorun, Bo); each branch a question mark until reached, a name after |
| Targets | 3 | Jorun: Sixteen Stairs (a building); Bo: the pills (a +2 limit); Tove: the lantern (map knowledge: reveals every branch one room deeper) |
| Branch length | 2 rooms + the goal room | from the existing rooms a to f, fixed per branch; the hub is a new small room with two exits |
| Goal rooms | 3 | one per villager: a small room with the villager asleep in it (a large grey capsule), their idea beside them |
| Scraps | 6 per night | three shapes, spread over the rooms on the chosen branch and the hub; +1 lucidity each; carry 3 |
| The self-pinch | 1 | hold PINCH 3 s still; the frame flickers during the hold; the dev bar says so |
| Forced waking | keep one scrap | the picker, as before |
| The Desk | 1 | the table by day; 75 s; outlines from data; cards from scraps |
| Developed things | 3 | the building, the pill, the lantern |
| Removed | | the bed room, the hat stack of ideas, breakfast as the burst (the villagers still talk, and the one whose idea you developed has a new line) |

## Lucidity, exactly (unchanged except scraps)

grab a scrap +1 · set a scrap down (as a step) +1 · force +1 · hard fall +1 ·
failed screen +1 · wonder −1 once per wonder per visit · floor 0.
`effective = lucidity + scraps carried` (no in-hand doubling; scraps are
small). Limit 8, plus 2 once the pill is developed, for every night after.

## Out of scope (returns only as a request, after the fourth chosen night)

More villagers. Branches longer than two rooms. Altars in goal rooms. The
map as a place you can be in. Coin. Art. Music. A second verb at the Desk.

## Files

```
prototypes/pinch/
  SPEC-2.md               this page
  wall.gd                  the map on the wall: branches, reached, revealed, the target
  desk.gd                  the Desk: outlines, slots, cards, the light, the result
  data/branches.json       per villager: the rooms in order, the goal room, the idea, what it develops into, the outline's slots
  data/scraps.json         shapes and names
  rooms/room_hub.tscn      two exits with signs
  rooms/goal_*.tscn        three goal rooms
  dream.gd                 the branch dealer replaces the deck; exits carry a branch id; the self-pinch; reached
  village.gd               the wall and the Desk by day; breakfast removed as the burst
tests/toy_pinch_loop2_test.gd/.tscn   the second loop, headless
```

## Verification

- Headless, from a clean import: the map lists three branches and the chosen
  target; the dream starts in the hub and the exits lead down the chosen
  branch in the fixed order; scraps count +1 and carry 3; the self-pinch
  needs 3 s still and keeps every scrap, not the idea; reaching the idea
  ends the night with it and the scraps; the forced waking keeps one scrap;
  the Desk fits only matching shapes, costs 5 s on a wrong one, develops the
  thing at all slots and keeps an unfinished outline for the next morning,
  reveals a room from three scraps;
  the pill raises the limit on the next night; the building rises; the
  lantern reveals; a four-night scripted run chooses four targets and ends
  with at least two developed things.
- The designer plays each evening; three observations.
- One confidant, week of 2026-11-03, twenty minutes, the question above.

## Build, three Claude days

| Day | Lands | Playable as |
| --- | --- | --- |
| A | the wall and the target; the hub and branch dealer; exits with signs; scraps; the three goal rooms with the sleeping villager and the idea; reaching ends the night; the self-pinch; forced waking keeps one scrap; the dev bar's new lines | choose a dream, pinch down its branch, reach the idea or bail out |
| B | the Desk: outlines, cards, the light, full and weak development (the weak grade was removed on day C), map knowledge; the pill, the building, the lantern; the villagers' new lines; the first-loop leftovers removed | the whole loop, four nights |
| C | balance measured on the three branches, feel at the wall and the Desk, README rewritten for the confidant, a four-night run | the toy as the confidant will see it |
