extends SceneTree
## Headless tests for PlayerStats. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_player_stats.gd

const PlayerStats := preload("res://scripts/player_stats.gd")

var _failures := 0


func _initialize() -> void:
	var s := PlayerStats.new()

	# Defaults: multipliers are identity, flat stats are the base values.
	_eq_i(s.damage_for(15), 15, "base damage unchanged")
	_near(s.cooldown_for(0.4), 0.4, "base cooldown unchanged")
	_near(s.move_speed, 4.0, "base move speed")
	_eq_i(s.max_health, 100, "base max health")

	# damage_mult is additive: +50% twice -> x2.0.
	s.apply(&"damage_mult", 0.5)
	s.apply(&"damage_mult", 0.5)
	_eq_i(s.damage_for(15), 30, "damage_mult stacks to x2")

	# fire_rate_mult shortens cooldown: x2 fire rate -> half cooldown.
	s.apply(&"fire_rate_mult", 1.0)
	_near(s.cooldown_for(0.4), 0.2, "fire_rate halves cooldown")

	# Flat stats add.
	s.apply(&"move_speed", 1.5)
	_near(s.move_speed, 5.5, "move_speed adds")
	s.apply(&"max_health", 50)
	_eq_i(s.max_health, 150, "max_health adds")

	if _failures == 0:
		print("test_player_stats: OK")
		quit(0)
	else:
		printerr("test_player_stats: FAILED (%d)" % _failures)
		quit(1)


func _eq_i(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1


func _near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > 0.0001:
		printerr("  FAIL: %s (got %.4f want %.4f)" % [msg, got, want])
		_failures += 1
