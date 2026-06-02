#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# ci.sh — the self-verification gate for NotepadL++ (ARCHITECTURE §5 / kickoff).
# Builds the app and the test runner headless, runs the tests, and fails (non-zero exit)
# on any build error or test failure. Never advance a milestone on a red ci.sh.
#
#   ./ci.sh            build app + tests, run tests
#   ./ci.sh --app-run  also smoke-launch the GUI under xvfb (no crash check)
#
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

LZ="${LAZARUS_DIR_LOCAL:-$ROOT/deps/lazarus-im}"   # project-local Lazarus (WITH_GTK2_IM-capable)
WS="gtk2"
LB=(lazbuild --lazarusdir="$LZ" --ws="$WS")

if [ ! -d "$LZ/lcl" ]; then
  echo "ERROR: project-local Lazarus not found at $LZ. Run scripts/setup-deps.sh first." >&2
  exit 2
fi

fail() { echo "CI FAILED: $1" >&2; exit 1; }

echo "== [1/3] Build app (NotepadLPP.lpi, $WS) =="
"${LB[@]}" NotepadLPP.lpi || fail "app build"

echo "== [2/3] Build tests (test/TestRunner.lpi) =="
"${LB[@]}" test/TestRunner.lpi || fail "test build"

echo "== [3/3] Run tests (headless) =="
./test/TestRunner --all --format=plain || fail "tests"

if [ "${1:-}" = "--app-run" ]; then
  echo "== [extra] GUI smoke launch under xvfb =="
  timeout 12 xvfb-run -a bash -c './notepadlpp & p=$!; sleep 5; kill -0 $p 2>/dev/null && { echo "app launched, no crash"; kill -TERM $p; } || { echo "app crashed"; exit 1; }' \
    || fail "gui smoke launch"
fi

echo "CI PASSED"
