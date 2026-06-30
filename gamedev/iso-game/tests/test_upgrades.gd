extends SceneTree
## Headless tests for Upgrades. Exits 0 on success, 1 on failure.
##   godot --headless --path iso-game --script res://tests/test_upgrades.gd

const Upgrades := preload("res://scripts/upgrades.gd")
const PlayerStats := preload("res://scripts/player_stats.gd")
const Weapon := preload("res://scripts/weapon.gd")

var _failures := 0


func _initialize() -> void:
	_test_roll()
	_test_apply()

	if _failures == 0:
		print("test_upgrades: OK")
		quit(0)
	else:
		printerr("test_upgrades: FAILED (%d)" % _failures)
		quit(1)


func _test_roll() -> void:
	# A fresh pool yields 3 distinct cards.
	var c := Upgrades.roll_choices(Upgrades.POOL, _rng(7), 3, {})
	_eq_i(c.size(), 3, "rolls 3 cards")
	_distinct(c, "3 rolled cards are distinct")

	# Same seed -> same offer (determinism).
	var c2 := Upgrades.roll_choices(Upgrades.POOL, _rng(7), 3, {})
	_eq_ids(c, c2, "same seed -> same roll")

	# Capped cards at their max are never offered.
	var capped := {}
	for card in Upgrades.POOL:
		if card.has("max"):
			capped[card["id"]] = card["max"]
	var all := Upgrades.roll_choices(Upgrades.POOL, _rng(99), Upgrades.POOL.size(), capped)
	_eq_i(all.size(), Upgrades.POOL.size() - capped.size(), "maxed cards drop out of the pool")
	for card in all:
		if card.has("max"):
			printerr("  FAIL: maxed card %s was offered" % card["id"])
			_failures += 1


func _test_apply() -> void:
	var s := PlayerStats.new()
	var w := Weapon.new()   # pistol: 1 pellet, 0 spread, 0 pierce

	Upgrades.apply(s, w, _card(&"damage"))
	_near(s.damage_mult, 1.25, "damage card -> +0.25 mult")

	Upgrades.apply(s, w, _card(&"firerate"))
	_near(s.fire_rate_mult, 1.20, "firerate card -> +0.20 mult")

	Upgrades.apply(s, w, _card(&"speed"))
	_near(s.move_speed, 4.6, "speed card -> +0.6")

	Upgrades.apply(s, w, _card(&"pickup"))
	_near(s.pickup_radius, 1.8, "pickup card -> +0.6")

	# max_health adds to the cap (the heal-on-pick is main's job, not apply's).
	Upgrades.apply(s, w, _card(&"health"))
	_eq_i(s.max_health, 125, "health card -> +25 max HP")

	# Multishot: +1 pellet and grants a fan when there was none.
	Upgrades.apply(s, w, _card(&"multishot"))
	_eq_i(w.pellets, 2, "multishot -> 2 pellets")
	if w.spread_deg <= 0.0:
		printerr("  FAIL: multishot did not grant spread (got %.1f)" % w.spread_deg)
		_failures += 1

	Upgrades.apply(s, w, _card(&"pierce"))
	_eq_i(w.pierce, 1, "pierce -> +1")

	# gain_weapon reshapes the weapon in place.
	Upgrades.apply(s, w, _card(&"shotgun"))
	_eq_i(w.pellets, 5, "shotgun -> 5 pellets")
	if w.max_range != 9.0:
		printerr("  FAIL: shotgun range (got %.1f want 9.0)" % w.max_range)
		_failures += 1


# --- helpers -----------------------------------------------------------------

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _card(id: StringName) -> Dictionary:
	for card in Upgrades.POOL:
		if card["id"] == id:
			return card
	push_error("no card %s" % id)
	return {}


func _distinct(cards: Array, msg: String) -> void:
	var seen := {}
	for card in cards:
		if seen.has(card["id"]):
			printerr("  FAIL: %s (duplicate %s)" % [msg, card["id"]])
			_failures += 1
			return
		seen[card["id"]] = true


func _eq_ids(a: Array, b: Array, msg: String) -> void:
	if a.size() != b.size():
		printerr("  FAIL: %s (size %d vs %d)" % [msg, a.size(), b.size()])
		_failures += 1
		return
	for i in a.size():
		if a[i]["id"] != b[i]["id"]:
			printerr("  FAIL: %s (card %d: %s vs %s)" % [msg, i, a[i]["id"], b[i]["id"]])
			_failures += 1
			return


func _eq_i(got: int, want: int, msg: String) -> void:
	if got != want:
		printerr("  FAIL: %s (got %d want %d)" % [msg, got, want])
		_failures += 1


func _near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > 0.0001:
		printerr("  FAIL: %s (got %.4f want %.4f)" % [msg, got, want])
		_failures += 1
