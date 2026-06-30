extends SceneTree
## Headless tests for RunSummary. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_run_summary.gd

const RunSummary := preload("res://scripts/run_summary.gd")

var _failures := 0


func _initialize() -> void:
	_eq(RunSummary.format_time(0.0), "0:00", "zero")
	_eq(RunSummary.format_time(5.0), "0:05", "single-digit seconds pad")
	_eq(RunSummary.format_time(65.0), "1:05", "minutes + seconds")
	_eq(RunSummary.format_time(600.0), "10:00", "ten minutes")
	_eq(RunSummary.format_time(-3.0), "0:00", "negative clamps")

	var s := RunSummary.summary(4, 95.0, 23)
	_contains(s, "Level reached: 4", "summary has level")
	_contains(s, "1:35", "summary has formatted time")
	_contains(s, "Enemies slain: 23", "summary has kills")

	if _failures == 0:
		print("test_run_summary: OK")
		quit(0)
	else:
		printerr("test_run_summary: FAILED (%d)" % _failures)
		quit(1)


func _eq(got: String, want: String, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %s want %s)" % [msg, got, want])
		_failures += 1


func _contains(haystack: String, needle: String, msg: String) -> void:
	if not haystack.contains(needle):
		printerr("  FAIL: %s (%s not in %s)" % [msg, needle, haystack])
		_failures += 1
