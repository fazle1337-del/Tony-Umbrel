#!/usr/bin/env bash
# Run every headless test in tests/. Exits non-zero if any test fails.
# Usage: tools/run_tests.sh        (GODOT env var overrides the binary)
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

shopt -s nullglob
tests=("$PROJECT_DIR"/tests/test_*.gd)
if [ ${#tests[@]} -eq 0 ]; then
	echo "no tests found in $PROJECT_DIR/tests/"
	exit 1
fi

failed=0
for test in "${tests[@]}"; do
	name="$(basename "$test")"
	echo "== running $name"
	"$GODOT" --headless --path "$PROJECT_DIR" --script "res://tests/$name" \
		2>&1 | grep -vE "^(Godot Engine|--|TextServer)" || true
	code=${PIPESTATUS[0]}
	if [ "$code" -ne 0 ]; then
		echo "   FAILED ($name, exit $code)"
		failed=1
	fi
done

if [ "$failed" -eq 0 ]; then
	echo "ALL TESTS PASSED"
else
	echo "TESTS FAILED"
fi
exit "$failed"
