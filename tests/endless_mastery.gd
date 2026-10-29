extends SceneTree
## Deterministic, local-only checks for growth after evolution and its save format.

const ProgressionScript = preload("res://scripts/hospital_progression.gd")
const ArsenalScript = preload("res://scripts/hospital_arsenal.gd")
var checks := 0
var failures := 0


class ClearWorld:
	extends RefCounted

	func clear_line(_from: Vector2, _to: Vector2, _radius: float) -> bool:
		return true


class CombatFixture:
	extends Node2D
	var progression = ProgressionScript.new()
	var world = ClearWorld.new()
	var hero := Vector2.ZERO
	var enemies: Array[Dictionary] = []
	var hits: Array[Dictionary] = []

	func attack_multiplier() -> float: return 1.0
	func cooldown_multiplier() -> float: return 1.0
	func duration_multiplier() -> float: return 1.0
	func area_multiplier() -> float: return 1.0
	func projectile_multiplier() -> float: return 1.0
	func _play(_sound: String, _point: Vector2) -> void: pass

	func _damage_enemy(_enemy: Dictionary, amount: float, weapon_id: String = "") -> void:
		hits.append({"weapon_id": weapon_id, "amount": amount})


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	_test_growth()
	_test_restore()
	_test_arsenal_identity()
	print("ENDLESS MASTERY COMPLETE | ", checks, " checks | ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_growth() -> void:
	var progression = ProgressionScript.new()
	check(not progression.apply_upgrade("mastery:syringe") and not progression.apply_upgrade("trait:syringe:focus"), "base weapons cannot acquire mastery or traits")
	for _step in range(4):
		progression.apply_upgrade("syringe")
	progression.apply_upgrade("experience")
	progression.apply_upgrade("syringe")
	check(progression.is_evolved("syringe") and progression.available_upgrades().has("mastery:syringe"), "evolution immediately unlocks continuing mastery")
	check(progression.is_owned_upgrade("mastery:syringe") and not progression.can_evolve("mastery:syringe"), "chests recognize mastery without treating it as evolution")
	for _step in range(2):
		progression.apply_upgrade("mastery:syringe")
	check(not progression.available_upgrades().has("trait:syringe:focus"), "traits wait for the third mastery level")
	progression.apply_upgrade("mastery:syringe")
	check(progression.available_upgrades().has("trait:syringe:focus") and progression.available_upgrades().has("trait:syringe:blast"), "third mastery offers both alternative traits")
	check(not progression.is_owned_upgrade("trait:syringe:focus"), "a chest cannot choose a permanent trait for the player")
	check(is_equal_approx(progression.damage_multiplier("syringe"), 1.45) and progression.get_level("syringe") == 6, "mastery increases damage while retaining the six-level weapon contract")
	var info: Dictionary = progression.offer_info("mastery:syringe")
	check(info.category == "mastery" and info.level == 3 and info.next_level == 4 and not info.evolution, "mastery offer exposes the next mastery rank to the HUD")
	info = progression.offer_info("trait:syringe:blast")
	check(info.category == "trait" and not info.description.is_empty() and not info.requirement.is_empty(), "trait offer describes its effect and mutually exclusive selection")
	check(progression.apply_upgrade("trait:syringe:focus") and progression.trait_for("syringe") == "focus", "trait selection stores the chosen weapon behavior")
	check(not progression.apply_upgrade("trait:syringe:blast") and not progression.apply_upgrade("trait:syringe:focus"), "a selected trait cannot be replaced or selected twice")
	var successful := true
	for _step in range(500):
		successful = progression.apply_upgrade("mastery:syringe") and successful
	check(successful and progression.mastery.syringe == 503 and progression.weapons.size() == 1 and progression.get_level("syringe") == 6, "five hundred more upgrades preserve slots and continue the damage curve")
	check(is_equal_approx(progression.damage_multiplier("syringe"), 76.45), "high mastery remains a finite additive damage multiplier")
	check(progression.damage_multiplier("unknown") == 1.0 and progression.trait_for("unknown").is_empty(), "non-weapon damage has no accidental mastery or trait")
	progression.weapons = {"syringe": 6, "pulse": 6, "guardian": 6, "lightning": 6, "rocket": 6, "brick": 6}
	progression.supplies = {"experience": 5, "regen": 5, "duration": 5, "cooldown": 5, "area": 5, "health": 5}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var offers: Array[String] = progression.roll_choices(rng)
	check(offers.size() == 3 and not offers.has("heal") and not offers.has("coins"), "maxed equipment continues offering growth instead of exhausted rewards")
	progression.reset()
	check(progression.mastery.is_empty() and progression.traits.is_empty() and progression.damage_multiplier("syringe") == 1.0, "new run clears mastery and all selected traits")
	progression.weapons = {"syringe": 1, "drone_a": 5, "drone_b": 5}
	progression.apply_upgrade("destroyer")
	check(progression.apply_upgrade("mastery:destroyer") and progression.mastery.destroyer == 1 and not progression.apply_upgrade("mastery:drone_a"), "fused drones gain mastery under their new weapon identity")


func _test_restore() -> void:
	var progression = ProgressionScript.new()
	var fixture := {"weapons": {"syringe": 6, "destroyer": 6}, "supplies": {"experience": 3}, "mastery": {"syringe": 12, "destroyer": 3}, "traits": {"syringe": "focus", "destroyer": "blast"}}
	check(progression.restore(fixture) and progression.serialize() == fixture, "valid evolved and fused builds round-trip with mastery and traits")
	var exported: Dictionary = progression.serialize()
	exported.weapons.syringe = 1
	exported.mastery.syringe = 0
	check(progression.get_level("syringe") == 6 and progression.mastery.syringe == 12, "save snapshots cannot mutate live progression through dictionary aliases")
	var parsed: Variant = JSON.parse_string(JSON.stringify(fixture))
	check(parsed is Dictionary and progression.restore(parsed) and progression.serialize() == fixture, "JSON float representation restores exact integral levels")
	var cases: Array[Dictionary] = []
	var invalid := fixture.duplicate(true)
	invalid.weapons["unrecognized"] = 1
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons.syringe = 6.5
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.supplies.experience = -1
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.supplies.experience = 6
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.supplies.experience = true
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.syringe = INF
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.syringe = NAN
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.syringe = -1
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.syringe = 3.25
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.syringe = 1e30
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons.syringe = 5
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery["rocket"] = 3
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.traits.syringe = "unrecognized"
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.mastery.destroyer = 2
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons["drone_a"] = 5
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons.destroyer = 5
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons.erase("destroyer")
	invalid.weapons["drone_a"] = 6
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons = {"syringe": 6, "pulse": 1, "guardian": 1, "lightning": 1, "rocket": 1, "brick": 1, "destroyer": 6}
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.supplies = {"experience": 1, "regen": 1, "duration": 1, "cooldown": 1, "area": 1, "health": 1, "speed": 1}
	cases.append(invalid)
	invalid = fixture.duplicate(true)
	invalid.weapons = {}
	cases.append(invalid)
	cases.append({"weapons": [], "supplies": {}})
	cases.append({"supplies": {}})
	var rejected_all := true
	var atomic := true
	for payload in cases:
		rejected_all = not progression.restore(payload) and rejected_all
		atomic = progression.serialize() == fixture and atomic
	check(rejected_all, "twenty-two corrupt saves are rejected: IDs, slots, fractions, nonfinite numbers, traits and fusion")
	check(atomic, "every rejected restore leaves all four live dictionaries untouched")
	check(progression.restore({"weapons": {"syringe": 1}, "supplies": {}}) and progression.mastery.is_empty() and progression.traits.is_empty(), "legacy loadouts without mastery fields restore with empty new state")


func _test_arsenal_identity() -> void:
	var game := CombatFixture.new()
	var arsenal = ArsenalScript.new()
	for weapon: String in ["rocket", "brick", "soccer", "drone_a", "drone_b", "destroyer"]:
		arsenal.reset()
		game.hits.clear()
		game.enemies.assign([{"p": Vector2(150, 0), "hp": 99999.0, "kind": "normal"}])
		var level := 5 if weapon in ["drone_a", "drone_b"] else 6
		game.progression.weapons = {weapon: level}
		game.progression.mastery = {weapon: 20} if level == 6 else {}
		arsenal._fire(game, weapon, level)
		var retained: bool = not arsenal.projectiles.is_empty()
		for projectile: Dictionary in arsenal.projectiles:
			retained = String(projectile.get("weapon_id", "")) == weapon and retained
		check(retained, "%s projectiles retain their weapon identity" % weapon)
		game.enemies[0].p = arsenal.projectiles[0].p
		arsenal._update_projectiles(game, 0.0)
		var attributed := not game.hits.is_empty()
		for hit: Dictionary in game.hits:
			attributed = hit.weapon_id == weapon and attributed
		check(attributed, "%s impact passes its weapon identity to host damage" % weapon)
		if weapon == "brick":
			check(is_equal_approx(float(game.hits[0].amount), 125.0), "arsenal sends base damage so the host applies mastery only once")
	arsenal.reset()
	game.hits.clear()
	game.enemies.assign([{"p": Vector2(150, 0), "hp": 99999.0, "kind": "normal"}])
	arsenal._fire(game, "lightning", 6)
	check(game.hits.size() == 2 and game.hits[0].weapon_id == "lightning" and game.hits[1].weapon_id == "lightning", "direct lightning and its evolved explosion share the same weapon identity")
	arsenal.reset()
	game.hits.clear()
	game.progression.weapons = {"guardian": 6}
	game.enemies.assign([{"p": Vector2(110, 0), "hp": 99999.0, "kind": "normal"}])
	arsenal._update_guardian(game, 0.0)
	check(not game.hits.is_empty() and game.hits[0].weapon_id == "guardian", "guardian contact passes its weapon identity to host damage")
	game.free()
