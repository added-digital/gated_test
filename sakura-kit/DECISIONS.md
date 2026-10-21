# Decisions

One line per piece per verdict: date · piece · LOVE / FIX / KILL · why · contract change (if any).
Taste lives here; the validator never decides fit.

## Defaults (2026-10-20; the 2026-10-21 block below replaces the lines it names)

- Engine: Godot 4.3+ first; Unity and Unreal through the same scene JSON.
- Camera: first-person. Capsule radius 0.35 m, height 1.80 m, eye 1.60 m, step 0.25 m, clear door 0.80 m.
- Storey: 2.5 m. The walk may overturn it once, to 3.0 m, before Phase 2.
- Scale: ship a slice at 27-40 pieces.
- Hours per week: not yet stated.

## Defaults, scale pass (2026-10-21)

From the first human walk (`breaks.md` 2026-10-21: "can't squeeze between the
table and the door", "bridge feels super small", "everything too close, not
walkable"). These replace the matching lines above; the rest stand.

- Engine: Godot 4.6 (the version the human runs; `project.godot` features ["4.6", "Forward Plus"]).
- Camera: first-person, 90° HORIZONTAL field of view (Godot: Camera3D keep_aspect KEEP_WIDTH, fov 90). Eye 1.60 m.
- Body: capsule radius 0.30 m (was 0.35), height 1.80 m. Walk speed 3.5 m/s (was 3.0).
- Layout: the tea room 5 x 4 tiles with 0.8 m clear around furniture; the bridge 3 m, spanning the whole pond; pond water 0.20 m below the rim.

## Verdicts

| Date | Piece | Verdict | Why | Contract change |
| --- | --- | --- | --- | --- |
| 2026-10-20 | floor_tatami | LOVE | reads as a mat at 48 px; border strips give the half-mat pattern when rotated | floor cap 24 -> 48 (borders cost 12 tris) |
