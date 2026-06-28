extends SceneTree
## Headless tests for the enemy FSM transitions. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_enemy_brain.gd

const EnemyBrain := preload("res://scripts/enemy_brain.gd")
const S := EnemyBrain.State

var _failures := 0
var _home := Vector2i(0, 0)


func _initialize() -> void:
	var b := EnemyBrain.new(5, 8, 1)  # detect 5, lose 8, attack 1

	# next_state(state, enemy, player, home, can_see, reachable)
	# PATROL: chase only when it can SEE the player AND is within detect range
	_eq(b.next_state(S.PATROL, V(0, 0), V(3, 0), _home, true, true), S.CHASE, "patrol->chase in range + LOS")
	_eq(b.next_state(S.PATROL, V(0, 0), V(6, 0), _home, true, true), S.PATROL, "patrol stays out of range")
	_eq(b.next_state(S.PATROL, V(0, 0), V(2, 0), _home, false, true), S.PATROL, "patrol stays without LOS")

	# CHASE: attack when adjacent, give up (RETURN) past lose range or if unreachable
	_eq(b.next_state(S.CHASE, V(0, 0), V(1, 0), _home, true, true), S.ATTACK, "chase->attack adjacent")
	_eq(b.next_state(S.CHASE, V(0, 0), V(4, 0), _home, true, true), S.CHASE, "chase persists mid-range")
	_eq(b.next_state(S.CHASE, V(0, 0), V(9, 0), _home, true, true), S.RETURN, "chase->return past lose")
	_eq(b.next_state(S.CHASE, V(0, 0), V(2, 0), _home, true, false), S.RETURN, "chase->return if unreachable")

	# chase keeps going without LOS (pursues around corners) until distance/unreachable
	_eq(b.next_state(S.CHASE, V(0, 0), V(7, 0), _home, false, true), S.CHASE, "chase persists without LOS")

	# ATTACK: back to chase when the player steps out of attack range
	_eq(b.next_state(S.ATTACK, V(0, 0), V(1, 0), _home, true, true), S.ATTACK, "attack holds adjacent")
	_eq(b.next_state(S.ATTACK, V(0, 0), V(3, 0), _home, true, true), S.CHASE, "attack->chase when player flees")

	# RETURN: re-chase if re-seen, else patrol once home is reached
	_eq(b.next_state(S.RETURN, V(5, 0), V(5, 1), _home, true, true), S.CHASE, "return->chase re-detected")
	_eq(b.next_state(S.RETURN, V(0, 0), V(9, 9), _home, false, true), S.PATROL, "return->patrol at home")
	_eq(b.next_state(S.RETURN, V(3, 0), V(9, 9), _home, false, true), S.RETURN, "return keeps going if not home")

	if _failures == 0:
		print("test_enemy_brain: OK")
		quit(0)
	else:
		printerr("test_enemy_brain: FAILED (%d)" % _failures)
		quit(1)


func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


func _eq(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1
