extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run()
	game.audio.sync(false, false, false, 0.0)
	game.audio.select_music(1)
	assert(game.audio.music.stream != null)
	game.testing = false
	game.pause_run("focus")
	assert(game.audio.music.stream_paused)
	assert(not game.audio.ui_voice.playing)
	# No process frame was needed to silence audio on native focus loss.
	game.testing = true
	game.resume_run()
	for won in [false, true]:
		game.start_run()
		game.audio.select_music(1)
		assert(game.audio.music.stream != null)
		game.finish(won)
		assert(game.audio.music.stream == null)
		game.audio.sync(false, false, false, 0.1)
		assert(not game.audio.music.playing)
		game._process(0.1)
		assert(game.audio.music.stream == null)
	game.free()
	game = null
	await create_timer(0.25).timeout
	print("BACKGROUND_AUDIO_PASS | immediate native focus pause, no UI cue, victory/loss music never restarts")
	quit()
