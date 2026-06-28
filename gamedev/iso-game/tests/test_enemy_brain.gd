extends SceneTree
## Headless tests for the enemy FSM transitions. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_enemy_brain.gd

const EnemyBrain := preload("res://scripts/enemy_brain.gd")
const S := EnemyBrain.State

var _failures := 0
var _home := Vector2i(0, 0)


func _initialize() -> void:
	var b := EnemyBrain.new(5, 8, 1)  # detect 5, lose 8, attack 1

	# PATROL: chase only when reachable AND within detect range
	_eq(b.next_state(S.PATROL, V(0, 0), V(3, 0), _home, true), S.CHASE, "patrol->chase in range")
	_eq(b.next_state(S.PATROL, V(0, 0), V(6, 0), _home, true), S.PATROL, "patrol stays out of range")
	_eq(b.next_state(S.PATROL, V(0, 0), V(2, 0), _home, false), S.PATROL, "patrol stays if unreachable")

	# CHASE: attack when adjacent, give up (RETURN) past lose range or if unreachable
	_eq(b.next_state(S.CHASE, V(0, 0), V(1, 0), _home, true), S.ATTACK, "chase->attack adjacent")
	_eq(b.next_state(S.CHASE, V(0, 0), V(4, 0), _home, true), S.CHASE, "chase persists mid-range")
	_eq(b.next_state(S.CHASE, V(0, 0), V(9, 0), _home, true), S.RETURN, "chase->return past lose")
	_eq(b.next_state(S.CHASE, V(0, 0), V(2, 0), _home, false), S.RETURN, "chase->return if unreachable")

	# hysteresis: between detect (5) and lose (8) a chase keeps going
	_eq(b.next_state(S.CHASE, V(0, 0), V(7, 0), _home, true), S.CHASE, "hysteresis keeps chasing")

	# ATTACK: back to chase when the player steps out of attack range
	_eq(b.next_state(S.ATTACK, V(0, 0), V(1, 0), _home, true), S.ATTACK, "attack holds adjacent")
	_eq(b.next_state(S.ATTACK, V(0, 0), V(3, 0), _home, true), S.CHASE, "attack->chase when player flees")

	# RETURN: re-chase if re-detected, else patrol once home is reached
	_eq(b.next_state(S.RETURN, V(5, 0), V(5, 1), _home, true), S.CHASE, "return->chase re-detected")
	_eq(b.next_state(S.RETURN, V(0, 0), V(9, 9), _home, true), S.PATROL, "return->patrol at home")
	_eq(b.next_state(S.RETURN, V(3, 0), V(9, 9), _home, true), S.RETURN, "return keeps going if not home")

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
