class_name RunSummary
extends RefCounted
## Pure formatting for the end-of-run screen and the HUD timer — no nodes, so
## it's unit-tested (tests/test_run_summary.gd).


## Seconds as M:SS (e.g. 65.0 -> "1:05"); negatives clamp to "0:00".
static func format_time(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	return "%d:%02d" % [total / 60, total % 60]


## The multi-line summary shown on death.
static func summary(level: int, seconds: float, kills: int) -> String:
	return "Level reached: %d\nTime survived: %s\nEnemies slain: %d" % [
			level, format_time(seconds), kills]
