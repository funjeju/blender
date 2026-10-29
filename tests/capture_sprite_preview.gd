extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func capture(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + name_text + ".png")

func _run() -> void:
	var preview = load("res://scenes/sprite_preview.tscn").instantiate()
	root.add_child(preview)
	await create_timer(0.3).timeout
	assert(preview.state_picker.item_count == 2)
	await capture("sprite-lab-checker")
	preview.state_picker.select(1)
	preview.select_state(1)
	assert(preview.actor.animation == "south_idle")
	preview.toggle_play()
	assert(not preview.actor.is_playing())
	preview.toggle_play()
	preview.background_mode = 1
	preview.queue_redraw()
	await capture("sprite-lab-white")
	preview.background_mode = 2
	preview.queue_redraw()
	await capture("sprite-lab-dark")
	print("SPRITE_PREVIEW_PASS | state switch, pause/resume, checker, light and dark captures")
	preview.queue_free()
	await process_frame
	quit()
