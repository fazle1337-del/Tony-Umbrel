extends SceneTree
## Headless test for the iso coordinate math. Run via tools/run_tests.sh, or:
##   godot --headless --path iso-game --script res://tests/test_iso_grid.gd
## Exits 0 on success, 1 on any failure (so CI / the harness can gate on it).

const IsoGrid := preload("res://scripts/iso_grid.gd")


func _initialize() -> void:
	var failures := 0

	# grid -> world -> grid must round-trip exactly across the play area.
	for x in range(-8, 9):
		for y in range(-8, 9):
			var cell := Vector2i(x, y)
			var back := IsoGrid.world_to_grid(IsoGrid.grid_to_world(cell))
			if back != cell:
				printerr("roundtrip failed: %s -> %s" % [cell, back])
				failures += 1

	# Arbitrary world points snap to the nearest cell center.
	failures += _expect_cell(Vector3(0.4, 0.0, 0.6), Vector2i(0, 1))
	failures += _expect_cell(Vector3(2.51, 5.0, -1.49), Vector2i(3, -1))
	failures += _expect_cell(Vector3(0.0, 0.0, 0.0), Vector2i(0, 0))

	if failures == 0:
		print("test_iso_grid: OK")
		quit(0)
	else:
		printerr("test_iso_grid: FAILED (%d)" % failures)
		quit(1)


func _expect_cell(world: Vector3, want: Vector2i) -> int:
	var got := IsoGrid.world_to_grid(world)
	if got == want:
		return 0
	printerr("world_to_grid(%s) = %s, want %s" % [world, got, want])
	return 1
