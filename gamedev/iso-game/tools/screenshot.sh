#!/usr/bin/env bash
# Render one deterministic frame of the game to res://screenshots/latest.png.
# Needs a display (rendering can't happen under --headless); defaults to :1.
# Usage: tools/screenshot.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DISPLAY="${DISPLAY:-:1}"

# timeout is a backstop: a script/parse error means the scene never reaches the
# self-quit in _capture_after_settle, so without this the run would hang.
timeout 30 "$GODOT" --path "$PROJECT_DIR" -- --screenshot \
	2>&1 | grep -vE "^(Godot Engine|--|TextServer)" || true

shot="$PROJECT_DIR/screenshots/latest.png"
if [ -f "$shot" ]; then
	echo "screenshot: $shot"
else
	echo "screenshot NOT created" >&2
	exit 1
fi
