#!/usr/bin/env python3
"""
tools/gated_page.py: builds build/gated.html, the *gated* page, version 1.

One screen with a sidebar: Design, World, Kit, Characters, Decisions.
Everything on the page comes from files in this repository. Nothing is typed
in here that the repo does not already say, with one marked exception: the
three numbered "where a toy could stand" markers on the map, which the page
labels as a proposal.

    python3 tools/gated_page.py              # writes build/gated.html
    python3 tools/gated_page.py --out x.html

Pillow is used for the kit thumbnails; without it the page has no thumbnails.
"""
from __future__ import annotations

import base64
import datetime as dt
import html
import io
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "sakura-kit"
GAME = ROOT / "game"
PROTOTYPES = GAME / "godot" / "prototypes"


def esc(s) -> str:
    return html.escape(str(s), quote=True)


def md(s) -> str:
    """Escape, then render `code`, **bold** and *em* from the notes' markdown."""
    t = html.escape(str(s), quote=True)
    codes: list[str] = []

    def keep(m):
        codes.append(f"<code>{m.group(1)}</code>")
        return f"\x00{len(codes) - 1}\x00"

    t = re.sub(r"`([^`]+)`", keep, t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", t)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], t)


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


# ----------------------------------------------------------------------------
# contract.py: palette, roles, player numbers
# ----------------------------------------------------------------------------
CONTRACT_SRC = read(KIT / "sakura_kit" / "contract.py")

PALETTE: dict[str, str] = {}
_pal_block = re.search(r"PALETTE[^=]*=\s*OrderedDict\(\[(.*?)\]\)", CONTRACT_SRC, re.S)
for name, hexv in re.findall(r'\("([a-z_]+)",\s*"(#[0-9A-Fa-f]{6})"\)', _pal_block.group(1) if _pal_block else ""):
    PALETTE[name] = hexv.upper()
assert len(PALETTE) == 32, f"expected 32 palette cells, found {len(PALETTE)}"

ROLES: dict[str, list[str]] = {}
_roles_block = re.search(r"PALETTE_ROLES\s*=\s*\{(.*?)\n\}", CONTRACT_SRC, re.S)
for role, cells in re.findall(r'"(\w+)":\s*\[(.*?)\]', _roles_block.group(1) if _roles_block else "", re.S):
    ROLES[role] = re.findall(r'"([a-z_]+)"', cells)


def const(name: str, default):
    m = re.search(rf"^{name}\s*(?::[^=\n]+)?=\s*([-+0-9.]+)", CONTRACT_SRC, re.M)
    return type(default)(m.group(1)) if m else default


CONTRACT_VERSION = re.search(r'CONTRACT_VERSION\s*=\s*"([^"]+)"', CONTRACT_SRC).group(1)
PLAYER = dict(
    radius=const("PLAYER_RADIUS", 0.30),
    height=const("PLAYER_HEIGHT", 1.80),
    eye=const("PLAYER_EYE", 1.60),
    fov=const("PLAYER_FOV_H", 90),
    speed=const("PLAYER_SPEED", 3.5),
    clearance=const("CLEARANCE", 0.8),
)
GRID = const("GRID", 1.0)
WALL_H = const("WALL_H", 2.5)
PROP_SCALE = const("PROP_SCALE", 1.2)
WATER_Z = const("WATER_Z", -0.20)
NAME_RE = re.search(r'NAME_RE\s*=\s*re\.compile\(\s*r?"([^"]+)"', CONTRACT_SRC)
NAME_RE = NAME_RE.group(1) if NAME_RE else "sakura_<category>_<name>[_<variant>]"

# ----------------------------------------------------------------------------
# kit: report.json + previews
# ----------------------------------------------------------------------------
REPORT = json.loads(read(KIT / "build" / "report.json"))
KIT_PIECES: dict[str, dict] = {}
for r in REPORT:
    warns = [c for c in r.get("checks", []) if c.get("level") == "warn" and not c.get("ok")]
    KIT_PIECES[r["name"]] = dict(
        name=r["name"],
        short=r["name"].removeprefix("sakura_"),
        category=r["category"],
        ok=bool(r.get("ok")),
        tris=int(r.get("tris", 0)),
        budget=int(r.get("budget", 0)),
        size=[round(float(v), 3) for v in r.get("size", [0, 0, 0])],
        warnings=len(warns),
    )
CATEGORY_ORDER = ["floor", "wall", "door", "pillar", "roof", "prop", "garden", "tree", "fx"]
BUDGETS = {}
for p in KIT_PIECES.values():
    BUDGETS.setdefault(p["category"], p["budget"])


def thumb_data_uri(name: str, px: int = 144) -> str | None:
    path = KIT / "build" / "previews" / f"{name}.png"
    if not path.exists():
        return None
    try:
        from PIL import Image  # type: ignore
    except ImportError:
        return None
    im = Image.open(path).convert("RGBA")
    # trim transparent margins so the piece fills the thumbnail
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im.thumbnail((px, px), Image.LANCZOS)
    try:
        im = im.quantize(colors=128, method=Image.Quantize.FASTOCTREE)
    except Exception:
        pass
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


THUMBS = {n: thumb_data_uri(n) for n in KIT_PIECES}

# ----------------------------------------------------------------------------
# scene: teahouse.json
# ----------------------------------------------------------------------------
SCENE = json.loads(read(KIT / "scenes" / "teahouse.json"))
PLACEMENTS = SCENE["placements"]
PLACED = Counter(p["piece"] for p in PLACEMENTS)
for n, c in PLACED.items():
    if n in KIT_PIECES:
        KIT_PIECES[n]["placed"] = c
for p in KIT_PIECES.values():
    p.setdefault("placed", 0)

# ----------------------------------------------------------------------------
# NOTES.md, IDEAS.md, breaks.md
# ----------------------------------------------------------------------------
NOTES_SRC = read(GAME / "NOTES.md")


def sections(md: str) -> dict[str, str]:
    out, cur, buf = {}, "_", []
    for line in md.splitlines():
        m = re.match(r"^## (.+)$", line)
        if m:
            out[cur] = "\n".join(buf)
            cur, buf = m.group(1).strip(), []
        else:
            buf.append(line)
    out[cur] = "\n".join(buf)
    return out


def split_cells(line: str) -> list[str]:
    """Split a markdown table row on '|' that is not inside backticks."""
    cells, buf, in_code = [], [], False
    for ch in line.strip().strip("|"):
        if ch == "`":
            in_code = not in_code
        if ch == "|" and not in_code:
            cells.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    cells.append("".join(buf).strip())
    return cells


def table_rows(body: str) -> list[list[str]]:
    rows = []
    for line in body.splitlines():
        if line.startswith("|") and not re.match(r"^\|\s*-", line):
            rows.append(split_cells(line))
    return rows[1:] if rows else []  # drop the header row


def dated_lines(body: str) -> list[dict]:
    out = []
    for line in body.splitlines():
        m = re.match(r"^- (\d{4}-\d{2}-\d{2}) · (.+)$", line.strip())
        if m:
            out.append(dict(date=m.group(1), text=m.group(2).strip()))
    return out


SEC = sections(NOTES_SRC)
NOW = dated_lines(SEC.get("Now", ""))
HANDOFFS = dated_lines(SEC.get("Hand-offs", ""))
DECISION_LINES = dated_lines(SEC.get("Decisions", ""))

_goal_sec = SEC.get("Goal (rung 1)", "")
_gm = re.search(r"\*\*(\d{4}-\d{2}-\d{2}) — (.+?)\*\*", _goal_sec)
GOAL = dict(date=_gm.group(1), text=_gm.group(2)) if _gm else dict(date="", text="(no Goal sentence in NOTES.md)")
_gate = re.search(r"^Gate: (.+)$", _goal_sec, re.M)
GOAL["gate"] = _gate.group(1) if _gate else ""
_tex = re.search(r"Texture from the interview[^\n]*\n((?:.+\n?)+)", _goal_sec)
GOAL["texture"] = " ".join(l.strip() for l in _tex.group(1).splitlines()).strip() if _tex else ""

_toys_sec = SEC.get("Toys (rung 3)", "")
_q = re.search(r"Question: (.+?) Proof: (.+?) Gate: (.+)", _toys_sec)
TOYS_Q = dict(question=_q.group(1), proof=_q.group(2), gate=_q.group(3)) if _q else dict(question="", proof="", gate="")
TOYS = []
for cells in table_rows(_toys_sec):
    if len(cells) >= 4 and re.match(r"^\d", cells[0]):
        num, _, name = cells[0].partition(" ")
        TOYS.append(dict(num=int(num), name=name, hypothesis=cells[1], verb=cells[2], dead_by=cells[3]))
_rules = re.search(r"^Rules in force: (.+)$", _toys_sec, re.M)
TOY_RULES = _rules.group(1) if _rules else ""

LOG = []
for cells in table_rows(SEC.get("Log", "")):
    if len(cells) >= 5:
        LOG.append(dict(date=cells[0], rung=cells[1], question=cells[2], evidence=cells[3], kill=cells[4]))
LOG_LATEST = list(reversed(LOG))

IDEAS = []
for line in read(GAME / "IDEAS.md").splitlines():
    m = re.match(r"^- (\d{4}-\d{2}-\d{2}) · ([^·]+?) · (.+)$", line.strip())
    if m:
        IDEAS.append(dict(date=m.group(1), tag=m.group(2).strip(), text=m.group(3).strip()))

BREAKS = []
for cells in table_rows(read(KIT / "breaks.md")):
    if len(cells) >= 5 and re.match(r"^\d{4}-", cells[0]):
        BREAKS.append(dict(date=cells[0], seen=cells[1], measurement=cells[2], line=cells[3], change=cells[4]))
BREAKS_OPEN = [b for b in BREAKS if b["change"].upper().startswith("OPEN")]

# ----------------------------------------------------------------------------
# toys: dialogue.json, requests.json, lines.json
# ----------------------------------------------------------------------------
DIALOGUE = json.loads(read(PROTOTYPES / "remember" / "dialogue.json"))
NODES = DIALOGUE["nodes"]
NODE_BY_ID = {n["id"]: n for n in NODES}
CHOICE_POINTS = [n for n in NODES if n.get("choices")]
FLAGS = sorted({f for n in NODES for c in n.get("choices", []) for f in c.get("set", [])} | {f for n in NODES for f in n.get("set", [])})
CONDITIONAL = [n for n in NODES if n.get("if") or n.get("unless")]
PIM_LINES = [n for n in NODES if n.get("who") == DIALOGUE["character"]]


def excerpt(start_id: str, max_lines: int = 4) -> list[dict]:
    out, nid, seen = [], start_id, set()
    while nid and nid in NODE_BY_ID and len(out) < max_lines and nid not in seen:
        seen.add(nid)
        n = NODE_BY_ID[nid]
        out.append(dict(who=n.get("who", ""), text=n.get("text", ""), choices=[c["text"] for c in n.get("choices", [])]))
        if n.get("choices"):
            break
        nid = n.get("next")
    return out


ENCOUNTERS = [dict(start=e["start"], walk=e.get("then_walk_to"), lines=excerpt(e["start"])) for e in DIALOGUE["encounters"]]

REQUESTS = json.loads(read(PROTOTYPES / "help" / "requests.json"))
HELP_WORDS = json.loads(read(PROTOTYPES / "help" / "words.json"))
FAR_LINES = json.loads(read(PROTOTYPES / "far_sound" / "lines.json"))

# ----------------------------------------------------------------------------
# git
# ----------------------------------------------------------------------------
def git(*args) -> str:
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return ""


COMMIT = git("log", "-1", "--format=%h|%cI|%s")
COMMIT_HASH, COMMIT_DATE, COMMIT_SUBJECT = (COMMIT.split("|", 2) + ["", "", ""])[:3]
DIRTY = bool(git("status", "--porcelain"))
GENERATED_AT = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
TODAY = dt.date.today()

# ----------------------------------------------------------------------------
# the ladder (from the doc "How a game gets made"; rung 3 is where we stand)
# ----------------------------------------------------------------------------
LADDER = [
    dict(n=1, name="Goal", q="What should the player feel?", spend="Writing, rejecting kit-flavoured feelings, reading it aloud", trap="A mood board instead of a feeling; a verb smuggled in as a feeling", ai="Interviews you for 15 minutes; offers no sentence of its own", you="Write it yourself; every later gate is judged against this line"),
    dict(n=2, name="Walk", q="Does the pipeline hold up in Godot, and is Godot the engine?", spend="Import, scale, camera height, FPS check, project notes, a headless run", trap="A scenic tour turns into kit-fixing; the garden picks the verb", ai="Sets up the project, pins the Godot version, imports the kit, runs it headless", you="Walk it; log defects; fix only what blocks a toy; confirm Godot"),
    dict(n=3, name="Toys", q="Which single interaction is worth repeating?", spend="Grey boxes; a kit piece only if the hypothesis names it as the object", trap="Making it pretty, or keeping the toy that was most fun to build", ai="Builds each toy in prototypes/ from your hypothesis line; no polish", you="A hypothesis and a kill line per toy; play; book a confidant; name the verb"),
    dict(n=4, name="Loop", q="Is the loop fun for twenty minutes with placeholder art?", spend="Goal, fail, restart, feedback, difficulty, a grey avatar or hand", trap="Adding a second mechanic to rescue a verb that is not fun alone", ai="Implements each change in hours, runs it, logs minutes played and pacing", you="Play every build; write the question before each change; judge fun"),
    dict(n=5, name="Core", q="Are character, camera and controls at ship quality?", spend="A grey test room; the player's presence as the first new kit family", trap="Half-building five systems instead of finishing the one", ai="Brings the mechanic to ship quality; tests pin the locked numbers", you="Sign the numbers; read the controller code until you can explain it"),
    dict(n=6, name="Slice", q="Does one slice look and feel like the finished game?", spend="Full art, sound, UI, start/win/lose, the kit pieces this section needs", trap="A pretty slice built with tricks the remaining sections cannot use", ai="Builds and validates every piece; logs hours per asset and per scene", you="Art-direct to the contract; run the stranger test; read the hour log"),
    dict(n=7, name="Macro", q="Can the rest be produced at that quality with the hours you have?", spend="Arithmetic from the slice log, cutting, ranking the parking lot", trap="Scope set by ambition or the kit's size, not by slice arithmetic", ai="Drafts the macro from your notes; does the sums; flags excess", you="Cut until the number fits; write the end date and the kill date"),
    dict(n=8, name="Build", q="Is every section arriving at the slice's quality?", spend="Sections in macro order, content on demand, kit growth per section", trap="Parked ideas flood in because they are cheap (the second-system effect)", ai="Builds sections from specs; validator on every write; a weekly report", you="Spec each section; play each weekly build; hold the kill date"),
    dict(n=9, name="Ship", q="Is it finishable with the hours you have?", spend="Bug fixes, balance, performance, onboarding, the page, AI disclosure", trap="The last 10% is the last 90%; perfection as scope creep in disguise", ai="Fixes bugs from your notes; builds, exports, drafts the page", you="Watch strangers; stop when it is no longer painful; press release"),
]
CURRENT_RUNG = 3
PASSED = {1, 2}
for r in LADDER:
    r["status"] = "passed" if r["n"] in PASSED else ("now" if r["n"] == CURRENT_RUNG else "ahead")

# ----------------------------------------------------------------------------
# decisions: seeded from the files; the page keeps state overrides in db
# ----------------------------------------------------------------------------
def plain(t: str) -> str:
    return re.sub(r"[`*]", "", t)


DECISIONS: list[dict] = []
DECISIONS.append(dict(id="goal", text=f"Goal: {GOAL['text']}", source="NOTES.md · Goal", date=GOAL["date"], state="decided"))
for i, d in enumerate(DECISION_LINES, 1):
    DECISIONS.append(dict(id=f"notes-d{i:02d}", text=plain(d["text"]), source="NOTES.md · Decisions", date=d["date"], state="decided"))
for t in TOYS:
    DECISIONS.append(dict(id=f"toy-{t['name'].lower().replace(' ', '-')}", text=f"Toy {t['num']} {t['name']}: {t['hypothesis']}", source="NOTES.md · Toys", date=f"dead by {t['dead_by']}", state="testing"))
for i, b in enumerate(BREAKS, 1):
    if b in BREAKS_OPEN:
        change = re.sub(r"^OPEN[:,]?\s*", "", b["change"], flags=re.I)
        DECISIONS.append(dict(id=f"breaks-r{i:02d}", text=plain(f"{b['measurement']}. {change}"), source=f"breaks.md · row {i}", date=b["date"], state="open"))
for i, idea in enumerate(IDEAS, 1):
    DECISIONS.append(dict(id=f"ideas-l{i:02d}", text=plain(f"{idea['tag']}: {idea['text']}"), source="IDEAS.md", date=idea["date"], state="parked"))

# ----------------------------------------------------------------------------
# the map
# ----------------------------------------------------------------------------
S = 40.0  # px per metre
MINX, MAXX, MINY, MAXY = -6.5, 9.5, -11.0, 7.0
MAP_W, MAP_H = (MAXX - MINX) * S, (MAXY - MINY) * S


def X(x: float) -> float:
    return round((x - MINX) * S, 1)


def Y(y: float) -> float:
    return round((MAXY - y) * S, 1)


def M(v: float) -> float:
    return round(v * S, 1)


ITEMS: dict[str, dict] = {}
_svg: list[str] = []


def add_item(kind: str, title: str, **kw) -> str:
    iid = f"i{len(ITEMS) + 1}"
    ITEMS[iid] = dict(kind=kind, title=title, **kw)
    return iid


def piece_item(p: dict, title: str | None = None) -> str:
    name = p["piece"]
    kp = KIT_PIECES.get(name, {})
    return add_item(
        "piece",
        title or kp.get("short", name).replace("_", " "),
        piece=name,
        category=p["category"],
        x=p["x"],
        y=p["y"],
        rot=p.get("rot", 0),
        walkable=p.get("walkable"),
        footprint=p.get("footprint"),
        tris=kp.get("tris"),
        budget=kp.get("budget"),
        size=kp.get("size"),
        placed=kp.get("placed"),
    )


def g_open(iid: str, extra_class: str = "") -> str:
    return f'<g class="hit {extra_class}" data-id="{iid}" tabindex="0" role="button">'


FLOOR_FILL = {
    "sakura_floor_tatami": PALETTE["tatami"],
    "sakura_floor_wood": PALETTE["wood"],
    "sakura_floor_gravel_raked": PALETTE["gravel"],
    "sakura_floor_moss": PALETTE["moss"],
    "sakura_floor_stone_path": PALETTE["stone"],
    "sakura_floor_water": PALETTE["water"],
}

# unknown regions (what the repo does not contain yet)
UNKNOWN = [
    dict(title="West, past the pond", x0=-6, x1=-3.2, y0=-7.2, y1=4.2, note="Nothing here yet. The bridge's west end is the last cell."),
    dict(title="East, past the garden", x0=6.2, x1=9, y0=-7.2, y1=4.2, note="Nothing here yet. The fence stops at the garden's edge."),
    dict(title="North, behind the house", x0=-3, x1=6, y0=4.6, y1=6.6, note="Nothing here yet. The roof's north eave is the last thing drawn."),
    dict(title="South, past the fence", x0=-3, x1=6, y0=-10, y1=-7.6, note="Nothing here yet. The walk begins at the gate cell (2.5, -6.5); where the player comes from is unwritten."),
]
for u in UNKNOWN:
    iid = add_item("unknown", u["title"], note=u["note"], x=(u["x0"] + u["x1"]) / 2, y=(u["y0"] + u["y1"]) / 2)
    cx, cy = X((u["x0"] + u["x1"]) / 2), Y((u["y0"] + u["y1"]) / 2)
    _svg.append(
        g_open(iid, "unknown")
        + f'<rect x="{X(u["x0"])}" y="{Y(u["y1"])}" width="{M(u["x1"] - u["x0"])}" height="{M(u["y1"] - u["y0"])}" rx="6"/>'
        + f'<text x="{cx}" y="{cy}" class="lbl unk">{esc(u["title"].split(",")[0].lower())}</text>'
        + f'<text x="{cx}" y="{cy + 14}" class="lbl unk small">unknown</text></g>'
    )

# floors
for p in PLACEMENTS:
    if p["category"] != "floor":
        continue
    fill = FLOOR_FILL.get(p["piece"], PALETTE["gravel"])
    iid = piece_item(p)
    cls = p["piece"].removeprefix("sakura_floor_")
    extra = ""
    if p["piece"] == "sakura_floor_gravel_raked":
        extra = f'<rect x="{X(p["x"] - 0.5)}" y="{Y(p["y"] + 0.5)}" width="{M(1)}" height="{M(1)}" fill="url(#raked)"/>'
    if p["piece"] == "sakura_floor_wood":
        extra = f'<rect x="{X(p["x"] - 0.5)}" y="{Y(p["y"] + 0.5)}" width="{M(1)}" height="{M(1)}" fill="url(#planks)"/>'
    _svg.append(
        g_open(iid, f"floor {cls}")
        + f'<rect x="{X(p["x"] - 0.5)}" y="{Y(p["y"] + 0.5)}" width="{M(1)}" height="{M(1)}" fill="{fill}"/>'
        + extra
        + "</g>"
    )

# roof (drawn under walls so the outline reads as the eave line)
_roofs = [p for p in PLACEMENTS if p["category"] == "roof"]
if _roofs:
    rx0 = min(p["x"] for p in _roofs) - 0.5
    rx1 = max(p["x"] for p in _roofs) + 0.5
    ridge = _roofs[0]["y"]
    depth = KIT_PIECES.get("sakura_roof_eave_1m", {}).get("size", [1, 2.2, 1.1])[1]
    iid = add_item("roof", "roof, ten eaves", piece="sakura_roof_eave_1m", x=(rx0 + rx1) / 2, y=ridge, count=len(_roofs), tris=KIT_PIECES.get("sakura_roof_eave_1m", {}).get("tris"), note=f"Two rows of {len(_roofs)//2} eaves meet at the ridge y = {ridge}; each runs {depth} m from the ridge, 0.2 m past the wall.")
    _svg.append(
        g_open(iid, "roof")
        + f'<rect x="{X(rx0)}" y="{Y(ridge + depth)}" width="{M(rx1 - rx0)}" height="{M(2 * depth)}" fill="{PALETTE["roof_tile"]}" fill-opacity="0.10" stroke="{PALETTE["roof_dark"]}" stroke-dasharray="6 4" stroke-width="1.5"/>'
        + f'<line x1="{X(rx0)}" y1="{Y(ridge)}" x2="{X(rx1)}" y2="{Y(ridge)}" stroke="{PALETTE["roof_dark"]}" stroke-width="2" stroke-dasharray="2 4"/>'
        + "</g>"
    )

# fence (edge pieces)
for p in PLACEMENTS:
    if "fence" not in p["piece"]:
        continue
    iid = piece_item(p, "bamboo fence")
    if p.get("rot", 0) % 2 == 0:
        x1, y1, x2, y2 = X(p["x"] - 0.5), Y(p["y"]), X(p["x"] + 0.5), Y(p["y"])
    else:
        x1, y1, x2, y2 = X(p["x"]), Y(p["y"] - 0.5), X(p["x"]), Y(p["y"] + 0.5)
    _svg.append(
        g_open(iid, "fence")
        + f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{PALETTE["bamboo"]}" stroke-width="5" stroke-linecap="round"/>'
        + f'<circle cx="{x1}" cy="{y1}" r="3" fill="{PALETTE["bamboo_node"]}"/><circle cx="{x2}" cy="{y2}" r="3" fill="{PALETTE["bamboo_node"]}"/>'
        + "</g>"
    )

# walls and doors
for p in PLACEMENTS:
    if p["category"] not in ("wall", "door"):
        continue
    is_door = p["category"] == "door"
    is_open = p["piece"].endswith("_open")
    iid = piece_item(p, "shoji, open bay" if is_open else ("shoji, closed" if is_door else "plain wall"))
    t = 0.14
    if p.get("rot", 0) % 2 == 0:
        bx, by, bw, bh = X(p["x"] - 0.5), Y(p["y"] + t / 2), M(1), M(t)
    else:
        bx, by, bw, bh = X(p["x"] - t / 2), Y(p["y"] + 0.5), M(t), M(1)
    if is_open:
        jamb = 0.06
        if p.get("rot", 0) % 2 == 0:
            body = (f'<rect x="{X(p["x"] - 0.5)}" y="{by}" width="{M(jamb)}" height="{bh}" fill="{PALETTE["lattice"]}"/>'
                    f'<rect x="{X(p["x"] + 0.5 - jamb)}" y="{by}" width="{M(jamb)}" height="{bh}" fill="{PALETTE["lattice"]}"/>')
        else:
            body = (f'<rect x="{bx}" y="{Y(p["y"] + 0.5)}" width="{bw}" height="{M(jamb)}" fill="{PALETTE["lattice"]}"/>'
                    f'<rect x="{bx}" y="{Y(p["y"] - 0.5 + jamb)}" width="{bw}" height="{M(jamb)}" fill="{PALETTE["lattice"]}"/>')
        body += f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="transparent"/>'
    elif is_door:
        body = f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{PALETTE["paper"]}" stroke="{PALETTE["lattice"]}" stroke-width="1.5"/>'
    else:
        body = f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{PALETTE["lattice"]}"/>'
    _svg.append(g_open(iid, "wall") + body + "</g>")

# pillars
for p in PLACEMENTS:
    if p["category"] != "pillar":
        continue
    iid = piece_item(p, "pillar post")
    s = 0.22
    _svg.append(g_open(iid, "pillar") + f'<rect x="{X(p["x"] - s/2)}" y="{Y(p["y"] + s/2)}" width="{M(s)}" height="{M(s)}" fill="{PALETTE["wood_dark"]}" stroke="{PALETTE["ink"]}" stroke-width="1"/></g>')

# garden pieces (not fences)
def _scatter(cx: float, cy: float, n: int, r: float, seed: int) -> list[tuple[float, float]]:
    pts, v = [], seed * 9973 + 17
    for _ in range(n):
        v = (v * 1103515245 + 12345) % (2**31)
        a = (v % 3600) / 10.0
        v = (v * 1103515245 + 12345) % (2**31)
        d = r * ((v % 1000) / 1000.0) ** 0.5
        import math
        pts.append((cx + d * math.cos(math.radians(a)), cy + d * math.sin(math.radians(a))))
    return pts


for idx, p in enumerate(PLACEMENTS):
    if p["category"] != "garden" or "fence" in p["piece"]:
        continue
    short = p["piece"].removeprefix("sakura_garden_")
    x, y = p["x"], p["y"]
    if short.startswith("bridge"):
        w, d = p.get("footprint", [3.0, 1.2])
        if p.get("rot", 0) % 2:
            w, d = d, w
        iid = piece_item(p, "bridge")
        planks = "".join(
            f'<line x1="{X(x - w/2 + k*0.25)}" y1="{Y(y + d/2)}" x2="{X(x - w/2 + k*0.25)}" y2="{Y(y - d/2)}" stroke="{PALETTE["wood_dark"]}" stroke-opacity="0.5" stroke-width="1"/>'
            for k in range(1, int(w / 0.25))
        )
        _svg.append(
            g_open(iid, "garden")
            + f'<rect x="{X(x - w/2)}" y="{Y(y + d/2)}" width="{M(w)}" height="{M(d)}" fill="{PALETTE["wood_light"]}" stroke="{PALETTE["wood_dark"]}" stroke-width="2"/>'
            + planks
            + "</g>"
        )
    elif short.startswith("water_basin"):
        iid = piece_item(p, "water basin")
        _svg.append(g_open(iid, "garden") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.3)}" fill="{PALETTE["water"]}" stroke="{PALETTE["stone_dark"]}" stroke-width="2"/></g>')
    elif short.startswith("lantern_stone"):
        iid = piece_item(p, "stone lantern")
        _svg.append(g_open(iid, "garden") + f'<rect x="{X(x - 0.3)}" y="{Y(y + 0.3)}" width="{M(0.6)}" height="{M(0.6)}" fill="{PALETTE["stone"]}" stroke="{PALETTE["stone_dark"]}" stroke-width="1.5"/><rect x="{X(x - 0.12)}" y="{Y(y + 0.12)}" width="{M(0.24)}" height="{M(0.24)}" fill="{PALETTE["gold"]}"/></g>')
    elif short.startswith("rock"):
        iid = piece_item(p, "garden rock")
        _svg.append(g_open(iid, "garden") + f'<ellipse cx="{X(x)}" cy="{Y(y)}" rx="{M(0.35)}" ry="{M(0.28)}" fill="{PALETTE["stone"]}" stroke="{PALETTE["stone_dark"]}" stroke-width="1.5" transform="rotate({p.get("rot",0)*25} {X(x)} {Y(y)})"/></g>')
    elif short.startswith("bamboo_cluster"):
        iid = piece_item(p, "bamboo cluster")
        culms = "".join(f'<circle cx="{X(px)}" cy="{Y(py)}" r="{M(0.07)}" fill="{PALETTE["bamboo"]}" stroke="{PALETTE["bamboo_node"]}" stroke-width="1"/>' for px, py in _scatter(x, y, 7, 0.3, idx))
        _svg.append(g_open(iid, "garden") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.42)}" fill="{PALETTE["bamboo"]}" fill-opacity="0.18"/>' + culms + "</g>")
    elif short.startswith("petals"):
        iid = piece_item(p, "fallen petals")
        dots = "".join(f'<circle cx="{X(px)}" cy="{Y(py)}" r="2" fill="{PALETTE["sakura"]}" stroke="{PALETTE["sakura_deep"]}" stroke-width="0.5"/>' for px, py in _scatter(x, y, 9, 0.45, idx))
        _svg.append(g_open(iid, "garden") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.5)}" fill="transparent"/>' + dots + "</g>")
    else:
        iid = piece_item(p)
        _svg.append(g_open(iid, "garden") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.3)}" fill="{PALETTE["stone"]}"/></g>')

# props
for p in PLACEMENTS:
    if p["category"] != "prop":
        continue
    short = p["piece"].removeprefix("sakura_prop_")
    x, y = p["x"], p["y"]
    size = KIT_PIECES.get(p["piece"], {}).get("size", [0.5, 0.5, 0.5])
    w, d = size[0], size[1]
    if p.get("rot", 0) % 2:
        w, d = d, w
    if short == "table_low":
        iid = piece_item(p, "low table")
        _svg.append(g_open(iid, "prop") + f'<rect x="{X(x - w/2)}" y="{Y(y + d/2)}" width="{M(w)}" height="{M(d)}" rx="3" fill="{PALETTE["wood"]}" stroke="{PALETTE["wood_dark"]}" stroke-width="1.5"/></g>')
    elif short == "tea_set":
        iid = piece_item(p, "tea set, on the table")
        _svg.append(g_open(iid, "prop") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.16)}" fill="{PALETTE["gold"]}" stroke="{PALETTE["wood_dark"]}" stroke-width="1"/></g>')
    elif short == "cushion":
        iid = piece_item(p, "cushion")
        _svg.append(g_open(iid, "prop") + f'<rect x="{X(x - w/2)}" y="{Y(y + d/2)}" width="{M(w)}" height="{M(d)}" rx="4" fill="{PALETTE["cushion"]}" stroke="{PALETTE["cushion_dark"]}" stroke-width="1"/></g>')
    elif short == "ikebana":
        iid = piece_item(p, "ikebana")
        _svg.append(g_open(iid, "prop") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.24)}" fill="{PALETTE["sakura_deep"]}" stroke="{PALETTE["lattice"]}" stroke-width="1"/></g>')
    elif short == "lantern_paper":
        iid = piece_item(p, "paper lantern")
        _svg.append(g_open(iid, "prop") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.2)}" fill="{PALETTE["paper"]}" stroke="{PALETTE["vermilion"]}" stroke-width="1.5"/></g>')
    else:
        iid = piece_item(p)
        _svg.append(g_open(iid, "prop") + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.2)}" fill="{PALETTE["wood"]}"/></g>')

# trees (drawn last among pieces, translucent so what is under the canopy shows)
for p in PLACEMENTS:
    if p["category"] != "tree":
        continue
    size = KIT_PIECES.get(p["piece"], {}).get("size", [2.8, 2.8, 3.5])
    r = size[0] / 2
    iid = piece_item(p, "sakura tree " + p["piece"][-1].upper())
    x, y = p["x"], p["y"]
    _svg.append(
        g_open(iid, "tree")
        + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(r)}" fill="{PALETTE["sakura"]}" fill-opacity="0.8" stroke="{PALETTE["sakura_deep"]}" stroke-width="1.5"/>'
        + f'<circle cx="{X(x - r*0.3)}" cy="{Y(y + r*0.25)}" r="{M(r*0.45)}" fill="{PALETTE["sakura_light"]}" fill-opacity="0.9"/>'
        + f'<circle cx="{X(x + r*0.35)}" cy="{Y(y - r*0.2)}" r="{M(r*0.4)}" fill="{PALETTE["sakura_deep"]}" fill-opacity="0.55"/>'
        + f'<circle cx="{X(x)}" cy="{Y(y)}" r="{M(0.12)}" fill="{PALETTE["bark"]}"/>'
        + "</g>"
    )

# the test walk's route and the start cell (from tests/walk_test.gd via NOTES)
ROUTE = [(2.5, -6.5), (2.5, -1.5), (2.5, -0.5), (2.5, 0.0), (2.5, 1.0)]
BRIDGE_WALK = [(1.5, -4.5), (-2.5, -4.5)]
_route_id = add_item("route", "the headless walk", note="tests/walk_test.gd: start (2.5, -6.5), north up the path to the engawa, through the open bay at (2.5, 0), onto the tatami at (2.5, 1.0); then the bridge from (1.5, -4.5) west to (-2.5, -4.5). Both pass headless on Godot 4.6.1.", x=2.5, y=-3.0)
_pts = " ".join(f"{X(x)},{Y(y)}" for x, y in ROUTE)
_bpts = " ".join(f"{X(x)},{Y(y)}" for x, y in BRIDGE_WALK)
_svg.append(
    g_open(_route_id, "route")
    + f'<polyline points="{_pts}" fill="none" stroke="{PALETTE["vermilion"]}" stroke-width="2.5" stroke-dasharray="7 5" stroke-linecap="round"/>'
    + f'<polyline points="{_bpts}" fill="none" stroke="{PALETTE["vermilion"]}" stroke-width="2.5" stroke-dasharray="7 5" stroke-linecap="round"/>'
    + f'<circle cx="{X(2.5)}" cy="{Y(-6.5)}" r="9" fill="{PALETTE["vermilion"]}" stroke="{PALETTE["paper"]}" stroke-width="2"/>'
    + f'<text x="{X(2.5)}" y="{Y(-6.5) + 4}" class="lbl onmark">S</text>'
    + "</g>"
)

# where the toys could stand once they leave grey ground (a proposal, not in any file)
HOTSPOTS = [
    dict(n=1, title="Remember: Pim", x=4.0, y=-0.5, toy="Remember", note="Proposal: Pim waits on the engawa, 'waiting for the painters'. The toy itself runs on grey ground in game/godot/prototypes/remember. Not placed in any scene file."),
    dict(n=2, title="Help: the runner", x=2.5, y=-3.5, toy="Help", note="Proposal: the runner hurries up and down the stone path and stops when you come within 3 m. The toy runs on grey ground in game/godot/prototypes/help. Not placed in any scene file."),
    dict(n=3, title="Far sound: the chime", x=-4.6, y=-5.2, toy="Far sound", note="Proposal: the first chime rings from past the pond, west, where there is no way through yet. The toy runs on grey ground in game/godot/prototypes/far_sound. Not placed in any scene file."),
]
for h in HOTSPOTS:
    iid = add_item("hotspot", h["title"], note=h["note"], x=h["x"], y=h["y"], toy=h["toy"], n=h["n"])
    _svg.append(
        g_open(iid, "hotspot")
        + f'<circle cx="{X(h["x"])}" cy="{Y(h["y"])}" r="{M(0.55)}" fill="{PALETTE["sakura_bud"]}" fill-opacity="0.15" stroke="{PALETTE["sakura_bud"]}" stroke-width="2" stroke-dasharray="4 3"/>'
        + f'<circle cx="{X(h["x"])}" cy="{Y(h["y"])}" r="9" fill="{PALETTE["sakura_bud"]}"/>'
        + f'<text x="{X(h["x"])}" y="{Y(h["y"]) + 4}" class="lbl onmark">{h["n"]}</text>'
        + "</g>"
    )

# labels
LABELS = [("tea room", 1.1, 1.0), ("engawa", 1.0, -0.5), ("garden", 4.2, -2.5), ("pond", -0.5, -3.0), ("bridge", -0.5, -5.3), ("path", 3.2, -5.5), ("fence", 2.5, -7.45)]
for text, x, y in LABELS:
    _svg.append(f'<text x="{X(x)}" y="{Y(y) + 4}" class="lbl">{esc(text)}</text>')
# scale bar and compass
_svg.append(
    f'<g class="scale"><line x1="{X(-6)}" y1="{Y(-10.5)}" x2="{X(-1)}" y2="{Y(-10.5)}"/>'
    + "".join(f'<line x1="{X(-6 + k)}" y1="{Y(-10.5) - 4}" x2="{X(-6 + k)}" y2="{Y(-10.5) + 4}"/>' for k in range(6))
    + f'<text x="{X(-3.5)}" y="{Y(-10.5) - 8}" class="lbl small">5 m · grid {GRID:g} m</text></g>'
)
_svg.append(f'<g class="compass"><text x="{X(8.7)}" y="{Y(6.4)}" class="lbl">N</text><line x1="{X(8.7)}" y1="{Y(5.3)}" x2="{X(8.7)}" y2="{Y(6.0)}"/><polygon points="{X(8.7)},{Y(6.2)} {X(8.5)},{Y(5.8)} {X(8.9)},{Y(5.8)}"/></g>')

MAP_SVG = (
    f'<svg id="map" viewBox="0 0 {MAP_W:.0f} {MAP_H:.0f}" role="img" aria-label="Top-down map of the tea house scene">'
    + "<defs>"
    + f'<pattern id="raked" width="{M(1)}" height="6" patternUnits="userSpaceOnUse">'
    + f'<line x1="0" y1="3" x2="{M(1)}" y2="3" stroke="{PALETTE["gravel_line"]}" stroke-width="1"/></pattern>'
    + f'<pattern id="planks" width="{M(1)}" height="{M(0.2)}" patternUnits="userSpaceOnUse">'
    + f'<line x1="0" y1="0.5" x2="{M(1)}" y2="0.5" stroke="{PALETTE["wood_dark"]}" stroke-opacity="0.35" stroke-width="1"/></pattern>'
    + "</defs>"
    + "".join(_svg)
    + "</svg>"
)

# reachable cells: from the latest mapcheck row in NOTES (a number, if present)
_reach = None
for row in LOG_LATEST:
    m = re.search(r"(\d+) cells reachable", row["evidence"])
    if m:
        _reach = int(m.group(1))
        break
FLOOR_COUNT = sum(1 for p in PLACEMENTS if p["category"] == "floor")

# ----------------------------------------------------------------------------
# HTML
# ----------------------------------------------------------------------------
def render_lines(lines: list[dict]) -> str:
    out = []
    for l in lines:
        who = esc(l["who"])
        out.append(f'<div class="line"><span class="who">{who}</span><span class="say">{esc(l["text"])}</span></div>')
        if l["choices"]:
            out.append('<ol class="choices">' + "".join(f"<li>{esc(c)}</li>" for c in l["choices"]) + "</ol>")
    return "".join(out)


def comment_btn(label: str = "Comment") -> str:
    return f'<button type="button" class="cbtn" data-comment>{esc(label)}</button>'


def days_to(datestr: str) -> str:
    try:
        d = dt.date.fromisoformat(datestr)
    except ValueError:
        return ""
    n = (d - TODAY).days
    if n < 0:
        return f"{-n} d past"
    if n == 0:
        return "today"
    return f"in {n} d"


# ---- Design view
_toys_rows = "".join(
    f'<tr><td class="num">{t["num"]}</td><td><b>{esc(t["name"])}</b><div class="muted">{esc(t["verb"])}</div></td>'
    f'<td class="hyp">{esc(t["hypothesis"])}</td><td class="mono nowrap">{esc(t["dead_by"])}<div class="muted">{days_to(t["dead_by"])}</div></td></tr>'
    for t in TOYS
)
_ladder_rows = "".join(
    f'<details class="rung {r["status"]}"><summary><span class="rn">{r["n"]}</span><span class="rname">{esc(r["name"])}</span>'
    f'<span class="rq">{esc(r["q"])}</span><span class="rstat">{ {"passed": "passed", "now": "now", "ahead": ""}[r["status"]] }</span></summary>'
    f'<div class="rbody"><div><b>You may spend on</b> {esc(r["spend"])}</div><div><b>The trap</b> {esc(r["trap"])}</div>'
    f'<div><b>The AI does</b> {esc(r["ai"])}</div><div><b>Only you do</b> {esc(r["you"])}</div></div></details>'
    for r in LADDER
)
_now_rows = "".join(f'<li><span class="mono">{esc(n["date"])}</span> {md(n["text"])}</li>' for n in NOW) or "<li>nothing under Now</li>"
_handoff_rows = "".join(f'<li><span class="mono">{esc(h["date"])}</span> {md(h["text"])}</li>' for h in HANDOFFS)
_latest = LOG_LATEST[0] if LOG_LATEST else None
_latest_html = (
    f'<div class="evidence"><div class="muted mono">{esc(_latest["date"])} · rung {esc(_latest["rung"])} · kill date still true? {esc(_latest["kill"])}</div>'
    f'<div class="q">{esc(_latest["question"])}</div><details><summary>{esc(_latest["evidence"][:260])}{"…" if len(_latest["evidence"]) > 260 else ""}</summary><p>{md(_latest["evidence"])}</p></details></div>'
    if _latest else ""
)
_palette_strip = "".join(f'<span class="sw" style="background:{v}" title="{esc(k)} {v}"></span>' for k, v in PALETTE.items())

DESIGN_HTML = f"""
<section class="view" id="design" aria-labelledby="design-h">
  <header class="vh"><h1 id="design-h">Design, on one page</h1><p class="sub">The two sentences, the ladder, the three toys, the theme. Everything here is quoted from <code>game/NOTES.md</code> and the ladder doc.</p></header>
  <div class="grid2">
    <article class="card goal" data-comment-target>
      <div class="eyebrow">Rung 1 · Goal · {esc(GOAL["date"])}</div>
      <p class="goal-line">{esc(GOAL["text"])}</p>
      <p class="muted">{esc(GOAL["gate"])}</p>
      <p>{esc(GOAL["texture"])}</p>
      {comment_btn()}
    </article>
    <article class="card verb" data-comment-target>
      <div class="eyebrow">The second sentence · written at the Toys gate</div>
      <p class="goal-line blank">the player <span class="fill">____</span>s <span class="fill">____</span> to <span class="fill">____</span></p>
      <p class="muted">Not yet written. It lands when one of the three toys passes its gate. If it needs "and", it is two games.</p>
      {comment_btn()}
    </article>
  </div>
  <div class="tiles">
    <div class="tile"><div class="n">{CURRENT_RUNG}<span class="of">/9</span></div><div class="l">rung · {esc(LADDER[CURRENT_RUNG-1]["name"])}</div></div>
    <div class="tile"><div class="n">{sum(1 for p in KIT_PIECES.values() if p["ok"])}<span class="of">/{len(KIT_PIECES)}</span></div><div class="l">kit pieces pass</div></div>
    <div class="tile"><div class="n">{len(PLACEMENTS)}</div><div class="l">placements in the tea house</div></div>
    <div class="tile"><div class="n">{_reach if _reach is not None else "–"}<span class="of">/{FLOOR_COUNT}</span></div><div class="l">floor cells reachable</div></div>
    <div class="tile"><div class="n">{len(BREAKS_OPEN)}</div><div class="l">open breaks</div></div>
    <div class="tile"><div class="n">{len(IDEAS)}</div><div class="l">ideas parked</div></div>
  </div>
  <div class="grid2">
    <article class="card" data-comment-target>
      <div class="eyebrow">Rung 3 · Toys · {esc(TOYS_Q["question"])}</div>
      <table class="toys"><thead><tr><th></th><th>Toy</th><th>Hypothesis, the designer's words</th><th>Dead by</th></tr></thead><tbody>{_toys_rows}</tbody></table>
      <p class="muted"><b>Gate</b> {esc(TOYS_Q["gate"])}</p>
      <p class="muted"><b>Rules in force</b> {esc(TOY_RULES)}</p>
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">The ladder · nine rungs, one question each</div>
      <div class="ladder">{_ladder_rows}</div>
      {comment_btn()}
    </article>
  </div>
  <div class="grid2">
    <article class="card" data-comment-target>
      <div class="eyebrow">Theme · sakura season, a tea house · contract {esc(CONTRACT_VERSION)}</div>
      <div class="strip">{_palette_strip}</div>
      <p class="muted">32 colours, one texture, one material. Grid {GRID:g} m, walls {WALL_H:g} m, props built at real size and scaled {PROP_SCALE:g}×. The player: a {PLAYER["radius"]:g} m capsule, {PLAYER["height"]:g} m tall, eye at {PLAYER["eye"]:g} m, {PLAYER["fov"]:g}° horizontal, {PLAYER["speed"]:g} m/s.</p>
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">Now · who is on what</div>
      <ul class="plain">{_now_rows}</ul>
      {"<div class='eyebrow'>Hand-offs</div><ul class='plain'>" + _handoff_rows + "</ul>" if _handoff_rows else ""}
      <div class="eyebrow">Latest evidence</div>
      {_latest_html}
      {comment_btn()}
    </article>
  </div>
</section>
"""

# ---- World view
_legend = "".join(
    f'<span class="lg"><i style="background:{FLOOR_FILL[k]}"></i>{esc(k.removeprefix("sakura_floor_").replace("_", " "))}</span>'
    for k in FLOOR_FILL
) + (
    f'<span class="lg"><i style="background:{PALETTE["lattice"]}"></i>wall</span>'
    f'<span class="lg"><i style="background:{PALETTE["paper"]};border:1px solid {PALETTE["lattice"]}"></i>shoji</span>'
    f'<span class="lg"><i style="background:{PALETTE["sakura"]}"></i>tree</span>'
    f'<span class="lg"><i style="background:{PALETTE["bamboo"]}"></i>fence, bamboo</span>'
    f'<span class="lg"><i style="background:{PALETTE["vermilion"]}"></i>the walk</span>'
    f'<span class="lg"><i style="background:{PALETTE["sakura_bud"]}"></i>a toy, proposed</span>'
    f'<span class="lg"><i class="dash"></i>unknown</span>'
)
WORLD_HTML = f"""
<section class="view" id="world" aria-labelledby="world-h">
  <header class="vh"><h1 id="world-h">World, from above</h1><p class="sub">{len(PLACEMENTS)} placements from <code>sakura-kit/scenes/teahouse.json</code>, north up, {GRID:g} m grid. Click anything. Dashed regions are what no file describes yet.</p></header>
  <div class="worldgrid">
    <div class="mapwrap" data-comment-target>{MAP_SVG}<div class="legend">{_legend}</div></div>
    <aside class="detail" id="detail" aria-live="polite"></aside>
  </div>
</section>
"""

# ---- Kit view
_cat_chips = '<button type="button" class="chip on" data-cat="all">all · {}</button>'.format(len(KIT_PIECES)) + "".join(
    f'<button type="button" class="chip" data-cat="{c}">{c} · {sum(1 for p in KIT_PIECES.values() if p["category"] == c)}</button>'
    for c in CATEGORY_ORDER if any(p["category"] == c for p in KIT_PIECES.values())
)
_kit_cards = []
for n in sorted(KIT_PIECES, key=lambda k: (CATEGORY_ORDER.index(KIT_PIECES[k]["category"]), k)):
    p = KIT_PIECES[n]
    pct = min(100, round(100 * p["tris"] / p["budget"])) if p["budget"] else 0
    img = f'<img src="{THUMBS[n]}" alt="{esc(p["short"])}" loading="lazy">' if THUMBS.get(n) else '<div class="nothumb">no preview</div>'
    sz = " × ".join(f"{v:g}" for v in p["size"])
    _kit_cards.append(
        f'<article class="kcard" id="kit-{esc(n)}" data-cat="{p["category"]}" data-comment-target>'
        f'<div class="thumb">{img}</div>'
        f'<div class="kname">{esc(p["short"].replace("_", " "))}</div>'
        f'<div class="kmeta"><span class="badge {p["category"]}">{p["category"]}</span><span class="mono">{sz} m</span></div>'
        f'<div class="bar" title="{p["tris"]} of {p["budget"]} tris"><i style="width:{pct}%"></i></div>'
        f'<div class="kmeta mono"><span>{p["tris"]} / {p["budget"]} tris</span><span>{"placed ×" + str(p["placed"]) if p["placed"] else "not placed"}</span></div>'
        f'<div class="kmeta"><span class="{"ok" if p["ok"] else "bad"}">{"passes" if p["ok"] else "FAILS"}{(" · " + str(p["warnings"]) + " warning") if p["warnings"] else ""}</span>{comment_btn()}</div>'
        "</article>"
    )
_roles_html = "".join(
    f'<div class="role"><div class="rname">{esc(role)}</div><div class="swl">'
    + "".join(f'<span class="swn"><i style="background:{PALETTE[c]}"></i>{esc(c)}</span>' for c in cells)
    + "</div></div>"
    for role, cells in ROLES.items()
)
_budget_rows = "".join(f'<tr><td>{c}</td><td class="mono">{BUDGETS[c]}</td></tr>' for c in CATEGORY_ORDER if c in BUDGETS)
KIT_HTML = f"""
<section class="view" id="kit" aria-labelledby="kit-h">
  <header class="vh"><h1 id="kit-h">Kit, {len(KIT_PIECES)} pieces</h1><p class="sub">From <code>sakura-kit/build/report.json</code> and the previews. Every piece passes the validator; the bar is triangles against the category budget.</p></header>
  <div class="chips" id="catchips">{_cat_chips}</div>
  <div class="kgrid" id="kgrid">{"".join(_kit_cards)}</div>
  <div class="grid2">
    <article class="card" data-comment-target>
      <div class="eyebrow">Palette by role · a new theme swaps hexes by role and nothing else moves</div>
      <div class="roles">{_roles_html}</div>
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">The contract in six lines · version {esc(CONTRACT_VERSION)}</div>
      <ul class="plain tight">
        <li>Grid {GRID:g} m; a piece's origin is bottom-centre, a roof's is its ridge edge.</li>
        <li>One palette texture (8 × 4 cells, 16 px each), one material, flat shading.</li>
        <li>Names: <code>{esc(NAME_RE)}</code></li>
        <li>Walls {WALL_H:g} m tall and {GRID:g} m wide; water {abs(WATER_Z):g} m below the rim; props scaled {PROP_SCALE:g}×.</li>
        <li>Every piece carries category, footprint, walkable and sockets as glTF extras; the scene JSON repeats them.</li>
        <li>A number changes only through a row in <code>sakura-kit/breaks.md</code>.</li>
      </ul>
      <table class="budgets"><thead><tr><th>category</th><th>tris max</th></tr></thead><tbody>{_budget_rows}</tbody></table>
      {comment_btn()}
    </article>
  </div>
</section>
"""

# ---- Characters view
_pim_enc = "".join(
    f'<div class="enc"><div class="eyebrow">Encounter {i+1}{(" · then Pim walks to (" + ", ".join(str(v) for v in e["walk"]) + ")") if e["walk"] else ""}</div>{render_lines(e["lines"])}</div>'
    for i, e in enumerate(ENCOUNTERS)
)
_req_html = "".join(
    f'<div class="enc"><div class="eyebrow">Request {i+1} · {esc(r["item"])} · {r["seconds"]} s · at ({r["at"][0]}, {r["at"][1]})</div>'
    f'<div class="line"><span class="who">runner</span><span class="say">{esc(r["ask"])}</span></div>'
    + (f'<div class="line alt"><span class="who">after a miss</span><span class="say">{esc(r["ask_after_miss"])}</span></div>' if r.get("ask_after_miss") else "")
    + "</div>"
    for i, r in enumerate(REQUESTS)
)
_far_html = "".join(f'<div class="line"><span class="who">{esc(k)}</span><span class="say">{esc(v)}</span></div>' for k, v in FAR_LINES.items())
_toy_by_name = {t["name"]: t for t in TOYS}


def toy_head(name: str) -> str:
    t = _toy_by_name.get(name)
    if not t:
        return ""
    return f'<p class="hyp">{esc(t["hypothesis"])}</p><p class="muted mono">verb: {esc(t["verb"])} · dead by {esc(t["dead_by"])} ({days_to(t["dead_by"])}) · state: built, fix-passed, awaiting confidants</p>'


CHARACTERS_HTML = f"""
<section class="view" id="characters" aria-labelledby="char-h">
  <header class="vh"><h1 id="char-h">Characters</h1><p class="sub">Everyone who exists in a file today: the player, and the three figures of the toys. Lines are quoted from the toys' JSON.</p></header>
  <div class="grid2">
    <article class="card" data-comment-target>
      <div class="eyebrow">You · the player</div>
      <h2>A capsule, first person</h2>
      <p>Radius {PLAYER["radius"]:g} m, {PLAYER["height"]:g} m tall, eye at {PLAYER["eye"]:g} m, {PLAYER["fov"]:g}° horizontal view, {PLAYER["speed"]:g} m/s. No hands, no body, no voice yet. The player's presence becomes the first new kit family at rung 5.</p>
      <p class="muted">Verbs available today, one per toy: choose (E, then 1 2 3), help (E to pick up, E to hand over), find the way (walking only).</p>
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">Toy 1 · Remember · <code>prototypes/remember/dialogue.json</code></div>
      <h2>{esc(DIALOGUE["character"])}</h2>
      {toy_head("Remember")}
      <p class="muted mono">{len(NODES)} nodes · {len(CHOICE_POINTS)} choice points · {len(FLAGS)} things remembered · {len(CONDITIONAL)} lines that depend on them · {len(PIM_LINES)} lines are Pim's</p>
      {_pim_enc}
      <details><summary>What Pim keeps ({len(FLAGS)} flags)</summary><p class="mono small">{esc(", ".join(FLAGS))}</p></details>
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">Toy 2 · Help · <code>prototypes/help/requests.json</code></div>
      <h2>The runner</h2>
      {toy_head("Help")}
      <p class="muted">{esc(HELP_WORDS.get("start", ""))} Three requests on three clocks; a miss changes the next ask.</p>
      {_req_html}
      {comment_btn()}
    </article>
    <article class="card" data-comment-target>
      <div class="eyebrow">Toy 3 · Far sound · <code>prototypes/far_sound/lines.json</code></div>
      <h2>The chime</h2>
      {toy_head("Far sound")}
      <p class="muted">Not a person: three chimes in sequence, each further and more blocked than the last, a gate on the far side of the third. Four lines in the whole toy.</p>
      {_far_html}
      {comment_btn()}
    </article>
  </div>
</section>
"""

# ---- Decisions view
_state_chips = "".join(
    f'<button type="button" class="chip{" on" if s == "all" else ""}" data-state="{s}">{s}</button>'
    for s in ("all", "open", "testing", "decided", "parked")
)
DECISIONS_HTML = f"""
<section class="view" id="decisions" aria-labelledby="dec-h">
  <header class="vh"><h1 id="dec-h">Decisions</h1><p class="sub">Seeded from NOTES.md (decided, testing), breaks.md (open) and IDEAS.md (parked). Click a state to cycle it; the change is saved for everyone who opens this page. <span id="dbstatus" class="muted">connecting…</span></p></header>
  <div class="chips" id="statechips">{_state_chips}</div>
  <div class="dlist" id="dlist"></div>
</section>
"""

# ---- shell
NAV = [
    ("design", "Design", "the two sentences"),
    ("world", "World", f"{len(PLACEMENTS)} placements"),
    ("kit", "Kit", f"{len(KIT_PIECES)} pieces"),
    ("characters", "Characters", "4"),
    ("decisions", "Decisions", f"{len(DECISIONS)}"),
]
_nav = "".join(f'<a class="nav" href="#{k}" data-view="{k}"><span class="nl">{esc(l)}</span><span class="nc">{esc(c)}</span></a>' for k, l, c in NAV)

DATA = dict(
    items=ITEMS,
    decisions=DECISIONS,
    kit={n: dict(short=p["short"], category=p["category"], tris=p["tris"], budget=p["budget"], size=p["size"], placed=p["placed"], thumb=bool(THUMBS.get(n))) for n, p in KIT_PIECES.items()},
    scene=dict(placements=len(PLACEMENTS), pieces=len(KIT_PIECES), floors=FLOOR_COUNT, reachable=_reach, bounds=[MINX, MAXX, MINY, MAXY]),
    toys={t["name"]: t for t in TOYS},
)

CSS = r"""
:root{
  --paper:#F7F2E8; --paper-2:#EDE6D6; --paper-3:#E9E2D3; --ink:#2B2A2E; --ink-2:#55402F;
  --muted:#7E7B73; --line:#D2CDBF; --sakura:#F3B1C8; --sakura-deep:#E58BAD; --bud:#C9557F;
  --vermilion:#B8403B; --moss:#6F924F; --water:#8FC0D6; --gold:#D9B45B; --lattice:#4A3A2E;
  --card:#FFFFFF; --shadow:0 1px 0 rgba(43,42,46,.06), 0 8px 24px -16px rgba(43,42,46,.25);
  --display:"Shippori Mincho", Georgia, serif; --body:"Zen Kaku Gothic New", system-ui, sans-serif; --mono:"IBM Plex Mono", ui-monospace, Menlo, monospace;
}
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --paper:#1F1E22; --paper-2:#2B2A2E; --paper-3:#35343A; --ink:#F7F2E8; --ink-2:#E9E2D3; --muted:#A9A69D; --line:#44434A;
  --card:#2B2A2E; --lattice:#D2A977; --shadow:0 1px 0 rgba(0,0,0,.3), 0 8px 24px -16px rgba(0,0,0,.6);
}}
:root[data-theme="dark"]{
  --paper:#1F1E22; --paper-2:#2B2A2E; --paper-3:#35343A; --ink:#F7F2E8; --ink-2:#E9E2D3; --muted:#A9A69D; --line:#44434A;
  --card:#2B2A2E; --lattice:#D2A977; --shadow:0 1px 0 rgba(0,0,0,.3), 0 8px 24px -16px rgba(0,0,0,.6);
}
*{box-sizing:border-box}
html,body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);font-size:15px;line-height:1.5}
a{color:inherit}
code{font-family:var(--mono);font-size:.85em;background:var(--paper-2);padding:1px 5px;border-radius:4px}
.mono{font-family:var(--mono);font-size:.85em}
.muted{color:var(--muted)}
.small{font-size:.85em}
.nowrap{white-space:nowrap}
.app{display:grid;grid-template-columns:220px 1fr;min-height:100vh}
.side{position:sticky;top:0;height:100vh;padding:22px 16px;border-right:1px solid var(--line);display:flex;flex-direction:column;gap:6px;background:var(--paper)}
.brand{font-family:var(--display);font-size:30px;line-height:1;margin:0 0 2px 4px;letter-spacing:.01em}
.brand i{display:inline-block;width:10px;height:10px;border-radius:50%;background:var(--sakura-deep);margin-left:6px;vertical-align:middle}
.tag{margin:0 4px 16px;color:var(--muted);font-size:.85em}
.nav{display:flex;justify-content:space-between;align-items:baseline;gap:8px;padding:9px 10px;border-radius:8px;text-decoration:none;color:var(--ink)}
.nav:hover{background:var(--paper-2)}
.nav.on{background:var(--ink);color:var(--paper)}
.nav .nl{font-family:var(--display);font-size:17px}
.nav .nc{font-family:var(--mono);font-size:.75em;opacity:.7}
.side .foot{margin-top:auto;font-size:.78em;color:var(--muted);line-height:1.45;padding:0 4px}
.side .foot b{color:var(--ink)}
main{padding:28px 32px 60px;min-width:0}
.view{display:none}
.view.on{display:block}
.vh{margin-bottom:18px}
.vh h1{font-family:var(--display);font-weight:500;font-size:34px;margin:0 0 4px;line-height:1.15}
.vh .sub{margin:0;color:var(--muted);max-width:70ch}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px;align-items:start}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px 20px;box-shadow:var(--shadow);position:relative;min-width:0}
.card h2{font-family:var(--display);font-weight:500;font-size:24px;margin:2px 0 8px}
.card p{margin:6px 0}
.eyebrow{font-family:var(--mono);font-size:.74em;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin:0 0 8px}
.eyebrow+ .eyebrow{margin-top:14px}
.eyebrow .mono,.eyebrow code{text-transform:none;letter-spacing:0}
.goal-line{font-family:var(--display);font-size:30px;line-height:1.2;margin:4px 0 10px}
.goal-line.blank{color:var(--muted)}
.fill{border-bottom:2px solid var(--sakura-deep);color:var(--ink)}
.tiles{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:16px}
.tile{background:var(--paper-2);border-radius:10px;padding:12px 14px}
.tile .n{font-family:var(--display);font-size:28px;line-height:1}
.tile .of{font-size:.55em;color:var(--muted)}
.tile .l{font-size:.8em;color:var(--muted);margin-top:4px}
table{border-collapse:collapse;width:100%}
th{text-align:left;font-weight:500;color:var(--muted);font-size:.8em;padding:4px 8px 6px;border-bottom:1px solid var(--line)}
td{padding:8px;vertical-align:top;border-bottom:1px solid var(--line)}
tr:last-child td{border-bottom:0}
td.num{font-family:var(--display);font-size:22px;color:var(--bud);width:26px}
td.hyp{font-size:.92em}
.ladder details{border-bottom:1px solid var(--line)}
.ladder details:last-child{border-bottom:0}
.ladder summary{display:grid;grid-template-columns:28px 72px 1fr auto;gap:8px;align-items:baseline;padding:8px 4px;cursor:pointer;list-style:none}
.ladder summary::-webkit-details-marker{display:none}
.ladder .rn{font-family:var(--display);font-size:18px;color:var(--muted)}
.ladder .rname{font-family:var(--display);font-size:18px}
.ladder .rq{font-size:.9em;color:var(--muted)}
.ladder .rstat{font-family:var(--mono);font-size:.72em;text-transform:uppercase;letter-spacing:.06em}
.ladder .passed .rstat{color:var(--moss)}
.ladder .passed .rn,.ladder .passed .rname{color:var(--muted)}
.ladder .now{background:linear-gradient(90deg, rgba(229,139,173,.18), transparent);border-radius:8px}
.ladder .now .rstat{color:var(--bud);font-weight:700}
.ladder .now .rname{color:var(--bud)}
.rbody{padding:4px 4px 12px 108px;font-size:.9em;display:grid;gap:4px}
.rbody b{font-weight:500;color:var(--muted);margin-right:4px}
ul.plain{list-style:none;padding:0;margin:0 0 8px}
ul.plain li{padding:4px 0;border-bottom:1px dashed var(--line)}
ul.plain li:last-child{border-bottom:0}
ul.tight li{padding:3px 0}
.evidence .q{font-family:var(--display);font-size:17px;margin:4px 0}
.evidence summary{cursor:pointer;color:var(--ink-2);font-size:.92em}
.evidence p{font-size:.88em;white-space:pre-wrap}
.strip{display:grid;grid-template-columns:repeat(16,1fr);gap:3px;margin:6px 0 10px}
.sw{display:block;aspect-ratio:1;border-radius:3px;border:1px solid rgba(0,0,0,.08)}
.cbtn{position:absolute;top:12px;right:12px;font:inherit;font-size:.78em;padding:4px 10px;border-radius:999px;border:1px solid var(--line);background:var(--paper);color:var(--ink);cursor:pointer}
.cbtn:hover{border-color:var(--bud);color:var(--bud)}
.no-comments .cbtn{display:none}
/* world */
.worldgrid{display:grid;grid-template-columns:minmax(0,1fr) 320px;gap:16px;align-items:start}
.mapwrap{background:#F7F2E8;border:1px solid var(--line);border-radius:12px;padding:10px;box-shadow:var(--shadow);position:relative}
#map{width:100%;height:auto;display:block;font-family:var(--mono)}
#map .lbl{font-family:var(--mono);font-size:11px;fill:#2B2A2E;text-anchor:middle;paint-order:stroke;stroke:#F7F2E8;stroke-width:3px;stroke-linejoin:round;pointer-events:none}
#map .lbl.small{font-size:9px}
#map .lbl.onmark{fill:#F7F2E8;stroke:none;font-weight:600;font-size:11px}
#map .lbl.unk{fill:#7E7B73;stroke:#F7F2E8}
#map .unknown rect{fill:#EDE6D6;fill-opacity:.5;stroke:#A9A69D;stroke-dasharray:6 5;stroke-width:1.2}
#map .hit{cursor:pointer}
#map .hit:hover rect,#map .hit:hover circle,#map .hit:hover ellipse,#map .hit:hover polyline{filter:brightness(.92)}
#map .hit.sel rect,#map .hit.sel circle,#map .hit.sel ellipse,#map .hit.sel line{stroke:#B8403B !important;stroke-width:2.5px !important;stroke-dasharray:none !important}
#map .hit:focus{outline:none}
#map .hit:focus-visible rect,#map .hit:focus-visible circle{stroke:#B8403B;stroke-width:2.5px}
#map .scale line{stroke:#2B2A2E;stroke-width:1.2}
#map .compass line,#map .compass polygon{stroke:#2B2A2E;fill:#2B2A2E;stroke-width:1.2}
#map .floor rect{stroke:#F7F2E8;stroke-width:.5;stroke-opacity:.6}
#map .floor.tatami rect{stroke:#3F4D3F;stroke-opacity:.35}
#map .floor.water rect{stroke:none}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;padding:8px 4px 0;font-size:.78em;color:#55402F;font-family:var(--mono)}
.lg i{display:inline-block;width:11px;height:11px;border-radius:2px;vertical-align:-1px;margin-right:5px}
.lg i.dash{border:1px dashed #7E7B73;background:transparent}
.detail{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px 18px;box-shadow:var(--shadow);position:sticky;top:16px;min-height:200px}
.detail h2{font-family:var(--display);font-weight:500;font-size:22px;margin:0 0 6px}
.detail .kv{display:grid;grid-template-columns:auto 1fr;gap:3px 12px;font-size:.88em;margin:8px 0}
.detail .kv b{font-weight:500;color:var(--muted)}
.detail img{width:120px;height:120px;object-fit:contain;float:right;margin:0 0 8px 8px;background:var(--paper-2);border-radius:8px}
.detail .cbtn{position:static;margin-top:10px}
.detail .link{font-size:.85em;color:var(--bud)}
/* kit */
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 14px}
.chip{font:inherit;font-size:.82em;padding:4px 11px;border-radius:999px;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer;font-family:var(--mono)}
.chip.on{background:var(--ink);color:var(--paper);border-color:var(--ink)}
.kgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(168px,1fr));gap:12px;margin-bottom:18px}
.kcard{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px;box-shadow:var(--shadow);position:relative;display:flex;flex-direction:column;gap:5px}
.kcard.hide{display:none}
.kcard.flash{outline:2px solid var(--bud)}
.thumb{aspect-ratio:1;background:var(--paper-2);border-radius:8px;display:flex;align-items:center;justify-content:center;overflow:hidden}
.thumb img{width:100%;height:100%;object-fit:contain;image-rendering:auto}
.nothumb{color:var(--muted);font-size:.8em}
.kname{font-family:var(--display);font-size:16px;line-height:1.2;margin-top:2px}
.kmeta{display:flex;justify-content:space-between;align-items:center;gap:6px;font-size:.78em;color:var(--muted)}
.kcard .cbtn{position:static;padding:2px 8px}
.badge{font-family:var(--mono);font-size:.72em;text-transform:uppercase;letter-spacing:.05em;padding:1px 6px;border-radius:4px;background:var(--paper-2);color:var(--ink)}
.bar{height:5px;background:var(--paper-2);border-radius:3px;overflow:hidden}
.bar i{display:block;height:100%;background:var(--sakura-deep)}
.ok{color:var(--moss)}.bad{color:var(--vermilion)}
.roles{display:grid;gap:8px}
.role{display:grid;grid-template-columns:80px 1fr;gap:8px;align-items:start}
.role .rname{font-family:var(--mono);font-size:.78em;color:var(--muted);padding-top:3px}
.swl{display:flex;flex-wrap:wrap;gap:4px 10px}
.swn{font-family:var(--mono);font-size:.74em;white-space:nowrap}
.swn i{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-2px;margin-right:4px;border:1px solid rgba(0,0,0,.08)}
.budgets{margin-top:10px;max-width:260px}
/* characters */
.enc{margin:12px 0 4px;padding-top:8px;border-top:1px dashed var(--line)}
.line{display:grid;grid-template-columns:64px 1fr;gap:8px;margin:5px 0;font-size:.92em}
.line .who{font-family:var(--mono);font-size:.8em;color:var(--muted);padding-top:3px;text-transform:uppercase;letter-spacing:.04em}
.line.alt .say{color:var(--muted)}
.choices{margin:4px 0 4px 72px;padding-left:18px;font-size:.9em;color:var(--ink-2)}
.choices li{margin:2px 0}
.hyp{font-family:var(--display);font-size:17px;line-height:1.35}
/* decisions */
.dlist{display:grid;gap:6px}
.drow{display:grid;grid-template-columns:96px 1fr auto;gap:12px;align-items:start;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;position:relative}
.drow.hide{display:none}
.drow .src{font-family:var(--mono);font-size:.74em;color:var(--muted);padding-top:4px;line-height:1.4}
.drow .txt{font-size:.93em}
.drow .cbtn{position:static}
.drow .right{display:flex;gap:6px;align-items:center}
.state{font:inherit;font-family:var(--mono);font-size:.74em;text-transform:uppercase;letter-spacing:.06em;padding:4px 10px;border-radius:999px;border:1px solid transparent;cursor:pointer;min-width:84px;text-align:center}
.state.open{background:#FBE3E2;color:#8D2B27;border-color:#EFB8B5}
.state.testing{background:#FCE7EF;color:#9C3A62;border-color:#F3B1C8}
.state.decided{background:#E4EDDA;color:#3E5B2A;border-color:#BFD3A9}
.state.parked{background:var(--paper-2);color:var(--muted);border-color:var(--line)}
.state.saving{opacity:.5}
@media (max-width: 960px){
  .grid2{grid-template-columns:1fr}
  .tiles{grid-template-columns:repeat(3,1fr)}
  .worldgrid{grid-template-columns:1fr}
  .detail{position:static}
}
@media (max-width: 760px){
  .app{grid-template-columns:1fr}
  .side{position:sticky;top:0;height:auto;flex-direction:row;flex-wrap:wrap;align-items:center;gap:4px;padding:10px 16px;border-right:0;border-bottom:1px solid var(--line);z-index:2}
  .brand{font-size:22px;margin:0 10px 0 0}
  .tag,.side .foot{display:none}
  .nav{padding:6px 9px}
  .nav .nc{display:none}
  main{padding:18px 16px 40px}
  .vh h1{font-size:26px}
  .goal-line{font-size:24px}
  .tiles{grid-template-columns:repeat(2,1fr)}
  .ladder summary{grid-template-columns:24px 60px 1fr auto}
  .ladder .rq{display:none}
  .rbody{padding-left:4px}
  .drow{grid-template-columns:1fr;gap:6px}
  .line{grid-template-columns:52px 1fr}
  .choices{margin-left:60px}
  .strip{grid-template-columns:repeat(8,1fr)}
}
"""

JS = r"""
const DATA = /*__DATA__*/{};
const views = ['design','world','kit','characters','decisions'];
const $ = (s, el=document) => el.querySelector(s);
const $$ = (s, el=document) => Array.from(el.querySelectorAll(s));
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

// ---- views
function show(v){
  if(!views.includes(v)) v = 'design';
  $$('.view').forEach(el => el.classList.toggle('on', el.id === v));
  $$('.nav').forEach(el => el.classList.toggle('on', el.dataset.view === v));
  document.title = 'Gated page · ' + v[0].toUpperCase() + v.slice(1);
}
window.addEventListener('hashchange', () => show(location.hash.slice(1).split('/')[0]));
show((location.hash.slice(1) || 'design').split('/')[0]);

// ---- world: detail panel
const detail = $('#detail');
let selected = null;
function fmt(v){ return (v === null || v === undefined) ? '' : (typeof v === 'number' ? (Math.round(v*100)/100) : v); }
function renderDetail(id){
  const it = id ? DATA.items[id] : null;
  $$('#map .hit.sel').forEach(el => el.classList.remove('sel'));
  if(!it){
    const s = DATA.scene;
    detail.innerHTML = `<div class="eyebrow">The tea house scene</div><h2>Click anything on the map</h2>
      <div class="kv"><b>placements</b><span>${s.placements} from ${s.pieces} pieces</span><b>floor cells</b><span>${s.floors}${s.reachable != null ? ', ' + s.reachable + ' reachable from the start' : ''}</span>
      <b>bounds</b><span class="mono">x ${s.bounds[0]+3.5}…${s.bounds[1]-3.5} · y ${s.bounds[2]+3.5}…${s.bounds[3]-3}</span><b>north</b><span>up</span></div>
      <p class="muted small">Numbered pink circles are where the three toys could stand once they leave grey ground. That is a proposal by Gated - cloud and is not in any file.</p>
      <button type="button" class="cbtn" data-comment>Comment on the map</button>`;
    wireComments(detail);
    return;
  }
  const el = $(`#map .hit[data-id="${id}"]`);
  if(el) el.classList.add('sel');
  let body = '';
  if(it.kind === 'piece'){
    const k = DATA.kit[it.piece] || {};
    const ti = k.thumb ? document.querySelector('#kit-' + CSS.escape(it.piece) + ' img') : null;
    const img = ti ? `<img src="${ti.src}" alt="">` : '';
    body = `${img}<div class="eyebrow">${esc(it.category)} · <span class="mono">${esc(it.piece)}</span></div><h2>${esc(it.title)}</h2>
      <div class="kv"><b>at</b><span class="mono">(${fmt(it.x)}, ${fmt(it.y)})${it.rot ? ' · rot ' + it.rot*90 + '°' : ''}</span>
      ${it.walkable !== undefined && it.walkable !== null ? `<b>walkable</b><span>${it.walkable ? 'yes' : 'no'}</span>` : ''}
      ${it.footprint ? `<b>footprint</b><span class="mono">${it.footprint[0]} × ${it.footprint[1]} m</span>` : ''}
      ${k.size ? `<b>size</b><span class="mono">${k.size.map(fmt).join(' × ')} m</span>` : ''}
      ${k.tris ? `<b>tris</b><span class="mono">${k.tris} / ${k.budget}</span>` : ''}
      ${k.placed ? `<b>in scene</b><span>×${k.placed}</span>` : ''}</div>
      <a class="link" href="#kit" data-kit="${esc(it.piece)}">see it in the kit →</a>`;
  } else if(it.kind === 'hotspot'){
    const t = DATA.toys[it.toy] || {};
    body = `<div class="eyebrow">toy ${it.n} · proposal, not in any file</div><h2>${esc(it.title)}</h2><p class="small">${esc(it.note)}</p>
      ${t.hypothesis ? `<p class="hyp small">${esc(t.hypothesis)}</p><p class="muted mono small">verb: ${esc(t.verb)} · dead by ${esc(t.dead_by)}</p>` : ''}
      <a class="link" href="#characters">read the character →</a>`;
  } else if(it.kind === 'unknown'){
    body = `<div class="eyebrow">unknown</div><h2>${esc(it.title)}</h2><p class="small">${esc(it.note)}</p><p class="muted small">Say what belongs here and it becomes a line in IDEAS.md, then a scene change when a rung asks for it.</p>`;
  } else if(it.kind === 'roof'){
    body = `<div class="eyebrow">roof · <span class="mono">${esc(it.piece)}</span></div><h2>${esc(it.title)}</h2><p class="small">${esc(it.note)}</p><div class="kv"><b>eaves</b><span>${it.count}</span><b>tris each</b><span class="mono">${it.tris}</span></div>`;
  } else {
    body = `<div class="eyebrow">${esc(it.kind)}</div><h2>${esc(it.title)}</h2><p class="small">${esc(it.note || '')}</p>`;
  }
  detail.innerHTML = body + `<button type="button" class="cbtn" data-comment>Comment on this</button>`;
  wireComments(detail);
  const kl = $('[data-kit]', detail);
  if(kl) kl.addEventListener('click', e => { e.preventDefault(); location.hash = 'kit'; const c = document.getElementById('kit-' + kl.dataset.kit); if(c){ c.scrollIntoView({block:'center'}); c.classList.add('flash'); setTimeout(() => c.classList.remove('flash'), 1600); } });
}
$$('#map .hit').forEach(el => {
  el.addEventListener('click', () => { selected = el.dataset.id; renderDetail(selected); });
  el.addEventListener('keydown', e => { if(e.key === 'Enter' || e.key === ' '){ e.preventDefault(); selected = el.dataset.id; renderDetail(selected); } });
});
renderDetail(null);

// ---- kit filter
$$('#catchips .chip').forEach(ch => ch.addEventListener('click', () => {
  $$('#catchips .chip').forEach(c => c.classList.toggle('on', c === ch));
  const cat = ch.dataset.cat;
  $$('#kgrid .kcard').forEach(c => c.classList.toggle('hide', cat !== 'all' && c.dataset.cat !== cat));
}));

// ---- decisions
const ORDER = ['open','testing','decided','parked'];
let overrides = {};   // id -> {state, at}
let db = null;
let stateFilter = 'all';
const dbstatus = $('#dbstatus');
function stateOf(d){ return (overrides[d.id] && overrides[d.id].state) || d.state; }
function renderDecisions(){
  const list = $('#dlist');
  list.innerHTML = DATA.decisions.map(d => {
    const st = stateOf(d);
    const changed = overrides[d.id] && overrides[d.id].state !== d.state;
    return `<div class="drow${stateFilter !== 'all' && st !== stateFilter ? ' hide' : ''}" data-id="${esc(d.id)}" data-comment-target>
      <div class="src">${esc(d.source)}<br>${esc(d.date)}${changed ? '<br>changed here' : ''}</div>
      <div class="txt">${esc(d.text)}</div>
      <div class="right"><button type="button" class="state ${st}" data-cycle="${esc(d.id)}" title="click to change">${st}</button><button type="button" class="cbtn" data-comment>Comment</button></div></div>`;
  }).join('');
  wireComments(list);
  $$('[data-cycle]', list).forEach(b => b.addEventListener('click', () => cycle(b.dataset.cycle, b)));
}
async function cycle(id, btn){
  const d = DATA.decisions.find(x => x.id === id);
  const next = ORDER[(ORDER.indexOf(stateOf(d)) + 1) % ORDER.length];
  if(!db){
    overrides[id] = {state: next, at: new Date().toISOString()};
    renderDecisions();
    if(dbstatus) dbstatus.textContent = 'not saved: this copy has no database';
    return;
  }
  btn.classList.add('saving');
  try{
    await db.doc('decisions/' + id).set({state: next, at: new Date().toISOString(), seed: d.state});
  }catch(e){
    btn.classList.remove('saving');
    if(dbstatus) dbstatus.textContent = 'could not save (' + (e && e.code || 'error') + ')';
  }
}
$$('#statechips .chip').forEach(ch => ch.addEventListener('click', () => {
  $$('#statechips .chip').forEach(c => c.classList.toggle('on', c === ch));
  stateFilter = ch.dataset.state; renderDecisions();
}));
renderDecisions();
(async () => {
  try{
    if(!(window.claude && typeof window.claude.use === 'function')){ if(dbstatus) dbstatus.textContent = 'not saved: this copy has no database'; return; }
    db = await window.claude.use('db');
    if(!db){ if(dbstatus) dbstatus.textContent = 'not saved: open it signed in on claude.ai'; return; }
    db.collection('decisions').onSnapshot(snap => {
      overrides = {};
      snap.docs.forEach(doc => { overrides[doc.id] = doc.data() || {}; });
      renderDecisions();
      const n = Object.keys(overrides).length;
      if(dbstatus) dbstatus.textContent = n ? `saved · ${n} changed from the files` : 'saved as you click';
    }, e => { if(dbstatus) dbstatus.textContent = 'database error: ' + (e && e.code || 'unknown'); });
  }catch(e){ if(dbstatus) dbstatus.textContent = 'database unavailable'; }
})();

// ---- comments
let comments = null;
function wireComments(root){
  $$('[data-comment]', root).forEach(b => {
    if(b.dataset.wired) return;
    b.dataset.wired = '1';
    b.addEventListener('click', async () => {
      if(!comments) return;
      const target = b.closest('[data-comment-target]') || b.parentElement;
      try{ await comments.openComposer({element: target}); }catch(e){}
    });
  });
}
wireComments(document);
document.body.classList.add('no-comments');
(async () => {
  try{
    if(!(window.claude && typeof window.claude.use === 'function')) return;
    comments = await window.claude.use('comments');
    document.body.classList.toggle('no-comments', !comments);
  }catch(e){}
})();
"""

PAGE = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gated page</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Shippori+Mincho:wght@500;700&family=Zen+Kaku+Gothic+New:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>{CSS}</style>
</head>
<body>
<div class="app">
  <nav class="side" aria-label="Sections">
    <div class="brand">gated<i></i></div>
    <div class="tag">the tea house game · rung {CURRENT_RUNG}, {esc(LADDER[CURRENT_RUNG-1]["name"])}</div>
    {_nav}
    <div class="foot">Built from <b>{esc(COMMIT_HASH)}</b>{" + uncommitted" if DIRTY else ""} on {esc(GENERATED_AT)} by <span class="mono">tools/gated_page.py</span>.<br>Comments on this page reach Gated - cloud.</div>
  </nav>
  <main>
    {DESIGN_HTML}
    {WORLD_HTML}
    {KIT_HTML}
    {CHARACTERS_HTML}
    {DECISIONS_HTML}
  </main>
</div>
<script>{JS.replace("/*__DATA__*/{}", json.dumps(DATA, ensure_ascii=False).replace("</", "<\\/"))}</script>
</body>
</html>
"""


def main(argv: list[str]) -> int:
    out = ROOT / "build" / "gated.html"
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(PAGE, encoding="utf-8")
    kb = out.stat().st_size / 1024
    print(f"wrote {out} ({kb:.0f} KB): {len(PLACEMENTS)} placements, {len(KIT_PIECES)} pieces, {sum(1 for t in THUMBS.values() if t)} thumbnails, {len(DECISIONS)} decisions, {len(ITEMS)} map items")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
