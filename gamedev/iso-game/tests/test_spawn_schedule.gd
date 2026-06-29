extends SceneTree
## Headless tests for the spawn difficulty curve. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_spawn_schedule.gd

const SpawnSchedule := preload("res://scripts/spawn_schedule.gd")

var _failures := 0


func _initialize() -> void:
	# Interval starts high, shrinks with time, and clamps to the floor.
	_near(SpawnSchedule.spawn_interval(0.0), SpawnSchedule.START_INTERVAL, "interval starts high")
	_check(SpawnSchedule.spawn_interval(50.0) < SpawnSchedule.spawn_interval(0.0), "interval shrinks")
	_near(SpawnSchedule.spawn_interval(100000.0), SpawnSchedule.MIN_INTERVAL, "interval floors")

	# Early on it's all grunts regardless of the roll.
	_eq(SpawnSchedule.pick_type(0.0, 0.0), &"grunt", "t=0 low roll -> grunt")
	_eq(SpawnSchedule.pick_type(0.0, 0.99), &"grunt", "t=0 high roll -> grunt")

	# Late game the toughest types appear; weights have shifted off pure grunt.
	_eq(SpawnSchedule.pick_type(300.0, 0.99), &"tank", "late high roll -> tank")
	_eq(SpawnSchedule.pick_type(300.0, 0.0), &"grunt", "late low roll -> still grunt")
	_check(SpawnSchedule.pick_type(120.0, 0.5) != &"grunt", "mid game mid roll has shifted")

	# Deterministic: same (t, roll) -> same type.
	_eq(SpawnSchedule.pick_type(120.0, 0.5), SpawnSchedule.pick_type(120.0, 0.5), "deterministic")

	if _failures == 0:
		print("test_spawn_schedule: OK")
		quit(0)
	else:
		printerr("test_spawn_schedule: FAILED (%d)" % _failures)
		quit(1)


func _eq(got: StringName, want: StringName, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %s want %s)" % [msg, got, want])
		_failures += 1


func _near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > 0.0001:
		printerr("  FAIL: %s (got %.4f want %.4f)" % [msg, got, want])
		_failures += 1


func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("  FAIL: %s" % msg)
		_failures += 1
