extends SceneTree
## Deterministic renderer captures for the local survivor rules and inventory UI.
## Run with the normal renderer, not --headless. Never writes player records.
var game

func _initialize() -> void:
	_run.call_deferred()

func snap(name: String) -> void:
	game.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://test-output/survivor-" + name + ".png"
	var result := root.get_texture().get_image().save_png(path)
	assert(result == OK, "Could not save screenshot: " + path)
	print("CAPTURE ", path)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	game.muted = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.rng.seed = 261025
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await process_frame
	await snap("title")
	game.start_run()
	game.elapsed = 32
	game.total_elapsed = 32
	game.level = 4
	game.kills = 37
	game.xp = 13
	game.upgrade_choices.assign(["syringe", "rocket", "experience"])
	game.mode = game.Mode.CHOOSING
	await snap("choices")
	game.progression.weapons["syringe"] = 5
	game.progression.supplies["experience"] = 1
	game.upgrade_choices.assign(["syringe", "guardian", "health"])
	await snap("evolution")
	game.progression.weapons = {"syringe": 6, "guardian": 5, "lightning": 4, "rocket": 3, "soccer": 2, "destroyer": 6}
	game.progression.supplies = {"experience": 5, "duration": 2, "cooldown": 4, "area": 3, "speed": 1, "health": 2}
	game._recompute_stats()
	game.level = 25
	game.elapsed = 112
	game.total_elapsed = 292
	game.coins = 170
	game.hp = game.max_hp * 0.72
	game.kills = 243
	game.xp = 21
	game.upgrade_choices.clear()
	game.mode = game.Mode.PLAYING
	game.banner_left = 0
	game.camera.position = game.hero
	await snap("inventory")
	game.mode = game.Mode.PAUSED
	await snap("pause")
	game.mode = game.Mode.PLAYING
	game.enemies.clear()
	var kinds := ["normal", "runner", "tank", "elite"]
	for i in range(16):
		var angle := float(i) / 16 * TAU
		var point: Vector2 = game.hero + Vector2.from_angle(angle) * (190 + (i % 3) * 72)
		# Leave the lower corridor clear so every drop remains inspectable.
		point.y = minf(point.y, game.hero.y + 110)
		game.enemies.append(game.make_enemy(point, kinds[i % kinds.size()]))
	for i in range(5):
		game._spawn_gem(game.hero + Vector2(-170 + i * 68, 145), 1 if i < 3 else 3)
	var pickups := ["chest", "magnet", "heal", "bomb", "coin"]
	for i in range(pickups.size()):
		game.spawn_pickup(game.hero + Vector2(-290 + i * 145, 245), pickups[i])
	game.arsenal.update(game, 0.12)
	game.fire_pulse()
	game.fire_clock = 0
	game._auto_fire()
	await snap("combat-loot")
	game.begin_stage(3)
	game.enemies.clear()
	var boss: Dictionary = game.make_enemy(game.hero + Vector2(210, -120), "boss")
	boss.attack = "charge_warning"
	boss.clock = 0.65
	boss.aim = boss.p.direction_to(game.hero)
	game.enemies.append(boss)
	game.elapsed = 12
	game.banner_left = 0
	game.pulse_flash = 0
	game.invulnerable = 0
	await snap("boss")
	game.queue_free()
	await process_frame
	quit()
