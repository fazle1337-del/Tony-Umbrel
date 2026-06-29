extends SceneTree
## Headless tests for the laser ray-march. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_laser.gd

const GridWorld := preload("res://scripts/grid_world.gd")
const Laser := preload("res://scripts/laser.gd")

var _failures := 0
const NONE: Array[Vector2] = []


func _initialize() -> void:
	var world := GridWorld.new(6)

	# Clear field: beam reaches max_range (5 < arena edge ~6.5).
	_near(Laser.cast_distance(world, NONE, V(0, 0), V(1, 0), 5.0), 5.0, "open field -> max range")

	# Out of bounds: beam stops at the arena edge (cell |x|>6, i.e. x>=6.5).
	_near(Laser.cast_distance(world, NONE, V(0, 0), V(1, 0), 20.0), 6.5, "stops at arena edge")

	# Wall at cell (3,0): ray enters it at x>=2.5 (roundi rounds .5 up).
	world.set_blocked(Vector2i(3, 0))
	_near(Laser.cast_distance(world, NONE, V(0, 0), V(1, 0), 10.0), 2.5, "stops at wall")

	# Enemy disc at (2,0): hit ~ENEMY_RADIUS before its center, and nearer than
	# the wall behind it, so the enemy wins.
	var enemies: Array[Vector2] = [V(2, 0)]
	_near(Laser.cast_distance(world, enemies, V(0, 0), V(1, 0), 10.0),
			2.0 - Laser.ENEMY_RADIUS, "stops at enemy before the wall")

	# cast() reports which enemy: index 0 for the disc, -1 when only the wall is hit.
	_eq_int(Laser.cast(world, enemies, V(0, 0), V(1, 0), 10.0)["enemy"], 0,
			"cast reports the hit enemy index")
	_eq_int(Laser.cast(world, NONE, V(0, 0), V(1, 0), 10.0)["enemy"], -1,
			"cast reports -1 when the wall is hit")

	if _failures == 0:
		print("test_laser: OK")
		quit(0)
	else:
		printerr("test_laser: FAILED (%d)" % _failures)
		quit(1)


func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)


func _near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > Laser.STEP * 2.0:
		printerr("  FAIL: %s (got %.3f want ~%.3f)" % [msg, got, want])
		_failures += 1


func _eq_int(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1
