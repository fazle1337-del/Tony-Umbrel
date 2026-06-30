extends SceneTree
## Headless tests for Drops. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_drops.gd

const Drops := preload("res://scripts/drops.gd")

var _failures := 0


func _initialize() -> void:
	# A heart drops for rolls strictly below HEART_CHANCE.
	_t(Drops.drops_heart(0.0), true, "roll 0 -> heart")
	_t(Drops.drops_heart(Drops.HEART_CHANCE - 0.001), true, "just below chance -> heart")
	_t(Drops.drops_heart(Drops.HEART_CHANCE), false, "at chance -> no heart")
	_t(Drops.drops_heart(0.99), false, "high roll -> no heart")

	if _failures == 0:
		print("test_drops: OK")
		quit(0)
	else:
		printerr("test_drops: FAILED (%d)" % _failures)
		quit(1)


func _t(got: bool, want: bool, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %s want %s)" % [msg, got, want])
		_failures += 1
