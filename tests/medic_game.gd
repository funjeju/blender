extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.hero_frames.get_animation_names().size() == 6)
	for clip in game.hero_frames.get_animation_names():
		assert(game.hero_frames.get_frame_count(clip) == 4)
		assert(game.hero_frames.get_animation_loop(clip))
		assert(game.hero_frames.get_animation_speed(clip) == (4.0 if clip.ends_with("idle") else 8.0))
	var inputs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var views := ["east", "west", "north", "south", "east", "west", "east", "west"]
	for i in range(inputs.size()):
		game.start_run()
		game.fire_clock = 999
		game.spawn_clock = 999
		game.step_game(0.016, inputs[i].normalized())
		assert(game.hero_view() == views[i])
		assert(game.hero_animation == "walk" and game.hero_frame_index() == 0)
		assert(game.hero_draw_angle() == 0.0)
		assert(game.hero_draw_scale().y == 1.0)
		assert(game.hero_draw_scale().x == (-1.0 if views[i] == "west" else 1.0))
		game.step_game(0.126, inputs[i].normalized())
		assert(game.hero_frame_index() == 1)
		if i < 4 and DisplayServer.get_name() != "headless":
			game.camera.position = game.hero
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://test-output/medic-game-" + views[i] + ".png") == OK)
	game.step_game(0.016, Vector2.ZERO)
	assert(game.hero_animation == "idle" and game.hero_frame_index() == 0)
	game.step_game(0.26, Vector2.ZERO)
	assert(game.hero_frame_index() == 1)
	game.step_game(0.75, Vector2.ZERO)
	assert(game.hero_frame_index() == 0)
	game.mode = game.Mode.PAUSED
	var phase: float = game.hero_animation_time
	game.step_game(1.0, Vector2.RIGHT)
	assert(game.hero_animation_time == phase)
	game.start_run()
	game.spawn_clock = 999
	game.enemies.append(game.make_enemy(game.hero + Vector2(210, 0), "normal"))
	game.fire_clock = 0
	game.step_game(0.06, Vector2.LEFT)
	assert(game.hero_view() == "east" and game.hero_clip() == "east_walk")
	assert(game.hero_draw_angle() == 0.0 and game.hero_draw_scale().y == 1.0)
	game.start_run()
	assert(game.hero_animation == "idle" and game.hero_frame_index() == 0)
	print("MEDIC_GAME_PASS | six clips, eight movement vectors upright, horizontal-only reflection, 4/8fps, loops, stop/pause/reset, shot-facing view")
	game.queue_free()
	await process_frame
	quit()
