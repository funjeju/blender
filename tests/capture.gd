extends SceneTree
## Real renderer captures; controlled scene states complement behavioral tests.
var game

func _initialize() -> void:
	_run.call_deferred()

func snap(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + name + ".png")
	print("CAPTURE ", name)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	game.rng.seed = 261023
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await create_timer(0.3).timeout
	await snap("hospital-title")
	game.start_run()
	game.enemies.append(game.make_enemy(game.hero + Vector2(210, 0), "normal"))
	game.fire_clock = 0
	game.step_game(0.06, Vector2.LEFT)
	await snap("hospital-aim-right")
	game.start_run()
	game.elapsed = 75
	for i in range(28):
		game.spawn_enemy()
	for i in range(70):
		game.step_game(0.1, Vector2.ZERO)
	game.hp = 84
	game.camera.position = game.hero
	await snap("hospital-play")
	game.elapsed = 180
	game.complete_stage()
	await snap("stage-1-clear")
	game.step_game(3.3, Vector2.ZERO)
	game.level = 8
	game.damage = 73
	game.fire_interval = 0.22
	game.elapsed = 70
	game.total_elapsed = 250
	game.banner_left = 0
	game.invulnerable = 0
	game.enemies.clear()
	var elite = game.make_enemy(game.hero + Vector2(245, 0), "elite")
	elite.attack = "slam_warning"
	elite.clock = 0.5
	game.enemies.append(elite)
	game.enemies.append(game.make_enemy(game.hero + Vector2(-220, 20), "elite"))
	for i in range(12):
		game.spawn_enemy()
	game.pulse_flash = 0.25
	await snap("stage-2-elites")
	game.start_run()
	game.begin_stage(2)
	game.elapsed = 140
	game.banner_left = 0
	for i in range(game.MAX_ENEMIES - 2):
		game.spawn_enemy("elite" if i < 4 else "")
	game.set_physics_process(true)
	await create_timer(1.2).timeout
	var frames: Array[float] = []
	var simulation_samples: Array[float] = []
	for i in range(240):
		var start := Time.get_ticks_usec()
		await process_frame
		frames.append(float(Time.get_ticks_usec() - start) / 1000.0)
		simulation_samples.append(game.measured_step_us / 1000.0)
	game.set_physics_process(false)
	frames.sort()
	var total := 0.0
	for value in frames:
		total += value
	print("P2 PERFORMANCE | enemies=", game.enemies.size(), " elites=", game._kind_count("elite"), " mode=", game.mode, " mean_ms=", total / frames.size(), " p95_ms=", frames[227], " fps=", 1000.0 / (total / frames.size()))
	print("PROFILE | physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var simulation_total := 0.0
	for value in simulation_samples:
		simulation_total += value
	simulation_samples.sort()
	print("SIMULATION COST | mean_ms=", simulation_total / simulation_samples.size(), " p95_ms=", simulation_samples[227])
	await snap("stage-2-stress")
	game.elapsed = 180
	game.complete_stage()
	await snap("stage-2-clear")
	game.step_game(3.3, Vector2.ZERO)
	game.enemies.clear()
	game.elapsed = 14
	game.total_elapsed = 374
	game.level = 16
	game.damage = 129
	game.hp = 82
	game.banner_left = 0
	var boss = game.make_enemy(game.hero + Vector2(220, -110), "boss")
	boss.attack = "charge_warning"
	boss.clock = 0.65
	boss.aim = boss.p.direction_to(game.hero)
	game.enemies.append(boss)
	game.fire_clock = 0
	game.step_game(0.06, Vector2.LEFT)
	await snap("stage-3-boss-charge")
	boss.p = game.hero + Vector2(180, 0)
	boss.hp = boss.max_hp * 0.42
	boss.attack = "slam_warning"
	boss.clock = 0.45
	game.pulse_flash = 0.28
	await snap("stage-3-boss-slam")
	game._damage_enemy(boss, boss.max_hp)
	game.step_game(0.01, Vector2.ZERO)
	await snap("hospital-win")
	game.start_run()
	game.begin_stage(2)
	game.total_elapsed = 262
	game.elapsed = 82
	game.hp = 0
	game.finish(false)
	await snap("hospital-loss")
	game.queue_free()
	await process_frame
	quit()
