class_name Upgrades
extends RefCounted
## Pure pick-a-card upgrade pool + roller for the level-up screen — no nodes,
## seeded by the caller, so the cards offered are deterministic and unit-tested
## (tests/test_upgrades.gd).
##
## A card is data: {id, title, desc, kind, value} plus an optional "max" (cards
## without it stack forever; with it they retire once `owned[id]` reaches max) and
## an optional "weapon" name for gain_weapon cards. roll_choices() picks N
## distinct still-available cards; apply() mutates a PlayerStats / Weapon for the
## chosen card (stat kinds defer to PlayerStats.apply; weapon kinds are handled
## here).

const PlayerStats := preload("res://scripts/player_stats.gd")
const Weapon := preload("res://scripts/weapon.gd")

const MULTISHOT_SPREAD := 12.0   # default fan granted with the first extra pellet

const POOL: Array[Dictionary] = [
	{"id": &"damage",    "title": "Sharper Rounds", "desc": "+25% damage",       "kind": &"damage_mult",    "value": 0.25},
	{"id": &"firerate",  "title": "Rapid Fire",     "desc": "+20% fire rate",    "kind": &"fire_rate_mult", "value": 0.20},
	{"id": &"speed",     "title": "Fleet Footed",   "desc": "+0.6 move speed",   "kind": &"move_speed",     "value": 0.6},
	{"id": &"health",    "title": "Toughness",      "desc": "+25 max HP",        "kind": &"max_health",     "value": 25.0},
	{"id": &"pickup",    "title": "Magnetism",      "desc": "+0.6 pickup range", "kind": &"pickup_radius",  "value": 0.6},
	{"id": &"multishot", "title": "Multishot",      "desc": "+1 projectile",     "kind": &"multishot",      "value": 1.0, "max": 4},
	{"id": &"pierce",    "title": "Piercing Shots", "desc": "+1 pierce",         "kind": &"pierce",         "value": 1.0, "max": 3},
	{"id": &"shotgun",   "title": "Scattergun",     "desc": "Swap to a shotgun", "kind": &"gain_weapon",    "value": 0.0, "weapon": &"shotgun", "max": 1},
]


## N distinct still-available cards from `pool`, chosen with the caller's seeded
## `rng` (deterministic). Returns fewer than N only if the pool runs dry. `owned`
## maps card id -> times taken, used to retire maxed cards.
static func roll_choices(pool: Array, rng: RandomNumberGenerator, n: int, owned: Dictionary) -> Array:
	var avail: Array = []
	for card in pool:
		if _available(card, owned):
			avail.append(card)
	# Partial Fisher-Yates: shuffle the first `count` slots into place.
	var count := mini(n, avail.size())
	for i in count:
		var j := rng.randi_range(i, avail.size() - 1)
		var tmp = avail[i]
		avail[i] = avail[j]
		avail[j] = tmp
	return avail.slice(0, count)


## A card is offerable unless it is capped and already at its max.
static func _available(card: Dictionary, owned: Dictionary) -> bool:
	if not card.has("max"):
		return true
	return int(owned.get(card["id"], 0)) < int(card["max"])


## Applies the chosen card. Stat kinds defer to PlayerStats; weapon-shape kinds
## (multishot/pierce/gain_weapon) mutate the Weapon directly.
static func apply(stats: PlayerStats, weapon: Weapon, upgrade: Dictionary) -> void:
	match upgrade["kind"]:
		&"multishot":
			weapon.pellets += int(upgrade["value"])
			if weapon.spread_deg < 1.0:
				weapon.spread_deg = MULTISHOT_SPREAD   # so the new pellets visibly fan
		&"pierce":
			weapon.pierce += int(upgrade["value"])
		&"gain_weapon":
			_reshape_weapon(weapon, upgrade["weapon"])
		_:
			stats.apply(upgrade["kind"], upgrade["value"])


## Mutates `w` in place into a named weapon preset (the player holds one Weapon
## by reference, so we reshape rather than swap the object).
static func _reshape_weapon(w: Weapon, name: StringName) -> void:
	match name:
		&"shotgun":
			w.damage = 9
			w.cooldown = 0.6
			w.proj_speed = 30.0
			w.max_range = 9.0
			w.pellets = 5
			w.spread_deg = 30.0
			w.pierce = 0
		_:
			push_warning("Upgrades._reshape_weapon: unknown weapon %s" % name)
