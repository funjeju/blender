extends SceneTree
## Behavioral checks plus a full normal-rules 180-second survival simulation.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func enemy_at(point: Vector2) -> Dictionary:
	return {"p": point, "hp": 40.0, "max_hp": 40.0, "speed": 75.0, "fast": false, "path": PackedVector2Array(), "repath": 0.0, "flash": 0.0, "phase": 0.0}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func choose_build_upgrade() -> void:
	# Select only offered upgrades, just as a player would; never grant equipment.
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

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(game.mode == game.Mode.READY, "starts on title screen")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "1920x1080 design viewport")
	check(game.sprites.size() == 4 and game.world.props.size() == 4, "both generated atlases are loaded")
	check(not game.world.blocked(game.START), "start position is walkable")
	key(KEY_ENTER)
	check(game.mode == game.Mode.PLAYING, "Enter starts survival")
	var origin: Vector2 = game.hero
	game.step_game(0.1, Vector2.RIGHT)
	var straight: float = game.hero.distance_to(origin)
	game.hero = origin
	game.step_game(0.1, Vector2.ONE)
	check(absf(game.hero.distance_to(origin) - straight) < 0.01, "diagonal speed equals straight speed")
	var p: Vector2 = game.world.move_body(Vector2(352, 492), Vector2(0, -170))
	check(p.y < 400, "open ward doorway can be traversed")
	var blocked: Vector2 = game.world.move_body(Vector2(500, 492), Vector2(0, -170))
	check(blocked.y > 466, "solid ward wall blocks movement")
	check(game.world.blocked(Vector2(165, 204)), "rendered hospital bed has collision")
	var path: PackedVector2Array = game.world.path_to(Vector2(768, 576), Vector2(440, 340))
	check(path.size() > 2, "enemy path connects corridor and ward through doorway")
	var path_clear := true
	for i in range(1, path.size()):
		if not game.world.clear_line(path[i - 1], path[i], 19):
			path_clear = false
	check(path_clear, "enemy path does not clip walls or furniture")
	game.start_run()
	game.enemies.append(enemy_at(game.hero + Vector2(150, 0)))
	for i in range(15):
		game.step_game(0.1, Vector2.ZERO)
	check(game.kills >= 1, "automatic attack kills without attack input")
	check(game.gems.size() > 0 or game.xp > 0, "kills award experience")
	game.start_run()
	game.hero = Vector2(700, 128)
	game.enemies.append(enemy_at(Vector2(550, 128)))
	game._auto_fire()
	check(game.shots.is_empty(), "weapon does not target through a wall")
	game.start_run()
	game.enemies.append(enemy_at(game.hero + Vector2(210, 0)))
	game.fire_clock = 0
	game.step_game(0.06, Vector2.LEFT)
	check(absf(angle_difference(game.body_angle, -PI / 2.0)) < 0.03 and game.aim_direction.x > 0.99, "body turns toward the shot within 60 ms while moving the opposite way")
	game.step_game(0.1, Vector2.LEFT)
	check(absf(angle_difference(game.body_angle, -PI / 2.0)) < 0.03, "aim takes priority over movement between shots")
	game.enemies.clear()
	game.step_game(0.7, Vector2.UP)
	check(absf(angle_difference(game.body_angle, PI)) < 0.03, "body follows movement once the firing aim expires")
	game.start_run()
	game.take_damage(9)
	game.take_damage(9)
	check(game.hp == 91 and game.invulnerable > 0, "damage has invulnerability protection")
	var time_before: float = game.elapsed
	var pos_before: Vector2 = game.hero
	key(KEY_ESCAPE)
	game.step_game(1, Vector2.RIGHT)
	check(game.mode == game.Mode.PAUSED and game.elapsed == time_before and game.hero == pos_before, "pause freezes timer and movement")
	key(KEY_ENTER)
	check(game.mode == game.Mode.PLAYING, "Enter resumes pause")
	key(KEY_M)
	check(game.muted, "mute works")
	game.start_run()
	game.xp = game.xp_needed()
	game._update_gems(0)
	check(game.level == 2 and game.mode == game.Mode.CHOOSING and game.damage == 24 and game.upgrade_choices.size() == 3, "level-up opens three choices before changing the build")
	time_before = game.elapsed
	pos_before = game.hero
	game.step_game(1, Vector2.RIGHT)
	check(game.elapsed == time_before and game.hero == pos_before, "upgrade selection freezes enemies, movement and timer")
	var selected: String = game.upgrade_choices[0]
	var previous_rank: int = game.progression.get_level(selected)
	key(KEY_1)
	check(game.mode == game.Mode.PLAYING and game.progression.get_level(selected) == previous_rank + 1, "number key applies the selected upgrade and resumes play")
	game.elapsed = 60
	check(game.stage() == 2, "difficulty increases at 60 seconds")
	game.elapsed = 120
	check(game.stage() == 3, "difficulty increases at 120 seconds")
	for destination in [Vector2(6000, 576), Vector2(-4500, 576), Vector2(768, 4800), Vector2(768, -3600)]:
		game.world.update_chunks(destination)
		check(game.world.chunks.size() == 9 and not game.world.blocked(destination), "bounded chunks and open corridor at " + str(destination))
	game.start_run()
	game.hp = 1
	game.take_damage(5)
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.LOST, "zero health causes defeat")
	key(KEY_ENTER)
	game.elapsed = 179.98
	game.step_game(0.02, Vector2.ZERO)
	check(game.mode == game.Mode.TRANSITION and game.elapsed == 180 and game.cleared_stages == 1, "180 seconds clears stage one without ending the campaign")
	var finish_time: float = game.elapsed
	game.step_game(1, Vector2.RIGHT)
	check(game.elapsed == finish_time, "stage transition freezes the completed stage timer")
	game.total_elapsed = 180
	game.record_path = "res://test-output/test_records.cfg"
	game.best_time = 0
	game.best_kills = 0
	game.best_stage = 0
	game.testing = false
	game.kills = 42
	game.finish(true)
	game.best_time = 0
	game.best_kills = 0
	game._load_records()
	check(game.best_time == 180 and game.best_kills >= 42, "local records survive a save and reload")
	game.testing = true
	for restart in range(3):
		game.start_run()
		check(game.hp == 100 and game.elapsed == 0 and game.enemies.is_empty() and game.shots.is_empty() and game.gems.is_empty() and game.hero == game.START and game.level == 1 and game.camera.position == game.START, "restart %d clears state" % (restart + 1))
	# Full run, with no invulnerability override, using only corridor movement.
	var route := [Vector2(2304, 576), Vector2(2304, 1728), Vector2(768, 1728), Vector2(768, 576)]
	var waypoint := 0
	var max_enemies := 0
	var ticks := Time.get_ticks_msec()
	game.rng.seed = 261023
	for i in range(1801):
		choose_build_upgrade()
		if game.mode != game.Mode.PLAYING:
			break
		if game.hero.distance_to(route[waypoint]) < 30:
			waypoint = (waypoint + 1) % route.size()
		game.step_game(0.1, game.hero.direction_to(route[waypoint]))
		max_enemies = maxi(max_enemies, game.enemies.size())
	check(game.mode == game.Mode.TRANSITION and game.cleared_stages == 1, "normal rules allow a full first-stage survival")
	check(max_enemies <= game.MAX_ENEMIES and game.world.chunks.size() == 9 and game.particles.size() <= 240 and game.gems.size() <= 180 and game.arsenal.projectiles.size() <= 128 and game.arsenal.effects.size() <= 80, "entity and chunk counts remain bounded")
	print("FULL RUN | hp=", game.hp, " kills=", game.kills, " level=", game.level, " peak_enemies=", max_enemies, " simulation_ms=", Time.get_ticks_msec() - ticks)
	print("SMOKE COMPLETE | ", checks, " checks | ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

