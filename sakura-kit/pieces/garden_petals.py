"""A patch of fallen sakura petals: two dozen tiny flat petals in three pinks, lying flat on the ground in a loose 0.9 m drift."""
import math
import random

import bmesh

from sakura_kit.contract import Piece

PETAL = (0.05, 0.035, 0.004)      # one petal: length x width x thickness (m)
DRIFT_RADIUS = 0.45               # the 0.9 m circle the patch lies inside
COUNT = 24
MIN_SPACING = 0.075               # > petal diagonal (0.061): no two coplanar tops overlap
SEED = 20260420
# Mostly pale, a few deeper petals so the patch reads as more than one tone.
COLOURS = ("sakura_light", "sakura_light", "sakura", "sakura", "sakura_deep")


def _scatter(rng, count, radius, spacing):
    """Deterministic rejection sampling: `count` points uniformly spread over a
    disc of `radius`, none closer than `spacing` to another."""
    pts = []
    tries = 0
    while len(pts) < count and tries < 20000:
        tries += 1
        r = radius * math.sqrt(rng.random())   # sqrt for uniform area density
        a = rng.random() * math.tau
        x, y = r * math.cos(a), r * math.sin(a)
        if all((x - px) ** 2 + (y - py) ** 2 >= spacing ** 2 for px, py in pts):
            pts.append((x, y))
    return pts


def build():
    p = Piece("sakura_garden_petals", "garden")
    rng = random.Random(SEED)
    # Keep every corner inside the drift circle: pull the centre radius in by
    # the petal's half-diagonal.
    half_diag = math.hypot(PETAL[0], PETAL[1]) / 2
    for x, y in _scatter(rng, COUNT, DRIFT_RADIUS - half_diag, MIN_SPACING):
        p.box(PETAL, at=(x, y, 0), rot=(0, 0, rng.uniform(0.0, 360.0)), color=rng.choice(COLOURS))
    # A random scatter is never exactly centred; the origin rule is. Slide the
    # whole drift so its bounding box is centred on the origin (z untouched, so
    # every petal still lies on z = 0).
    xs = [v.co.x for v in p.bm.verts]
    ys = [v.co.y for v in p.bm.verts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    bmesh.ops.translate(p.bm, vec=(-cx, -cy, 0.0), verts=p.bm.verts[:])
    return p.finish()
