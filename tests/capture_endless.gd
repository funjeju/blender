extends SceneTree
## Deterministic native captures for endless progression. Local assets only.
## Uses a disposable project-local campaign path and never player saves.
var game

func _initialize() -> void:
	_run.call_deferred()

func snap(name: String) -> void:
	game.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://test-output/endless-" + name + ".png"
	assert(root.get_texture().get_image().save_png(path) == OK, "Capture failed: " + path)
	print("CAPTURE ", path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	game.muted = true
	game.campaign.path = "res://test-output/endless-capture-profile.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.rng.seed = 261025
	game.campaign.checkpoint = {}
	game.campaign.profile = {
		"materials": 0, "equipment": {"coat": 0, "gloves": 0, "boots": 0},
		"highest_stage": 1, "rewarded_sector": 0, "reward_run_id": "",
	}
	await process_frame
	await snap("title")
	game.start_run()
	game.progression.weapons = {"syringe": 6, "guardian": 6, "lightning": 6, "rocket": 6, "soccer": 6, "destroyer": 6}
	game.progression.supplies = {"experience": 5, "duration": 5, "cooldown": 5, "area": 5, "speed": 5, "health": 5}
	game.progression.mastery = {"syringe": 7, "guardian": 4, "lightning": 3, "rocket": 3}
	game.progression.traits = {"syringe": "focus", "guardian": "blast"}
	game.campaign.profile.materials = 42
	game.campaign.profile.equipment = {"coat": 2, "gloves": 3, "boots": 1}
	game.campaign.profile.highest_stage = 7
	game._recompute_stats()
	game.level = 52
	game.kills = 1684
	game.coins = 870
	game.total_elapsed = 811
	game.xp = 21
	game.begin_stage(6)
	game.enemies.clear()
	game.upgrade_choices.assign(["mastery:syringe", "trait:lightning:focus", "trait:rocket:blast"])
	game.mode = game.Mode.CHOOSING
	game.banner_left = 0
	await snap("mastery")
	game.upgrade_choices.clear()
	game.mode = game.Mode.PAUSED
	await snap("loadout")
	game.mode = game.Mode.PLAYING
	game.boss_defeated = true
	game.complete_stage()
	await snap("rest")
	game.checkpoint_pending = true
	game.campaign.error_message = "저장 폴더에 쓸 수 없습니다. 권한을 확인한 뒤 다시 시도해 주세요."
	await snap("save-retry")
	game.checkpoint_pending = false
	game.campaign.error_message = ""
	game.return_to_title()
	await snap("resume")
	game.open_workshop()
	await snap("workshop")
	game.return_to_title()
	assert(game.continue_checkpoint(), "Capture needs checkpoint resume")
	game.elapsed = 34
	game.banner_left = 0
	game.invulnerable = 0
	var kinds := ["normal", "tank", "ranged", "rusher", "fast", "elite"]
	for index in range(12):
		var point: Vector2 = game.hero + Vector2.from_angle(index * TAU / 12) * (230 + (index % 3) * 48)
		game.enemies.append(game.make_enemy(point, kinds[index % kinds.size()]))
	await snap("stage7")
	game.finish(false)
	await snap("defeat-checkpoint")
	game.begin_stage(6)
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
	await snap("boss6")
	game.queue_free()
	await process_frame
	quit()
