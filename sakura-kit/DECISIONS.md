# Decisions

One line per piece per verdict: date · piece · LOVE / FIX / KILL · why · contract change (if any).
Taste lives here; the validator never decides fit.

## Defaults (2026-10-20)

- Engine: Godot 4.3+ first; Unity and Unreal through the same scene JSON.
- Camera: first-person. Capsule radius 0.35 m, height 1.80 m, eye 1.60 m, step 0.25 m, clear door 0.80 m.
- Storey: 2.5 m. The walk may overturn it once, to 3.0 m, before Phase 2.
- Scale: ship a slice at 27-40 pieces.
- Hours per week: not yet stated.

## Verdicts

| Date | Piece | Verdict | Why | Contract change |
| --- | --- | --- | --- | --- |
| 2026-10-20 | floor_tatami | LOVE | reads as a mat at 48 px; border strips give the half-mat pattern when rotated | floor cap 24 -> 48 (borders cost 12 tris) |
