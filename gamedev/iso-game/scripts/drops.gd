class_name Drops
extends RefCounted
## Pure drop-table logic for enemy deaths — seeded by the caller, so drops are
## deterministic and unit-tested (tests/test_drops.gd). Every kill drops an XP
## gem (handled in main); on top of that a heart may drop with HEART_CHANCE,
## restoring HEART_HEAL HP when collected.

const HEART_CHANCE := 0.12   # probability a kill also drops a heart
const HEART_HEAL := 25       # HP a heart restores


## True if a kill should also drop a heart, given a roll in [0,1).
static func drops_heart(roll: float) -> bool:
	return roll < HEART_CHANCE
