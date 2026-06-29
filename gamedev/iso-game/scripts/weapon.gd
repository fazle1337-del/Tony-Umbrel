class_name Weapon
extends RefCounted
## A gun as data, so weapons are swappable and upgrade cards can tweak them. The
## player's PlayerStats multipliers scale `damage`/`cooldown` at fire time; this
## holds the per-weapon base values and shot shape. fire_pattern() is pure and
## unit-tested (tests/test_weapon.gd).

var damage: int               # base HP per pellet (before PlayerStats.damage_mult)
var cooldown: float           # base seconds between shots (before fire_rate_mult)
var proj_speed: float         # bullet travel speed (world units/s)
var max_range: float          # max shot / laser-sight distance
var pellets: int              # bullets per shot (1 = single)
var spread_deg: float         # total fan angle the pellets are spaced across
var pierce: int               # extra enemies a pellet passes through (0 = stops at first)


# Defaults are the starting pistol (today's hardcoded values), so Weapon.new()
# with no args is the pistol and behavior is unchanged.
func _init(dmg := 15, cd := 0.4, speed := 36.4, rng := 14.0,
		pellet_count := 1, spread := 0.0, pierce_count := 0) -> void:
	damage = dmg
	cooldown = cd
	proj_speed = speed
	max_range = rng
	pellets = pellet_count
	spread_deg = spread
	pierce = pierce_count


## Aim directions for one shot: `pellets` unit vectors fanned symmetrically across
## `spread_deg`, centered on `aim`. A single pellet (or zero spread) fires straight.
func fire_pattern(aim: Vector2) -> Array[Vector2]:
	if pellets <= 1:
		return [aim]
	var dirs: Array[Vector2] = []
	var step := spread_deg / float(pellets - 1)
	for i in pellets:
		var angle := -spread_deg * 0.5 + step * i
		dirs.append(aim.rotated(deg_to_rad(angle)))
	return dirs
