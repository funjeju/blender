extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio = load("res://scripts/hospital_audio.gd").new()
	add_child(audio)
	audio.select_music(1)
	audio.play_event("shoot")
	await get_tree().create_timer(0.5).timeout
	var position: float = audio.music.get_playback_position()
	print("AUDIO_RUNTIME | playing=", audio.music.playing, " pos=", position, " length=", audio.music.stream.get_length())
	assert(audio.music.playing and position > 0.1)
	audio.sync(false, true, false, 0.016)
	await get_tree().create_timer(0.2).timeout
	assert(audio.music.stream_paused)
	assert(absf(audio.music.get_playback_position() - position) < 0.04)
	audio.sync(false, false, false, 0.016)
	await get_tree().create_timer(0.2).timeout
	assert(audio.music.get_playback_position() > position + 0.05)
	audio.sync(true, false, false, 0.016)
	assert(not audio.music.playing)
	print("AUDIO_RUNTIME_PASS | MP3 real-time playback advances; pause, resume and mute work")
	var report := FileAccess.open("res://test-output/audio-runtime.txt", FileAccess.WRITE)
	report.store_string("AUDIO_RUNTIME_PASS | position after 0.5s: %s | length: %s | pause/resume/mute verified" % [position, audio.music.stream.get_length()])
	report.close()
	audio.queue_free()
	await get_tree().create_timer(8.0).timeout
	get_tree().quit()
