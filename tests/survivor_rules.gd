extends SceneTree
## Functional rules checks. Runs locally without providers, editor control or saves.

const ProgressionScript = preload("res://scripts/hospital_progression.gd")
var game
var checks := 0
var failures := 0


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
	_test_progression()
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_test_level_choices()
	_test_loot()
	_test_chests()
	_test_campaign_state()
	print("SURVIVOR RULES COMPLETE | ", checks, " checks | ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _test_progression() -> void:
	var progression = ProgressionScript.new()
	check(progression.weapons == {"syringe": 1} and progression.supplies.is_empty(), "new run starts with only the one-star syringe")
	for id in ["pulse", "guardian", "lightning", "rocket", "brick"]:
		progression.apply_upgrade(id)
	check(progression.weapons.size() == 6 and not progression.apply_upgrade("soccer"), "six-weapon cap includes the starter weapon")
	check(progression.apply_upgrade("syringe") and progression.get_level("syringe") == 2, "full weapon inventory still permits owned upgrades")
	for id in ["experience", "cooldown", "duration", "area", "health", "speed"]:
		progression.apply_upgrade(id)
	check(progression.supplies.size() == 6 and not progression.apply_upgrade("attack"), "supplies have a separate six-slot cap")
	check(not progression.available_upgrades().has("soccer") and not progression.available_upgrades().has("attack"), "choice pool excludes equipment blocked by full slots")
	check(not progression.apply_upgrade("not_an_item"), "unknown upgrade IDs cannot mutate equipment")
	progression.reset()
	for _index in range(4):
		progression.apply_upgrade("syringe")
	check(progression.get_level("syringe") == 5 and not progression.can_evolve("syringe") and not progression.apply_upgrade("syringe"), "five-star weapon cannot evolve without its paired supply")
	progression.apply_upgrade("attack")
	check(not progression.can_evolve("syringe"), "unrelated supplies do not unlock evolution")
	progression.apply_upgrade("experience")
	var info: Dictionary = progression.offer_info("syringe")
	check(progression.can_evolve("syringe") and info.evolution and info.next_level == 6 and not str(info.requirement).is_empty(), "one-star paired supply unlocks the named evolution offer")
	check(progression.apply_upgrade("syringe") and progression.is_evolved("syringe") and not progression.apply_upgrade("syringe"), "weapon evolution ends at level six")
	for _index in range(4):
		progression.apply_upgrade("experience")
	check(progression.get_level("experience") == 5 and not progression.apply_upgrade("experience"), "supplies stop at level five")
	progression.weapons = {"syringe": 1, "drone_a": 5, "drone_b": 4, "guardian": 1, "lightning": 1, "rocket": 1}
	check(not progression.can_evolve("destroyer") and not progression.apply_upgrade("destroyer"), "drone fusion requires both components at five stars")
	progression.apply_upgrade("drone_b")
	check(progression.can_evolve("destroyer") and progression.available_upgrades().has("destroyer"), "maxed drone pair offers its fusion at full inventory")
	check(progression.apply_upgrade("destroyer") and progression.weapons.size() == 5 and progression.get_level("destroyer") == 6, "fusion consumes two drones and frees one weapon slot")
	check(not progression.weapons.has("drone_a") and not progression.weapons.has("drone_b") and not progression.apply_upgrade("drone_a") and not progression.available_upgrades().has("drone_b"), "fused component drones cannot be acquired again")
	check(progression.apply_upgrade("soccer") and progression.weapons.size() == 6, "freed fusion slot accepts a new weapon")
	progression.reset()
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 261025
	second_rng.seed = 261025
	var first: Array[String] = progression.roll_choices(first_rng)
	var second: Array[String] = progression.roll_choices(second_rng)
	check(first.size() == 3 and _unique(first) and first == second, "choice rolls contain three unique offers and respect the supplied RNG seed")
	check(progression.roll_choices(first_rng, 0).is_empty() and progression.roll_choices(first_rng, -1).is_empty(), "zero or negative choice requests return no offers")
	var valid_random_run := true
	for _index in range(200):
		var offers: Array[String] = progression.roll_choices(first_rng)
		valid_random_run = valid_random_run and not offers.is_empty() and _unique(offers)
		var selected: String = offers[0]
		valid_random_run = valid_random_run and progression.apply_upgrade(selected)
		valid_random_run = valid_random_run and progression.weapons.size() <= 6 and progression.supplies.size() <= 6
		for id in progression.weapons:
			valid_random_run = valid_random_run and progression.get_level(id) in range(1, 7)
		for id in progression.supplies:
			valid_random_run = valid_random_run and progression.get_level(id) in range(1, 6)
	check(valid_random_run, "two hundred seeded choices preserve slot and level limits without invalid offers")
	_set_maxed(progression)
	var exhausted: Array[String] = progression.roll_choices(first_rng)
	check(not progression.available_upgrades().is_empty() and exhausted.size() == 3 and _unique(exhausted) and not exhausted.has("heal") and not exhausted.has("coins"), "fully evolved loadout keeps offering mastery growth")
	check(progression.apply_upgrade("mastery:syringe") and not progression.apply_upgrade("heal") and not progression.apply_upgrade("coins"), "mastery remains available instead of exhausted fallback rewards")
	progression.supplies["experience"] = 4
	check(progression.available_upgrades().has("experience") and progression.available_upgrades().has("mastery:syringe") and not progression.apply_upgrade("heal"), "remaining supply upgrades coexist with evolved weapon mastery")
	_set_blocked(progression)
	exhausted = progression.roll_choices(first_rng)
	check(progression.available_upgrades().is_empty() and exhausted.size() == 2 and _unique(exhausted) and exhausted.has("heal") and exhausted.has("coins"), "a full unevolved build without matching supplies retains the fallback rewards")
	check(progression.apply_upgrade("heal") and progression.apply_upgrade("coins"), "fallback rewards remain valid when no equipment can grow")
	progression.reset()
	check(progression.weapons == {"syringe": 1} and progression.supplies.is_empty(), "reset discards all previous weapons and supplies")


func _test_level_choices() -> void:
	game.start_run()
	game.rng.seed = 261025
	game.xp = game.xp_needed()
	game._check_level_up()
	check(game.mode == game.Mode.CHOOSING and game.level == 2 and game.upgrade_choices.size() == 3 and _unique(game.upgrade_choices), "level-up stops play and opens three distinct upgrade choices")
	var enemy: Dictionary = game.make_enemy(game.hero + Vector2(250, 0), "normal")
	game.enemies.append(enemy)
	var frozen_time: float = game.elapsed
	var frozen_position: Vector2 = enemy.p
	var frozen_hero: Vector2 = game.hero
	game.step_game(1.0, Vector2.RIGHT)
	check(game.elapsed == frozen_time and enemy.p == frozen_position and game.hero == frozen_hero, "upgrade selection freezes timer, enemies and movement")
	var choices: Array = game.upgrade_choices.duplicate()
	game.pause_run("test")
	check(game.mode == game.Mode.PAUSED and game.paused_mode == game.Mode.CHOOSING, "pausing remembers an open selection")
	game.resume_run()
	check(game.mode == game.Mode.CHOOSING and game.upgrade_choices == choices, "resuming returns to the same upgrade choices")
	var loadout: Dictionary = game.progression.weapons.duplicate()
	game.choose_upgrade(-1)
	game.choose_upgrade(999)
	check(game.mode == game.Mode.CHOOSING and game.upgrade_choices == choices and game.progression.weapons == loadout, "invalid choice indexes preserve state")
	game.reroll_upgrades()
	check(game.rerolls_left == 0 and game.upgrade_choices.size() == 3 and _unique(game.upgrade_choices), "one reroll replaces the choices and consumes the run allowance")
	choices = game.upgrade_choices.duplicate()
	game.reroll_upgrades()
	check(game.rerolls_left == 0 and game.upgrade_choices == choices, "second reroll cannot change the offer")
	game.upgrade_choices.assign(["not_an_item"])
	game.choose_upgrade(0)
	check(game.mode == game.Mode.CHOOSING and game.progression.weapons == loadout, "stale or unknown offered item cannot resume play or grant an upgrade")
	game.start_run()
	var first_cost: int = game.xp_needed()
	game.level = 2
	var second_cost: int = game.xp_needed()
	game.level = 1
	game.xp = first_cost + second_cost + 3
	game._check_level_up()
	var first_revision: int = game.choice_revision
	game.choose_upgrade(0, first_revision)
	check(game.mode == game.Mode.PLAYING and game.level == 2 and game.xp == second_cost + 3, "buffered experience waits for combat after the first choice without losing XP")
	game.spawn_clock = 1000
	game.elite_clock = 1000
	game.loot_clock = 1000
	game.step_game(game.UPGRADE_COMBAT_INTERVAL, Vector2.ZERO)
	check(game.mode == game.Mode.CHOOSING and game.level == 3 and game.xp == 3, "buffered experience opens the next selection after the combat interval")
	choices = game.upgrade_choices.duplicate()
	loadout = game.progression.weapons.duplicate()
	var supplies: Dictionary = game.progression.supplies.duplicate()
	game.choose_upgrade(0, first_revision)
	check(game.mode == game.Mode.CHOOSING and game.upgrade_choices == choices and game.progression.weapons == loadout and game.progression.supplies == supplies, "delayed duplicate selection cannot choose a subsequent buffered reward")
	game.reroll_upgrades(first_revision)
	check(game.rerolls_left == 1 and game.upgrade_choices == choices, "stale reroll cannot consume the current choice allowance")
	game.choose_upgrade(0)
	check(game.mode == game.Mode.PLAYING and game.level == 3 and game.xp == 3, "last buffered level resumes play without losing remaining experience")


func _test_loot() -> void:
	game.start_run()
	game.hp = 10
	game.collect_pickup("heal")
	check(is_equal_approx(game.hp, 40.0), "health pickup restores thirty percent of maximum health")
	game.hp = game.max_hp - 1
	game.collect_pickup("heal")
	check(game.hp == game.max_hp, "health pickup cannot exceed maximum health")
	var before_coins: int = game.coins
	game.collect_pickup("coin")
	check(game.coins > before_coins, "coin pickup grants local run currency")
	game._spawn_gem(game.hero + Vector2(1500, 0), 2)
	game._spawn_gem(game.hero + Vector2(-1500, 0), 3)
	game.collect_pickup("magnet")
	for _index in range(200):
		game._update_gems(0.1)
	check(game.gems.is_empty() and game.xp == 5, "magnet pickup collects distant experience without losing gem values")
	game.start_run()
	game._apply_upgrade("experience")
	game.level = 100
	for _index in range(10):
		game._spawn_gem(game.hero, 1)
	game._update_gems(0.01)
	var single_gem_xp: int = game.xp
	game.start_run()
	game._apply_upgrade("experience")
	game.level = 100
	game._spawn_gem(game.hero, 10)
	game._update_gems(0.01)
	check(single_gem_xp == 11 and game.xp == single_gem_xp, "experience supply retains fractional bonuses equally for separate and merged gems")
	game.start_run()
	var normal: Dictionary = game.make_enemy(game.hero + Vector2(120, 0), "normal")
	var elite: Dictionary = game.make_enemy(game.hero + Vector2(180, 0), "elite")
	var distant: Dictionary = game.make_enemy(game.hero + Vector2(2500, 0), "normal")
	var elite_hp: float = elite.hp
	var distant_hp: float = distant.hp
	game.enemies.append(normal)
	game.enemies.append(elite)
	game.enemies.append(distant)
	game.collect_pickup("bomb")
	check(normal.hp <= 0 and elite.hp < elite_hp and distant.hp == distant_hp, "bomb clears nearby normal enemies and damages elites within its range")
	game.start_run()
	var total := 0
	for index in range(240):
		var value := index % 3 + 1
		total += value
		game._spawn_gem(game.hero + Vector2(1200 + index, 0), value)
	var stored := 0
	for value in game.gem_amounts:
		stored += value
	check(game.gems.size() <= 180 and game.gems.size() == game.gem_amounts.size() and stored == total, "experience cap merges overflow without losing value or desynchronizing arrays")
	game.spawn_pickup(game.hero + Vector2(3000, 0), "heal")
	game.loot_clock = 20.0
	game._update_gems(0.1)
	game._update_pickups(0.1)
	check(game.gems.size() == 180 and not game.pickups.is_empty(), "offscreen experience and supplies persist instead of being culled")


func _test_chests() -> void:
	game.start_run()
	game.progression.weapons["syringe"] = 5
	game.progression.supplies["experience"] = 1
	game.open_chest(1)
	check(game.progression.is_evolved("syringe"), "single-reward chest prioritizes an eligible evolution")
	game.start_run()
	game.open_chest(3)
	check(game.progression.weapons.size() == 1 and game.progression.supplies.is_empty() and game.progression.get_level("syringe") == 4, "multi-reward chest upgrades owned gear without filling empty slots")
	game.start_run()
	_set_maxed(game.progression)
	var coins_before: int = game.coins
	var mastery_before := _total_mastery(game.progression)
	game.open_chest(1)
	check(game.coins == coins_before and _total_mastery(game.progression) == mastery_before + 1, "maxed chest continues upgrading owned evolved weapons")
	_set_blocked(game.progression)
	coins_before = game.coins
	game.collect_pickup("coin")
	check(game.coins == coins_before + 15, "gold supply bonus applies to floor coins")
	coins_before = game.coins
	game.open_chest(1)
	check(game.coins == coins_before + 75, "gold supply bonus applies to exhausted chest rewards")
	coins_before = game.coins
	game._apply_upgrade("coins")
	check(game.coins == coins_before + 75, "gold supply bonus applies to exhausted level-up rewards")


func _test_campaign_state() -> void:
	game.start_run()
	game.begin_stage(2)
	check(not game.pulse_unlocked() and game.progression.get_level("pulse") == 0, "stage two does not grant an unselected free pulse weapon")
	game._apply_upgrade("pulse")
	game._apply_upgrade("health")
	game.level = 4
	game.xp = 3
	game.coins = 123
	var loadout: Dictionary = game.progression.weapons.duplicate()
	var supplies: Dictionary = game.progression.supplies.duplicate()
	game.begin_stage(3)
	check(game.progression.weapons == loadout and game.progression.supplies == supplies and game.level == 4 and game.xp == 3 and game.coins == 123, "stage transitions retain weapons, supplies, level, experience and coins")
	game.spawn_pickup(game.hero + Vector2(300, 0), "chest")
	game._spawn_gem(game.hero + Vector2(300, 0), 3)
	game.upgrade_choices.assign(["syringe"])
	game.rerolls_left = 0
	game.start_run()
	check(game.progression.weapons == {"syringe": 1} and game.progression.supplies.is_empty() and game.max_hp == 100 and game.hp == 100, "restart resets loadout and all derived health stats")
	check(game.gems.is_empty() and game.gem_amounts.is_empty() and game.pickups.is_empty() and game.shots.is_empty() and game.shockwaves.is_empty(), "restart clears experience, loot and active combat effects")
	check(game.upgrade_choices.is_empty() and game.rerolls_left == 1 and game.coins == 0 and game.level == 1 and game.xp == 0 and game.stage_index == 1 and game.mode == game.Mode.PLAYING, "restart clears reward state and restores a fresh first-stage run")


func _unique(values: Array) -> bool:
	var found := {}
	for value in values:
		if found.has(value):
			return false
		found[value] = true
	return true


func _set_maxed(progression) -> void:
	progression.weapons = {"syringe": 6, "pulse": 6, "guardian": 6, "lightning": 6, "rocket": 6, "brick": 6}
	progression.supplies = {"experience": 5, "cooldown": 5, "duration": 5, "area": 5, "health": 5, "regen": 5}
	progression.mastery = {}
	progression.traits = {}


func _set_blocked(progression) -> void:
	progression.weapons = {"syringe": 5, "pulse": 5, "guardian": 5, "lightning": 5, "rocket": 5, "brick": 5}
	progression.supplies = {"speed": 5, "attack": 5, "magnet": 5, "armor": 5, "projectile": 5, "gold": 5}
	progression.mastery = {}
	progression.traits = {}


func _total_mastery(progression) -> int:
	var total := 0
	for rank in progression.mastery.values():
		total += int(rank)
	return total
