"""Every module in tests/broken must FAIL, and on the check it names.

    python -m tests.run_broken
"""
import importlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from sakura_kit.check import check  # noqa: E402

bad = 0
for f in sorted(os.listdir(os.path.join(ROOT, "tests", "broken"))):
    if not f.endswith(".py") or f.startswith("_"):
        continue
    name = f[:-3]
    expect = importlib.import_module(f"tests.broken.{name}").MUST_FAIL
    rep = check(f"tests.broken.{name}", render=False)
    failed = {c["check"] for c in rep["checks"] if not c["ok"] and c.get("level", "error") == "error"}
    ok = (not rep["ok"]) and expect in failed
    print(f"{'ok  ' if ok else 'BAD '} {name}: expected {expect}, failed {sorted(failed)}")
    bad += not ok
print(f"\n{bad} fixture(s) did not fail as expected")
sys.exit(1 if bad else 0)
