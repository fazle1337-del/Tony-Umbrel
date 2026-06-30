extends SceneTree
## Headless tests for Progression. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_progression.gd

const Progression := preload("res://scripts/progression.gd")

var _failures := 0


func _initialize() -> void:
	# Per-level span grows linearly (BASE_XP=5, XP_STEP=4).
	_eq(Progression.xp_span(1), 5, "span L1")
	_eq(Progression.xp_span(2), 9, "span L2")
	_eq(Progression.xp_span(3), 13, "span L3")

	# Cumulative XP to reach a level (level 1 = 0, then sum of prior spans).
	_eq(Progression.xp_for_level(1), 0, "cumulative L1")
	_eq(Progression.xp_for_level(2), 5, "cumulative L2")
	_eq(Progression.xp_for_level(3), 14, "cumulative L3")     # 5 + 9
	_eq(Progression.xp_for_level(4), 27, "cumulative L4")     # 5 + 9 + 13

	# Level boundaries: just below / at / above a threshold.
	_eq(Progression.level_for_total(0), 1, "total 0 -> L1")
	_eq(Progression.level_for_total(4), 1, "total 4 -> L1 (below)")
	_eq(Progression.level_for_total(5), 2, "total 5 -> L2 (at)")
	_eq(Progression.level_for_total(13), 2, "total 13 -> L2 (below next)")
	_eq(Progression.level_for_total(14), 3, "total 14 -> L3 (at)")

	# XP into the current level (the bar-fill numerator).
	_eq(Progression.xp_into_level(0), 0, "into at 0")
	_eq(Progression.xp_into_level(5), 0, "into at a level boundary")
	_eq(Progression.xp_into_level(7), 2, "into L2 by 2")

	# Invariant: 0 <= xp_into_level < xp_span(level) for any total.
	for total in [1, 5, 10, 14, 30, 100, 500]:
		var lv := Progression.level_for_total(total)
		var into := Progression.xp_into_level(total)
		if into < 0 or into >= Progression.xp_span(lv):
			printerr("  FAIL: fill invariant at total=%d (lv=%d into=%d span=%d)"
					% [total, lv, into, Progression.xp_span(lv)])
			_failures += 1

	if _failures == 0:
		print("test_progression: OK")
		quit(0)
	else:
		printerr("test_progression: FAILED (%d)" % _failures)
		quit(1)


func _eq(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1
