class_name Progression
extends RefCounted
## Pure XP/level curve for the survivors-like — static, seedless, unit-tested
## (tests/test_progression.gd). Levels start at 1; the per-level span grows
## linearly so early levels come fast and later ones take longer. main keeps a
## running XP total and reads level_for_total() / xp_into_level() / xp_span() to
## drive the HUD bar and detect level-ups.

const BASE_XP := 5      # XP to go from level 1 -> 2
const XP_STEP := 4      # extra XP each subsequent level needs


## XP needed *within* `level` to reach the next one (the bar's full width).
static func xp_span(level: int) -> int:
	return BASE_XP + (maxi(level, 1) - 1) * XP_STEP


## Cumulative XP required to have reached `level` (level 1 = 0).
static func xp_for_level(level: int) -> int:
	var total := 0
	for k in range(1, maxi(level, 1)):
		total += xp_span(k)
	return total


## The level for a cumulative XP `total` (always >= 1).
static func level_for_total(total: int) -> int:
	var level := 1
	while total >= xp_for_level(level + 1):
		level += 1
	return level


## XP accumulated into the current level (the bar-fill numerator).
static func xp_into_level(total: int) -> int:
	return total - xp_for_level(level_for_total(total))
