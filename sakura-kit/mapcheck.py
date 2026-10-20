"""Check a scene JSON before it goes anywhere near an engine.

    python mapcheck.py scenes/teahouse.json

Structural pieces (floor, wall, door, pillar, roof) must sit on the grid and
occupy their slot exclusively; props, garden pieces and trees must stand on a
floor (or on another prop); corners need a pillar; and a character must be
able to walk from the start cell to every tatami cell, crossing a wall line
only through an open door bay. Exit 1 on any failure.
"""
from __future__ import annotations

import json
import math
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.abspath(__file__))
START = (2.5, -6.5)          # the south end of the stone path
WALL_H = 2.5
TOL = 1e-6


def on_half(v):
    return abs((v - 0.5) - round(v - 0.5)) < TOL


def on_int(v):
    return abs(v - round(v)) < TOL


def cell(x, y):
    return (math.floor(x + TOL), math.floor(y + TOL))


def edge_of(x, y, rot):
    """A wall/door segment as the edge between two cells. rot 0/2 run along X at
    integer y; rot 1/3 run along Y at integer x. Returns (cell_a, cell_b)."""
    if rot % 2 == 0:
        if not (on_half(x) and on_int(y)):
            return None
        c = cell(x, y)
        return ((c[0], c[1] - 1), (c[0], c[1]))
    if not (on_int(x) and on_half(y)):
        return None
    c = cell(x, y)
    return ((c[0] - 1, c[1]), (c[0], c[1]))


def main(path):
    data = json.load(open(path))
    pl = data["placements"]
    sizes = {}
    rep_path = os.path.join(ROOT, "build", "report.json")
    if os.path.exists(rep_path):
        for r in json.load(open(rep_path)):
            if r.get("size"):
                sizes[r["name"]] = r["size"]
    fails: list[str] = []

    floors, walls, pillars, roofs = {}, {}, {}, {}
    blocked_edges: set[frozenset] = set()
    open_edges: set[frozenset] = set()
    for p in pl:
        cat, name, x, y, z, rot = p["category"], p["piece"], p["x"], p["y"], p["z"], p["rot"]
        if cat == "floor":
            if not (on_half(x) and on_half(y) and abs(z) < TOL):
                fails.append(f"{name} at ({x}, {y}, {z}) is off the floor grid")
            c = cell(x, y)
            if c in floors:
                fails.append(f"two floors in cell {c}: {floors[c]} and {name}")
            floors[c] = name
            p["_walkable"] = p.get("walkable", True)
        elif cat in ("wall", "door"):
            e = edge_of(x, y, rot)
            if e is None or abs(z) > TOL:
                fails.append(f"{name} at ({x}, {y}, {z}) rot {rot} is off the wall grid")
                continue
            key = frozenset(e)
            if key in walls:
                fails.append(f"two walls on edge {e}: {walls[key]} and {name}")
            walls[key] = name
            (open_edges if "_open" in name else blocked_edges).add(key)
        elif cat == "pillar":
            if not (on_int(x) and on_int(y) and abs(z) < TOL):
                fails.append(f"{name} at ({x}, {y}) is off a grid vertex")
            v = (round(x), round(y))
            if v in pillars:
                fails.append(f"two pillars at {v}")
            pillars[v] = name
        elif cat == "roof":
            if not (on_half(x) and on_int(y) and abs(z - WALL_H) < TOL):
                fails.append(f"{name} at ({x}, {y}, {z}) rot {rot}: roofs sit on a ridge line at z = {WALL_H}")
            key = (x, y, rot % 4)
            if key in roofs:
                fails.append(f"two roofs at {key}")
            roofs[key] = name

    # Non-structural pieces stand on a floor; stacked ones stand on a prop in the same cell.
    # A fence is an edge piece like a wall; a tree touches the ground only at its trunk.
    ground_props = {cell(p["x"], p["y"]) for p in pl if p["category"] in ("prop", "garden") and abs(p["z"]) < TOL}
    for p in pl:
        if p["category"] == "garden" and "_fence_" in p["piece"]:
            if edge_of(p["x"], p["y"], p["rot"]) is None:
                fails.append(f"{p['piece']} at ({p['x']}, {p['y']}) rot {p['rot']} is off the edge grid")
            continue
        if p["category"] in ("prop", "garden", "tree", "fx"):
            c = cell(p["x"], p["y"])
            w, d = (sizes.get(p["piece"]) or [1, 1, 1])[:2]
            if p["category"] == "tree":
                w = d = 0.3
            if p["rot"] % 2:
                w, d = d, w
            cells = {cell(p["x"] + dx, p["y"] + dy) for dx in (-(w / 2 - 0.01), w / 2 - 0.01) for dy in (-(d / 2 - 0.01), d / 2 - 0.01)}
            if abs(p["z"]) < TOL:
                for cc in cells:
                    if cc not in floors:
                        fails.append(f"{p['piece']} at ({p['x']}, {p['y']}) overhangs cell {cc}, which has no floor")
            elif c not in ground_props:
                fails.append(f"{p['piece']} at z = {p['z']} is stacked on nothing in cell {c}")

    # A pillar at every vertex where wall segments meet at an angle (corner, T, cross).
    by_vertex: dict[tuple, set] = {}
    for key in walls:
        a, b = sorted(key)
        if a[0] == b[0]:        # edge along X between cells stacked in y: vertices at x, x+1 on the shared line
            vx, vy = a[0], max(a[1], b[1])
            for v in ((vx, vy), (vx + 1, vy)):
                by_vertex.setdefault(v, set()).add("x")
        else:                   # edge along Y
            vx, vy = max(a[0], b[0]), a[1]
            for v in ((vx, vy), (vx, vy + 1)):
                by_vertex.setdefault(v, set()).add("y")
    for v, dirs in by_vertex.items():
        if len(dirs) == 2 and v not in pillars:
            fails.append(f"walls meet at an angle at {v} with no pillar")

    # Walkability: flood fill over walkable floors, never through a blocked edge.
    walkable = {c for c, n in floors.items() if not any(p["piece"] == n and p.get("walkable") is False for p in pl)}
    start = cell(*START)
    if start not in walkable:
        fails.append(f"start cell {start} has no walkable floor")
    seen, q = {start}, deque([start])
    while q:
        c = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if n in walkable and n not in seen and frozenset((c, n)) not in blocked_edges:
                seen.add(n)
                q.append(n)
    tatami = [c for c, n in floors.items() if "tatami" in n]
    unreached = [c for c in tatami if c not in seen]
    if unreached:
        fails.append(f"{len(unreached)} tatami cells cannot be reached from {start}: {sorted(unreached)}")

    print(f"{len(pl)} placements: {len(floors)} floors, {len(walls)} wall/door edges ({len(open_edges)} open), "
          f"{len(pillars)} pillars, {len(roofs)} roofs; {len(seen)} cells reachable from {start}")
    for f in fails:
        print("   x", f)
    print("PASS" if not fails else f"FAIL ({len(fails)})")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "scenes", "teahouse.json")))
