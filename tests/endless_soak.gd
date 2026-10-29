extends SceneTree
## Full first/second-sector balance runs, plus a separate synthetic combat-load check.
## Natural runs use offered rewards and earned materials; no stat or immunity cheats.
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


func _new_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)


func _run() -> void:
	for seed_value in [261023, 71023]:
		_new_game()
		_campaign(seed_value)
		game.queue_free()
		await process_frame
	_new_game()
	_stress_combat()
	game.queue_free()
	await process_frame
	print("ENDLESS SOAK COMPLETE | ", checks, " checks | ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _campaign(seed_value: int) -> void:
	game.start_run()
	game.rng.seed = seed_value
	game._save_checkpoint(1)
	var route := [Vector2(2304, 576), Vector2(2304, 1728), Vector2(768, 1728), Vector2(768, 576)]
	var waypoint := 0
	var previous_stage := 1
	var peak_enemies := 0
	var peak_enemy_shots := 0
	var retries := 0
	var reached_seven := false
	var bounded := true
	var started := Time.get_ticks_msec()
	for _tick in range(27000):
		_choose_upgrade()
		if game.mode == game.Mode.LOST:
			print("SOAK DEATH | seed=", seed_value, " stage=", game.stage_index, " stage_s=", game.elapsed, " level=", game.level, " retry=", retries)
			if retries >= 2 or not game.continue_checkpoint():
				break
			retries += 1
			waypoint = 0
		if game.mode == game.Mode.REST:
			print("SOAK SECTOR | seed=", seed_value, " stage=", game.stage_index, " time=", game.total_elapsed, " level=", game.level, " hp=", game.hp, " weapons=", game.progression.weapons, " mastery=", game.progression.mastery, " traits=", game.progression.traits)
			_spend_earned_materials()
			game.leave_workshop()
			if game.stage_index == 7:
				reached_seven = true
				break
		if previous_stage != game.stage_index:
			waypoint = 0
			previous_stage = game.stage_index
		var direction := Vector2.ZERO
		if game.stage_in_sector() < 3:
			if game.hero.distance_to(route[waypoint]) < 30:
				waypoint = (waypoint + 1) % route.size()
			direction = game.hero.direction_to(route[waypoint])
		else:
			var target: Vector2 = game.START + Vector2.from_angle(game.elapsed) * 255.0
			direction = game.hero.direction_to(target)
		game.step_game(0.1, direction)
		peak_enemies = maxi(peak_enemies, game.enemies.size())
		peak_enemy_shots = maxi(peak_enemy_shots, game.enemy_shots.size())
		bounded = bounded and _bounded()
	check(reached_seven and game.cleared_stages >= 6, "normal offered upgrades and earned equipment reach stage seven for seed %d" % seed_value)
	check(bounded, "two-sector play keeps every combat container bounded for seed %d" % seed_value)
	print("SOAK RESULT | seed=", seed_value, " success=", reached_seven, " stage=", game.stage_index, " mode=", game.mode, " retries=", retries, " total_s=", game.total_elapsed, " hp=", game.hp, " kills=", game.kills, " level=", game.level, " materials=", game.campaign.profile.materials, " equipment=", game.campaign.profile.equipment, " peak_enemies=", peak_enemies, " peak_enemy_shots=", peak_enemy_shots, " simulation_ms=", Time.get_ticks_msec() - started)


func _spend_earned_materials() -> void:
	# Alternate offense and health, buying only with materials actually awarded.
	for _purchase in range(16):
		var slot := "coat" if game.campaign.equipment_level("coat") <= game.campaign.equipment_level("gloves") else "gloves"
		if not game.upgrade_equipment(slot):
			break


func _choose_upgrade() -> void:
	var priority := {"syringe": 120, "lightning": 96, "pulse": 94, "guardian": 92,
		"rocket": 90, "soccer": 88, "brick": 86, "cooldown": 82, "attack": 78,
		"regen": 76, "health": 72, "speed": 68, "duration": 62,
		"drone_a": 60, "drone_b": 59, "area": 55, "armor": 50,
		"projectile": 40, "experience": 38, "magnet": 35, "gold": 10}
	while game.mode == game.Mode.CHOOSING:
		var best := 0
		var best_score := -1
		for index in range(game.upgrade_choices.size()):
			var id: String = game.upgrade_choices[index]
			var score: int = priority.get(id, 0)
			if game.progression.can_evolve(id):
				score += 150
			if id.begins_with("mastery:"):
				score = 98
			if id.begins_with("trait:"):
				score = 130 if id.ends_with(":blast") else 125
			if id == "experience" and game.progression.get_level(id) == 0:
				score = 112
			if id == "magnet" and game.progression.get_level(id) == 0:
				score = 100
			if id == "duration" and game.progression.get_level("guardian") >= 4 and game.progression.get_level(id) == 0:
				score = 110
			if score > best_score:
				best = index
				best_score = score
		game.choose_upgrade(best)


func _bounded() -> bool:
	return game.enemies.size() <= 48 and game.enemy_shots.size() <= 80 and game.shots.size() <= 80 and game.particles.size() <= 240 and game.numbers.size() <= 64 and game.gems.size() <= 180 and game.arsenal.projectiles.size() <= 128 and game.arsenal.effects.size() <= 80


func _stress_combat() -> void:
	# This is a synthetic throughput fixture, separate from the two balance runs.
	game.start_run()
	game.progression.weapons = {"syringe": 6, "pulse": 6, "guardian": 6, "lightning": 6, "rocket": 6, "brick": 6}
	game.progression.supplies = {"health": 5, "armor": 5, "attack": 5, "area": 5, "cooldown": 5, "duration": 5}
	for weapon: String in game.progression.weapons:
		game.progression.mastery[weapon] = 100
		game.progression.traits[weapon] = "blast"
	game._recompute_stats()
	game.begin_stage(30)
	game.enemies.clear()
	var kinds := ["normal", "tank", "ranged", "rusher", "elite"]
	for index in range(48):
		var point: Vector2 = game.hero + Vector2.from_angle(index * TAU / 48) * (130.0 + index % 3 * 20.0)
		var enemy: Dictionary = game.make_enemy(point, kinds[index % kinds.size()])
		enemy.hp = 1e12
		enemy.max_hp = 1e12
		game.enemies.append(enemy)
	var bounded := true
	var peak_projectiles := 0
	var peak_effects := 0
	var slowest_us := 0
	var total_us := 0
	for index in range(180):
		var started := Time.get_ticks_usec()
		if index % 3 == 0:
			game._auto_fire()
		if index % 9 == 0:
			game.fire_pulse()
		game.arsenal.update(game, 1.0 / 60.0)
		game._update_shots(1.0 / 60.0)
		var elapsed_us := Time.get_ticks_usec() - started
		total_us += elapsed_us
		slowest_us = maxi(slowest_us, elapsed_us)
		peak_projectiles = maxi(peak_projectiles, game.arsenal.projectiles.size())
		peak_effects = maxi(peak_effects, game.arsenal.effects.size())
		bounded = bounded and _bounded()
	check(bounded and game.enemies.size() == 48, "six evolved mastery-blast weapons remain bounded against forty-eight durable mixed enemies")
	print("COMBAT STRESS | frames=180 mean_us=", total_us / 180, " max_us=", slowest_us, " peak_projectiles=", peak_projectiles, " peak_effects=", peak_effects, " particles=", game.particles.size(), " damage_numbers=", game.numbers.size())
