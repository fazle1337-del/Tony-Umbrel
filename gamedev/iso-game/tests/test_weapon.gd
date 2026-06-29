extends SceneTree
## Headless tests for Weapon.fire_pattern and Laser.cast_pierce. Exits 0/1.
##   godot --headless --path iso-game --script res://tests/test_weapon.gd

const Weapon := preload("res://scripts/weapon.gd")
const GridWorld := preload("res://scripts/grid_world.gd")
const Laser := preload("res://scripts/laser.gd")

var _failures := 0


func _initialize() -> void:
	var aim := Vector2(1, 0)

	# Pistol (default Weapon): a single straight pellet (parity with the old gun).
	var pistol := Weapon.new()
	var p := pistol.fire_pattern(aim)
	_eq_i(p.size(), 1, "pistol fires 1 pellet")
	_near(p[0].angle(), 0.0, "pistol pellet goes straight")

	# 3 pellets across 30deg: symmetric fan, middle straight, outers at +/-15deg.
	var shotgun := Weapon.new(10, 0.6, 30.0, 12.0, 3, 30.0, 0)
	var f := shotgun.fire_pattern(aim)
	_eq_i(f.size(), 3, "shotgun fires 3 pellets")
	_near(rad_to_deg(f[0].angle()), -15.0, "pellet 0 at -15deg")
	_near(rad_to_deg(f[1].angle()), 0.0, "pellet 1 straight")
	_near(rad_to_deg(f[2].angle()), 15.0, "pellet 2 at +15deg")

	# Pierce: two enemies in a line with a wall behind. max_hits 3 -> both hit,
	# bullet stops at the wall (cell 5 entered at x>=4.5).
	var world := GridWorld.new(6)
	world.set_blocked(Vector2i(5, 0))
	var enemies: Array[Vector2] = [Vector2(2, 0), Vector2(4, 0)]
	var hit := Laser.cast_pierce(world, enemies, Vector2(0, 0), aim, 10.0, 3)
	_eq_arr(hit["enemies"], [0, 1], "pierce hits both enemies in order")
	_near(hit["distance"], 4.5, "pierce stops at the wall")

	# max_hits 1: stops at the first enemy (~ENEMY_RADIUS before its center).
	var hit1 := Laser.cast_pierce(world, enemies, Vector2(0, 0), aim, 10.0, 1)
	_eq_arr(hit1["enemies"], [0], "max_hits 1 stops after one enemy")
	_near(hit1["distance"], 2.0 - Laser.ENEMY_RADIUS, "stops at the first enemy")

	if _failures == 0:
		print("test_weapon: OK")
		quit(0)
	else:
		printerr("test_weapon: FAILED (%d)" % _failures)
		quit(1)


func _eq_i(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1


func _eq_arr(got: Array, want: Array, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %s want %s)" % [msg, str(got), str(want)])
		_failures += 1


func _near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > Laser.STEP * 2.0:
		printerr("  FAIL: %s (got %.3f want ~%.3f)" % [msg, got, want])
		_failures += 1
