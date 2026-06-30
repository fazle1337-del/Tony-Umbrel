class_name PlayerStats
extends RefCounted
## Central, mutable player stats — the one place level-up upgrades land. The
## player rig and gun read derived values from here instead of constants, so a
## card just calls apply(). Pure logic (no nodes), unit-tested in
## tests/test_player_stats.gd.
##
## Flat stats (move_speed, max_health) are the player's own. The gun's base
## damage/cooldown still live as constants on the weapon side (main.gd today, a
## Weapon in step 2); this object only holds the *multipliers* an upgrade tweaks,
## applied via damage_for()/cooldown_for().

var move_speed := 4.0          # world units / second
var max_health := 100
var pickup_radius := 1.2       # XP gems within this distance are collected

# Multipliers accumulated by upgrades (1.0 = unchanged).
var damage_mult := 1.0
var fire_rate_mult := 1.0


## Shot damage after upgrades, given the weapon's base damage.
func damage_for(base: int) -> int:
	return roundi(base * damage_mult)


## Seconds between shots after upgrades (faster fire = shorter cooldown).
func cooldown_for(base: float) -> float:
	return base / fire_rate_mult


## Applies one upgrade effect. `value` is additive for flat stats, and added to
## the multiplier for *_mult stats (e.g. apply(&"damage_mult", 0.5) = +50%).
func apply(kind: StringName, value: float) -> void:
	match kind:
		&"move_speed": move_speed += value
		&"max_health": max_health += int(value)
		&"pickup_radius": pickup_radius += value
		&"damage_mult": damage_mult += value
		&"fire_rate_mult": fire_rate_mult += value
		_: push_warning("PlayerStats.apply: unknown kind %s" % kind)
