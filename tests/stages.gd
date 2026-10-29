extends SceneTree
## Stage progression, elite/boss combat and complete normal-rules campaigns.
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
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_TAB
	game._unhandled_input(event)
	check(game.selected_skin == 1, "title permits the second cosmetic appearance")
	game.start_run()
	# Isolate the elite schedule while advancing real cumulative game time.
	game.spawn_clock = 1000
	for i in range(749):
		choose_build_upgrade()
		game.step_game(0.1, Vector2.RIGHT)
	choose_build_upgrade()
	check(game._kind_count("elite") == 0 and game.boss_enemy().is_empty(), "first stage has no elite before 75 seconds")
	game.step_game(0.2, Vector2.RIGHT)
	check(game.stage_index == 1 and game._kind_count("elite") == 1 and game.elite_clock > 59, "first-stage elite appears at 75 seconds and schedules a 60-second interval")
	game.enemies.clear()
	for i in range(599):
		choose_build_upgrade()
		game.step_game(0.1, Vector2.RIGHT)
	choose_build_upgrade()
	check(game._kind_count("elite") == 0, "first-stage reinforcement waits the complete 60-second interval")
	game.step_game(0.2, Vector2.RIGHT)
	check(game._kind_count("elite") == 1, "first-stage reinforcement repeats after 60 seconds")
	game.start_run()
	game.level = 5
	game.xp = 8
	game.damage = 52
	game.fire_interval = 0.3
	game.hp = 50
	game.elapsed = 179.99
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.TRANSITION and game.stage_index == 1, "first timer enters a stage-clear intermission")
	var frozen_time: float = game.total_elapsed
	game.step_game(1.0, Vector2.RIGHT)
	check(game.total_elapsed == frozen_time and game.stage_index == 1, "intermission freezes play time and does not skip stages")
	game.step_game(2.3, Vector2.ZERO)
	check(game.stage_index == 2 and game.mode == game.Mode.PLAYING and game.elapsed == 0, "intermission automatically starts a fresh three-minute stage two")
	check(game.level == 5 and game.xp == 8 and game.damage == 52 and game.fire_interval == 0.3 and game.hp == 75, "stage change keeps growth and heals exactly 25 health")
	check(game.world.current_theme == 1 and game._kind_count("elite") == 2 and not game.pulse_unlocked(), "stage two starts with the isolation theme and elite pair; weapons require upgrades")
	for i in range(3):
		game.enemies.append(game.make_enemy(game.hero + Vector2(800, 0), "elite"))
	game.elite_clock = 0
	game.step_game(0.01, Vector2.ZERO)
	check(game._kind_count("elite") == 6 and not game.spawn_enemy("elite") and game.elite_clock == 25, "25-second reinforcement from five elites respects the six-elite cap")
	var elite: Dictionary = game.enemies[0]
	check(elite.kind == "elite" and elite.hp > 400 and elite.speed > 90, "elite has distinct endurance and mobility")
	game.hero = game.START
	elite.p = game.hero + Vector2(100, 0)
	elite.clock = 0
	game._special_attack(elite, 0.01)
	check(elite.attack == "slam_warning" and game.hp == 75, "elite warns before its area strike")
	game.hero += Vector2(0, 230)
	game._special_attack(elite, 0.9)
	check(game.hp == 75 and elite.attack == "recover", "moving out of a warned strike avoids its damage")
	game.hero = game.START
	game.invulnerable = 0
	elite.p = game.hero + Vector2(85, 0)
	elite.attack = "slam_warning"
	elite.clock = 0.1
	game._special_attack(elite, 0.11)
	check(game.hp == 57, "remaining in an elite strike takes damage once")
	game.start_run()
	game.begin_stage(2)
	game._apply_upgrade("pulse")
	game.enemies.clear()
	var close: Dictionary = game.make_enemy(game.hero + Vector2(100, 0), "normal")
	var far: Dictionary = game.make_enemy(game.hero + Vector2(230, 0), "normal")
	close.hp = 500
	far.hp = 500
	game.enemies.append(close)
	game.enemies.append(far)
	game.fire_pulse()
	check(close.hp < 500 and close.slow > 0 and far.hp == 500, "automatic pulse damages/slows only enemies within its range")
	game.enemies.clear()
	game.hero = Vector2(700, 128)
	var hidden: Dictionary = game.make_enemy(Vector2(550, 128), "normal")
	hidden.hp = 500
	game.enemies.append(hidden)
	game.fire_pulse()
	check(hidden.hp == 500, "pulse respects solid ward walls")
	game.start_run()
	game.begin_stage(2)
	game._apply_upgrade("pulse")
	game.enemies.clear()
	var lethal: Dictionary = game.make_enemy(game.hero + Vector2(20, 0), "elite")
	lethal.hp = 1
	game.enemies.append(lethal)
	game.hp = 1
	game.invulnerable = 0
	game.pulse_clock = 0
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.LOST, "lethal contact cannot be undone by a later pulse/kill heal in the same tick")
	game.start_run()
	game.begin_stage(2)
	game.elapsed = 180
	game.complete_stage()
	game.step_game(3.3, Vector2.ZERO)
	check(game.stage_index == 3 and game.world.current_theme == 2 and game._kind_count("boss") == 1, "second clear enters the operating-theatre boss stage")
	check(not game.world.blocked(game.START + Vector2(250, 250)), "boss theatre provides an open dodge arena")
	var boss: Dictionary = game.boss_enemy()
	var boss_health: float = boss.hp
	game.elapsed = 180
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.PLAYING and not game.boss_enemy().is_empty(), "third stage cannot be won merely by waiting three minutes")
	game.enemies.clear()
	boss.p = game.hero + Vector2(230, 0)
	boss.attack = "chase"
	boss.clock = 0
	game.enemies.append(boss)
	game._special_attack(boss, 0.01)
	check(boss.attack == "charge_warning" and boss.clock > 0.8, "boss locks a warned charge direction before moving")
	var locked: Vector2 = boss.aim
	game.hero += Vector2(0, 160)
	game._special_attack(boss, 1.0)
	check(boss.attack == "charge" and boss.aim == locked, "boss charge keeps its warned direction when the player dodges")
	# Charge from inside the theatre toward its outer wall: never tunnel through.
	boss.p = Vector2(150, 360)
	boss.aim = Vector2.LEFT
	boss.attack = "charge"
	boss.clock = 0.55
	game._special_attack(boss, 0.5)
	check(boss.p.x >= 110 and not game.world.blocked(boss.p, 22), "boss dash collides with arena walls")
	boss.p = game.hero + Vector2(200, 0)
	boss.attack = "chase"
	boss.attack_number = 1
	boss.clock = 0
	game._special_attack(boss, 0.01)
	check(boss.attack == "slam_warning", "boss alternates charge and area strike")
	boss.hp = boss_health * 0.4
	boss.attack = "recover"
	boss.clock = 0
	game._special_attack(boss, 0.01)
	check(boss.clock < 3, "boss accelerates its attack cycle below half health")
	game.start_run()
	game.begin_stage(3)
	for i in range(game.MAX_ENEMIES - 1):
		game.enemies.append(game.make_enemy(game.hero + Vector2(800, 0), "normal"))
	check(not game.spawn_enemy("boss") and game._kind_count("boss") == 1, "boss cannot be duplicated")
	game.enemies = game.enemies.filter(func(e: Dictionary) -> bool: return e.kind != "boss")
	game.enemies.append(game.make_enemy(game.hero + Vector2(800, 0), "normal"))
	check(game.spawn_enemy("boss") and game.enemies.size() == game.MAX_ENEMIES, "boss spawn reserves a slot even at the normal enemy cap")
	boss = game.boss_enemy()
	boss.hp = 400
	boss.p = game.hero + Vector2(5000, 0)
	game._update_enemies(0.01)
	check(game._kind_count("boss") == 1 and game.boss_enemy().hp == 400 and game.boss_enemy().p.distance_to(game.hero) < 1000, "boss remains alive and keeps health after off-screen repositioning")
	game._damage_enemy(boss, 1000)
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.REST and game.cleared_stages == 3 and game.has_checkpoint(), "boss defeat finishes stage three at a saved workshop")
	game.start_run()
	check(game.stage_index == 1 and game.cleared_stages == 0 and not game.boss_spawned and not game.boss_defeated and not game.pulse_unlocked() and game.shockwaves.is_empty(), "new campaign clears stages, special attacks and unlocks")
	for seed_value in [261023, 71023, 909]:
		_campaign(seed_value)
	print("STAGE TESTS COMPLETE | ", checks, " checks | ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _campaign(seed_value: int) -> void:
	game.start_run()
	game.rng.seed = seed_value
	var route := [Vector2(2304, 576), Vector2(2304, 1728), Vector2(768, 1728), Vector2(768, 576)]
	var waypoint := 0
	var peak := 0
	var ticks := Time.get_ticks_msec()
	for i in range(9000):
		choose_build_upgrade()
		if game.mode in [game.Mode.REST, game.Mode.LOST]:
			break
		var direction := Vector2.ZERO
		if game.stage_index < 3:
			if game.hero.distance_to(route[waypoint]) < 30:
				waypoint = (waypoint + 1) % route.size()
			direction = game.hero.direction_to(route[waypoint])
		else:
			var target: Vector2 = game.START + Vector2.from_angle(game.elapsed) * 255
			direction = game.hero.direction_to(target)
		game.step_game(0.1, direction)
		peak = maxi(peak, game.enemies.size())
	check(game.mode == game.Mode.REST and game.cleared_stages == 3, "normal movement/auto-attack completes the first sector for seed %d" % seed_value)
	check(peak <= game.MAX_ENEMIES and game.world.chunks.size() == 9 and game.particles.size() <= 240 and game.gems.size() <= 180 and game.arsenal.projectiles.size() <= 128 and game.arsenal.effects.size() <= 80, "three-stage campaign stays within entity bounds for seed %d" % seed_value)
	print("CAMPAIGN | seed=", seed_value, " stage=", game.stage_index, " hp=", game.hp, " kills=", game.kills, " level=", game.level, " total_s=", game.total_elapsed, " peak=", peak, " simulation_ms=", Time.get_ticks_msec() - ticks, " weapons=", game.progression.weapons, " supplies=", game.progression.supplies)
	game.leave_workshop()
	check(game.stage_index == 4 and game.mode == game.Mode.PLAYING, "completed sector continues into stage four for seed %d" % seed_value)

func choose_build_upgrade() -> void:
	# Only offered choices are selected: full campaigns use normal combat rules.
	if game.mode != game.Mode.CHOOSING:
		return
	var priority := {"syringe": 120, "lightning": 96, "pulse": 94, "guardian": 92,
		"rocket": 90, "soccer": 88, "brick": 86, "cooldown": 82, "attack": 78,
		"regen": 76, "health": 72, "speed": 68, "duration": 62,
		"drone_a": 60, "drone_b": 59, "area": 55, "armor": 50,
		"projectile": 40, "experience": 38, "magnet": 35, "gold": 10}
	while game.mode == game.Mode.CHOOSING:
		var best := 0
		var best_score := -1
		for i in range(game.upgrade_choices.size()):
			var id: String = game.upgrade_choices[i]
			var score: int = priority.get(id, 0)
			if game.progression.can_evolve(id):
				score += 150
			if id == "experience" and game.progression.get_level(id) == 0:
				score = 112
			if id == "magnet" and game.progression.get_level(id) == 0:
				score = 100
			if id == "duration" and game.progression.get_level("guardian") >= 4 and game.progression.get_level(id) == 0:
				score = 110
			if score > best_score:
				best = i
				best_score = score
		game.choose_upgrade(best)
