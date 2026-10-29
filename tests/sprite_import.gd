extends SceneTree
## Verify generated resources in Godot, including unequal frame timings.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "res://assets/sprites/reference_medic/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "manifest.json"))
	var frames: SpriteFrames = load(path + "sprites.tres")
	assert(frames != null)
	var rows: Dictionary = manifest.frame_layout.rows
	assert(frames.get_animation_names().size() == rows.size())
	for name_text in rows:
		var info: Dictionary = manifest.animation.rows[name_text]
		assert(frames.get_frame_count(name_text) == rows[name_text].size())
		assert(is_equal_approx(frames.get_animation_speed(name_text), info.fps))
		assert(frames.get_animation_loop(name_text) == info.loop)
		for index in range(rows[name_text].size()):
			var texture: AtlasTexture = frames.get_frame_texture(name_text, index)
			var r: Dictionary = rows[name_text][index]
			assert(texture.region == Rect2(r.x, r.y, r.w, r.h))
			assert(not texture.get_image().is_empty())
			assert(is_equal_approx(frames.get_frame_duration(name_text, index), info.durations_ms[index] * info.fps / 1000.0))
	var timing: SpriteFrames = load("res://test-output/sprite-timing-fixture.tres")
	assert(timing.get_frame_count("timing_test") == 3)
	assert(not timing.get_animation_loop("timing_test"))
	assert(is_equal_approx(timing.get_animation_speed("timing_test"), 8.0))
	for i in range(3):
		assert(is_equal_approx(timing.get_frame_duration("timing_test", i), [0.8, 2.0, 4.0][i]))
	print("SPRITE_IMPORT_PASS | rectangles, alpha, loop, fps and unequal durations")
	quit()
