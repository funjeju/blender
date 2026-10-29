extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio = load("res://scripts/hospital_audio.gd").new()
	root.add_child(audio)
	await process_frame
	assert(audio.library.size() == 22)
	assert(audio.voices.size() == 16)
	for event in audio.library:
		for stream in audio.library[event]:
			assert(stream != null and stream.get_length() > 0)
	assert(absf(audio.library.charge_warning[0].get_length() - 0.95) < 0.002)
	assert(absf(audio.library.elite_warning[0].get_length() - 0.85) < 0.002)
	assert(audio.play_event("shoot"))
	assert(not audio.play_event("shoot"))
	audio.stop_all()
	# Saturate ordinary slots; reserved warning slots must still be available.
	for i in range(12):
		audio.voices[i].player.stream = audio.library.pulse[0]
		audio.voices[i].player.play()
		audio.voices[i].priority = 1
	assert(audio.play_event("charge_warning"))
	assert(audio.voices[12].player.playing)
	audio.select_music(1)
	assert(audio.music.stream is AudioStreamMP3)
	assert(audio.music.stream.loop)
	assert(audio.music.stream.get_length() > 170 and audio.music.stream.get_length() < 190)
	await create_timer(0.25).timeout
	print("MP3_PLAYBACK | playing=", audio.music.playing, " pos=", audio.music.get_playback_position(), " length=", audio.music.stream.get_length())
	assert(audio.music.playing and audio.music.get_playback_position() > 0.05)
	var previous: AudioStream = audio.music.stream
	var position: float = audio.music.get_playback_position()
	audio.select_music(2)
	assert(audio.music.stream == previous and audio.music.get_playback_position() >= position)
	audio.sync(false, true, false, 0.016)
	assert(audio.music.stream_paused)
	position = audio.music.get_playback_position()
	await create_timer(0.15).timeout
	assert(absf(audio.music.get_playback_position() - position) < 0.03)
	audio.sync(false, false, false, 0.016)
	assert(not audio.music.stream_paused)
	audio.sync(true, false, false, 0.016)
	assert(not audio.music.playing and not audio.play_event("player_hit"))
	for voice in audio.voices:
		assert(not voice.player.playing)
	audio.sync(false, false, true, 0.016)
	assert(not audio.play_event("pulse"))
	print("AUDIO_PASS | 33 WAV / 22 events, warning durations, cooldowns, reserved voices, MP3 decode/playback/loop, stage continuity, pause/resume, mute, test silence | bgm_s=", previous.get_length())
	audio.queue_free()
	previous = null
	audio = null
	await create_timer(0.2).timeout
	quit()
