class_name EnemyBrain
extends RefCounted
## Pure finite-state machine for enemy AI — no nodes, no rendering — so the
## decision logic is unit-testable (tests/test_enemy_brain.gd). The concept
## follows the kidscancode "changing behaviors" recipe (enum states + a single
## transition function), adapted to our grid: the detect/attack "radii" become
## Manhattan distance, plus an A*-reachability flag so enemies only commit to a
## chase when a path to the player actually exists. The Enemy node (enemy.gd)
## executes whatever state this returns.

enum State { PATROL, CHASE, ATTACK, RETURN }

var detect_range: int   # start chasing when the player is within this many cells
var lose_range: int     # give up once the player is beyond this (hysteresis)
var attack_range: int   # attack when within this many cells (1 = adjacent)


func _init(detect := 5, lose := 8, attack := 1) -> void:
	detect_range = detect
	lose_range = lose
	attack_range = attack


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Pure transition. `reachable` = an A* path from enemy to player exists.
func next_state(state: State, enemy: Vector2i, player: Vector2i, home: Vector2i,
		reachable: bool) -> State:
	var d := manhattan(enemy, player)
	match state:
		State.PATROL:
			return State.CHASE if reachable and d <= detect_range else State.PATROL
		State.CHASE:
			if not reachable or d > lose_range:
				return State.RETURN
			if d <= attack_range:
				return State.ATTACK
			return State.CHASE
		State.ATTACK:
			return State.ATTACK if d <= attack_range else State.CHASE
		State.RETURN:
			if reachable and d <= detect_range:
				return State.CHASE
			return State.PATROL if enemy == home else State.RETURN
	return state
