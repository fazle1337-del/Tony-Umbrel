extends SceneTree
## Headless tests for the melee targeting math. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_combat.gd

const Combat := preload("res://scripts/combat.gd")

var _failures := 0


func _initialize() -> void:
	# player at origin; enemies at increasing Manhattan distance: 1, 2, 3, 0
	var enemies: Array[Vector2i] = [V(1, 0), V(0, 2), V(3, 0), V(0, 0)]

	# reach 0: only the enemy sharing the player's cell (index 3)
	_eq(Combat.targets_in_range(V(0, 0), enemies, 0), [3], "reach 0 hits only same cell")

	# reach 1: same-cell (d0) then adjacent (d1), nearest first
	_eq(Combat.targets_in_range(V(0, 0), enemies, 1), [3, 0], "reach 1 nearest-first")

	# reach 2: d0, d1, d2 — excludes the d3 enemy
	_eq(Combat.targets_in_range(V(0, 0), enemies, 2), [3, 0, 1], "reach 2 excludes out-of-range")

	# nothing in range -> empty
	_eq(Combat.targets_in_range(V(9, 9), enemies, 1), [], "no targets in range")

	# empty enemy list -> empty (no crash)
	_eq(Combat.targets_in_range(V(0, 0), [] as Array[Vector2i], 5), [], "empty list")

	if _failures == 0:
		print("test_combat: OK")
		quit(0)
	else:
		printerr("test_combat: FAILED (%d)" % _failures)
		quit(1)


func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


func _eq(got: Array, want: Array, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %s want %s)" % [msg, str(got), str(want)])
		_failures += 1
