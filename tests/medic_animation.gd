extends SceneTree
## Validate the actual asset and AnimatedSprite2D playback, not source spec alone.

var changes := 0
var loops := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var pack: SpriteFrames = load("res://assets/sprites/medic_idle_walk_v1/sprites.tres")
	assert(pack != null)
	assert(pack.get_animation_names() == PackedStringArray(["idle", "walk"]))
	for state in ["idle", "walk"]:
		assert(pack.get_frame_count(state) == 4)
		assert(pack.get_animation_speed(state) == (4.0 if state == "idle" else 8.0))
		assert(pack.get_animation_loop(state))
		var hashes: Array[String] = []
		for index in range(4):
			assert(is_equal_approx(pack.get_frame_duration(state, index), 1.0))
			var image := pack.get_frame_texture(state, index).get_image()
			assert(image.get_size() == Vector2i(256, 256))
			assert(image.is_invisible() == false)
			assert(image.get_pixel(0, 0).a == 0)
			var fingerprint := image.get_data().hex_encode().md5_text()
			assert(not hashes.has(fingerprint), "Duplicate frame in " + state)
			hashes.append(fingerprint)
	var preview = load("res://scenes/medic_animation_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	assert(preview.state_picker.item_count == 2)
	assert(preview.actor.animation == "idle")
	preview.actor.frame_changed.connect(func() -> void: changes += 1)
	preview.actor.animation_looped.connect(func() -> void: loops += 1)
	for index in range(2):
		var state := "idle" if index == 0 else "walk"
		preview.state_picker.select(index)
		preview.select_state(index)
		changes = 0
		loops = 0
		await create_timer(1.12).timeout
		assert(changes >= (4 if index == 0 else 8))
		assert(loops >= (1 if index == 0 else 2))
		preview.toggle_play()
		var stopped_frame: int = preview.actor.frame
		await create_timer(0.3).timeout
		assert(preview.actor.frame == stopped_frame)
		assert(not preview.actor.is_playing())
		preview.background_mode = 1
		preview.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://test-output/medic-" + state + "-preview.png") == OK)
		preview.toggle_play()
		assert(preview.actor.is_playing())
	print("MEDIC_ANIMATION_PASS | eight unique frames, alpha, 4/8fps, loops, state switching, pause/resume, actual rendered captures")
	preview.queue_free()
	await process_frame
	quit()
