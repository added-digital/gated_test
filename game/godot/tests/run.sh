#!/usr/bin/env bash
# Imports the project, then runs the scripted walk headless (no GPU needed)
# and writes everything to tests/last_run.log. Exit 0 only if every check
# passed. Usage: tests/run.sh   (GODOT=/path/to/Godot_v4.6.1-stable tests/run.sh
# to pick another binary; the default is the 4.6.1 binary in the scratchpad.)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$HERE")"
GODOT="${GODOT:-/tmp/claude-0/-home-user-gated-test/5dad3fb4-c617-5098-9f35-819130e12508/scratchpad/godot46/Godot_v4.6.1-stable_linux.x86_64}"
LOG="$HERE/last_run.log"

{
	echo "== $(date -u +%Y-%m-%dT%H:%M:%SZ)  $("$GODOT" --headless --version 2>&1 | tail -n 1)"
	echo "== import"
} > "$LOG"
"$GODOT" --headless --path "$PROJECT" --import >> "$LOG" 2>&1
echo "== walk_test (exit code of the import: $?)" >> "$LOG"
# --fixed-fps 60: one physics step per frame, as fast as the CPU allows,
# deterministic. --quit-after is only a backstop; the test quits itself.
"$GODOT" --headless --fixed-fps 60 --path "$PROJECT" res://tests/walk_test.tscn --quit-after 3000 >> "$LOG" 2>&1
code=$?
echo "== walk_test exit code: $code" >> "$LOG"
cat "$LOG"
if [ "$code" -eq 0 ] && grep -q "^RESULT: 0 failure" "$LOG"; then
	echo "ALL PASS"
	exit 0
fi
echo "FAILED (exit $code; see $LOG)"
exit 1
