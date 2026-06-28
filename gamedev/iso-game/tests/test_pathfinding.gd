extends SceneTree
## Headless tests for GridWorld A* pathfinding. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_pathfinding.gd

const GridWorld := preload("res://scripts/grid_world.gd")

var _failures := 0


func _initialize() -> void:
	_test_clear_path_is_shortest()
	_test_path_steps_are_adjacent()
	_test_routes_around_wall()
	_test_never_enters_blocked_cell()
	_test_unreachable_returns_empty()
	_test_blocked_goal_returns_empty()
	_test_same_cell()
	_test_line_of_sight()

	if _failures == 0:
		print("test_pathfinding: OK")
		quit(0)
	else:
		printerr("test_pathfinding: FAILED (%d)" % _failures)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("  FAIL: ", msg)
		_failures += 1


func _test_clear_path_is_shortest() -> void:
	var w := GridWorld.new(6)
	var path := w.find_path(Vector2i(0, 0), Vector2i(3, 0))
	# 3 steps east => 4 cells, no detours on an empty grid.
	_check(path.size() == 4, "clear path length: got %d want 4" % path.size())
	_check(path[0] == Vector2i(0, 0), "path starts at start")
	_check(path[-1] == Vector2i(3, 0), "path ends at goal")


func _test_path_steps_are_adjacent() -> void:
	var w := GridWorld.new(6)
	var path := w.find_path(Vector2i(-4, -2), Vector2i(2, 3))
	for i in range(1, path.size()):
		var step := path[i] - path[i - 1]
		_check(abs(step.x) + abs(step.y) == 1,
				"non-adjacent step at %d: %s" % [i, step])


func _test_routes_around_wall() -> void:
	var w := GridWorld.new(6)
	# Wall at x=1 spanning y=-4..3, leaving a gap near the top to route through.
	for y in range(-4, 4):
		w.set_blocked(Vector2i(1, y))
	var path := w.find_path(Vector2i(-3, 0), Vector2i(3, 0))
	_check(path.size() > 0, "wall route should exist")
	_check(path.size() > 7, "route should detour (got %d)" % path.size())
	_check(path[-1] == Vector2i(3, 0), "wall route reaches goal")


func _test_never_enters_blocked_cell() -> void:
	var w := GridWorld.new(6)
	for y in range(-4, 4):
		w.set_blocked(Vector2i(1, y))
	var path := w.find_path(Vector2i(-3, 0), Vector2i(3, 0))
	for cell in path:
		_check(not w.is_blocked(cell), "path entered blocked cell %s" % cell)


func _test_unreachable_returns_empty() -> void:
	var w := GridWorld.new(6)
	# Fully wall off the goal at (0,0).
	for dir in GridWorld.DIRECTIONS:
		w.set_blocked(dir)
	var path := w.find_path(Vector2i(3, 3), Vector2i(0, 0))
	_check(path.is_empty(), "surrounded goal should be unreachable")


func _test_blocked_goal_returns_empty() -> void:
	var w := GridWorld.new(6)
	w.set_blocked(Vector2i(2, 2))
	_check(w.find_path(Vector2i(0, 0), Vector2i(2, 2)).is_empty(),
			"blocked goal should yield no path")


func _test_same_cell() -> void:
	var w := GridWorld.new(6)
	var path := w.find_path(Vector2i(1, 1), Vector2i(1, 1))
	_check(path == [Vector2i(1, 1)], "start==goal should be single cell")


func _test_line_of_sight() -> void:
	var w := GridWorld.new(6)
	_check(w.has_line_of_sight(Vector2i(-3, 0), Vector2i(3, 0)), "clear LOS on empty grid")
	w.set_blocked(Vector2i(0, 0))
	_check(not w.has_line_of_sight(Vector2i(-3, 0), Vector2i(3, 0)), "wall on the line breaks LOS")
	_check(w.has_line_of_sight(Vector2i(-3, 2), Vector2i(3, 2)), "parallel row still has LOS")
	_check(w.has_line_of_sight(Vector2i(0, 0), Vector2i(3, 0)), "endpoint being blocked is ignored")
