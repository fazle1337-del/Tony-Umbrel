class_name Combat
extends RefCounted
## Pure combat helpers — melee targeting math, no nodes — so the logic stays
## unit-testable (tests/test_combat.gd). The Enemy node holds HP and applies the
## damage; this module only decides *what a swing hits*. Distance reuses
## EnemyBrain.manhattan so the player's reach is measured the same way enemies
## measure their detect/attack ranges (grid cells, 4-directional).

const EnemyBrain := preload("res://scripts/enemy_brain.gd")


## Indices of `enemies` whose cell is within `reach` (Manhattan) of `player`,
## nearest first. A melee swing damages every returned target (a cleave); the
## near-first order lets a caller instead pick just the closest if it wants.
static func targets_in_range(player: Vector2i, enemies: Array[Vector2i], reach: int) -> Array[int]:
	var hits: Array[int] = []
	for i in enemies.size():
		if EnemyBrain.manhattan(player, enemies[i]) <= reach:
			hits.append(i)
	hits.sort_custom(func(a, b):
		return EnemyBrain.manhattan(player, enemies[a]) < EnemyBrain.manhattan(player, enemies[b]))
	return hits
