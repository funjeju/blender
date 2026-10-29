extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.touch_direction = Vector2(1, -1).normalized()
	assert(game.movement_input().is_equal_approx(game.touch_direction))
	game.complete_stage()
	var remaining: float = game.transition_left
	game.pause_run()
	assert(game.mode == game.Mode.PAUSED and game.touch_direction == Vector2.ZERO)
	game.step_game(1, Vector2.ZERO)
	assert(game.transition_left == remaining)
	game.resume_run()
	assert(game.mode == game.Mode.TRANSITION)
	game.step_game(3.3, Vector2.ZERO)
	assert(game.stage_index == 2 and game.mode == game.Mode.PLAYING)
	game.kills = 7
	assert(game.ranking_score() == 10700)
	game.cleared_stages = 3
	game.total_elapsed = 400.5
	game.finish(true)
	assert(game.ranking_score() == 35700)
	assert(game.hud.font.has_char("병".unicode_at(0)))
	game.free()
	await process_frame
	print("DISTRIBUTION_PASS | transition pause/resume, touch, scoring, Korean font")
	quit()
