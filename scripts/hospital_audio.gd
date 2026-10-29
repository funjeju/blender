extends Node
## Bounded local effects; optional user-supplied music. No network or providers.

const VOICE_LIMIT := 16
const RESERVED := 4
const EVENTS := {
	"shoot": [3, -20.0, 1, 0.07], "impact": [3, -23.0, 1, 0.06],
	"enemy_down": [2, -23.0, 1, 0.10], "player_hit": [2, -12.0, 4, 0.15],
	"pickup": [4, -25.0, 1, 0.065], "level": [1, -13.0, 3, 0.3],
	"pulse": [1, -17.0, 2, 0.4], "elite_warning": [1, -11.0, 4, 0.18],
	"charge_warning": [1, -9.0, 5, 0.2], "boss_slam_warning": [1, -10.0, 5, 0.2],
	"dash": [1, -14.0, 3, 0.3], "slam": [1, -12.0, 4, 0.15],
	"enrage": [1, -12.0, 5, 1.0], "boss_intro": [1, -13.0, 5, 1.0],
	"stage_clear": [1, -13.0, 5, 1.0], "victory": [1, -11.0, 5, 1.0],
	"loss": [1, -13.0, 5, 1.0], "ui": [1, -20.0, 2, 0.05],
	"start": [1, -17.0, 3, 0.15], "pause": [1, -20.0, 3, 0.1],
	"resume": [1, -20.0, 3, 0.1], "step": [3, -29.0, 0, 0.12]
}

var library: Dictionary = {}
var voices: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var random := RandomNumberGenerator.new()
var muted := false
var paused := false
var disabled := false
var music: AudioStreamPlayer
var ui_voice: AudioStreamPlayer
var music_stage := -1
var duck_left := 0.0

func _exit_tree() -> void:
	stop_all()
	for voice in voices:
		voice.player.stream = null
	music.stream = null
	ui_voice.stream = null
	voices.clear()
	library.clear()

func _ready() -> void:
	random.randomize()
	for event in EVENTS:
		var streams: Array[AudioStream] = []
		for i in range(EVENTS[event][0]):
			streams.append(load("res://assets/audio/sfx/%s_%d.wav" % [event, i]))
		library[event] = streams
	for i in range(VOICE_LIMIT):
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append({"player": player, "priority": -1})
	ui_voice = AudioStreamPlayer.new()
	ui_voice.volume_db = -20
	add_child(ui_voice)
	music = AudioStreamPlayer.new()
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	music.volume_db = -23
	add_child(music)
	music.finished.connect(func() -> void:
		if not muted and not disabled and not paused and music.stream != null:
			music.play())

func sync(is_muted: bool, is_paused: bool, is_testing: bool, dt: float, play_ui_cue: bool = true) -> void:
	var pause_changed := is_paused != paused
	if (is_muted and not muted) or (is_testing and not disabled):
		stop_all()
	muted = is_muted
	paused = is_paused
	disabled = is_testing
	if pause_changed and not muted and not disabled and play_ui_cue:
		ui_voice.stream = library["pause" if paused else "resume"][0]
		ui_voice.play()
	for voice in voices:
		voice.player.stream_paused = paused
	music.stream_paused = paused
	duck_left = maxf(0.0, duck_left - dt)
	music.volume_db = move_toward(music.volume_db, -29.0 if duck_left > 0 else -23.0, dt * 16.0)
	if not muted and not disabled and not paused and music.stream != null and not music.playing:
		music.play()

func stop_all() -> void:
	for voice in voices:
		voice.player.stop()
	music.stop()
	ui_voice.stop()
	cooldowns.clear()

func play_event(event: String, distance: float = 0.0) -> bool:
	if muted or paused or disabled or not EVENTS.has(event) or distance > 1000:
		return false
	var spec: Array = EVENTS[event]
	var now := Time.get_ticks_msec() / 1000.0
	if now < cooldowns.get(event, -100.0) + spec[3]:
		return false
	var priority: int = spec[2]
	var selected := -1
	# Ordinary rapid sounds cannot occupy the four warning/damage/stinger slots.
	var count := VOICE_LIMIT if priority >= 3 else VOICE_LIMIT - RESERVED
	for i in range(count):
		if not voices[i].player.playing:
			selected = i
			break
	if selected < 0 and priority >= 3:
		var lowest := priority
		for i in range(VOICE_LIMIT):
			if voices[i].priority < lowest:
				lowest = voices[i].priority
				selected = i
	if selected < 0:
		return false
	cooldowns[event] = now
	var voice: Dictionary = voices[selected]
	voice.priority = priority
	var player: AudioStreamPlayer = voice.player
	player.stop()
	player.stream = library[event][random.randi_range(0, library[event].size() - 1)]
	# Telegraph lengths are exact; variation comes from authored takes, never pitch-shifting warnings.
	player.pitch_scale = 1.0
	player.volume_db = float(spec[1]) - minf(14.0, distance / 80.0)
	player.play()
	if priority >= 4:
		duck_left = maxf(duck_left, 1.1)
	return true

func select_music(stage: int) -> void:
	if stage == music_stage:
		return
	music_stage = stage
	var name_text := "title" if stage == 0 else "stage_%d" % stage
	var selected := ""
	for candidate in ([name_text, "default"] if stage > 0 else [name_text]):
		for extension in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/bgm/%s.%s" % [candidate, extension]
			if ResourceLoader.exists(path):
				selected = path
				break
		if not selected.is_empty():
			break
	# A shared combat track continues through stage changes without restarting.
	if music.stream != null and music.stream.resource_path == selected:
		return
	music.stop()
	music.stream = null
	if not selected.is_empty():
		music.stream = load(selected)
		if music.stream is AudioStreamOggVorbis or music.stream is AudioStreamMP3:
			music.stream.loop = true
		elif music.stream is AudioStreamWAV:
			music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			music.stream.loop_end = -1
	if music.stream != null and not muted and not disabled and not paused:
		music.play()
