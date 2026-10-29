extends Node2D

const PlayerScene := preload("res://scenes/player.tscn")
const HudScript := preload("res://scripts/hud.gd")
const WORLD_END := 3500.0
const START := Vector2(105, 500)
const CHECKPOINT := Vector2(1705, 390)
const GOAL := Vector2(3300, 380)
const PLATFORMS := [
	Rect2(0, 500, 390, 200), Rect2(480, 445, 170, 65),
	Rect2(740, 375, 160, 70), Rect2(990, 440, 210, 70),
	Rect2(1270, 365, 210, 70), Rect2(1570, 390, 350, 90),
	Rect2(2010, 320, 180, 70), Rect2(2280, 390, 170, 70),
	Rect2(2540, 315, 180, 70), Rect2(2810, 360, 180, 70),
	Rect2(3080, 380, 420, 220)
]
const GEMS := [Vector2(295, 455), Vector2(565, 400), Vector2(820, 330),
	Vector2(1095, 395), Vector2(1390, 320), Vector2(1825, 345),
	Vector2(2100, 275), Vector2(2365, 345), Vector2(2630, 270), Vector2(2900, 315)]
const SPIKES := [Rect2(1130, 420, 45, 20), Rect2(1860, 370, 42, 20), Rect2(2400, 370, 36, 20)]

var player: CharacterBody2D
var camera: Camera2D
var hud: Node2D
var collected: Array[int] = []
var checkpoint_active := false
var won := false
var paused := false
var elapsed := 0.0
var deaths := 0
var clock := 0.0
var notice := "Find your way to the lighthouse."
var notice_time := 5.0
var motes: Array[Dictionary] = []
var sounds: Dictionary = {}
var audio: AudioStreamPlayer

func _ready() -> void:
	_install_inputs()
	for rect in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = rect.position
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.size / 2
		body.add_child(shape)
		add_child(body)
	player = PlayerScene.instantiate()
	player.position = START
	add_child(player)
	player.jumped.connect(func(): _burst(player.position, Color("c4f4db"), 7); _sound("jump"))
	player.landed.connect(func(): _burst(player.position, Color("b9d2b6"), 6))
	camera = Camera2D.new()
	camera.position = Vector2(576, 324)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Node2D.new()
	hud.set_script(HudScript)
	hud.game = self
	layer.add_child(hud)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -17
	add_child(audio)
	for key in ["jump", "gem", "checkpoint", "death", "win"]:
		sounds[key] = _make_tone(key)
	print("SKYBOUND READY | 11 islands, 10 gems, checkpoint, hazards and lighthouse")

func _install_inputs() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "restart": [KEY_R], "pause_game": [KEY_ESCAPE], "confirm": [KEY_ENTER]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in keys[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause_game") and not won:
		set_paused(not paused)
	elif event.is_action_pressed("confirm") and (paused or won):
		if won:
			restart()
		else:
			set_paused(false)

func _physics_process(delta: float) -> void:
	if paused or won:
		return
	elapsed += delta
	if player.position.y > 790:
		respawn()
	for i in range(GEMS.size()):
		if i not in collected and player.position.distance_to(GEMS[i] + Vector2(0, 20)) < 36:
			collected.append(i)
			_burst(GEMS[i], Color("ffd78a"), 16)
			_sound("gem")
	for spike in SPIKES:
		if player.invulnerable <= 0 and spike.grow(-3).intersects(Rect2(player.position - Vector2(11, 34), Vector2(22, 34))):
			respawn()
	if not checkpoint_active and absf(player.position.x - CHECKPOINT.x) < 44 and absf(player.position.y - CHECKPOINT.y) < 60:
		checkpoint_active = true
		notice = "Checkpoint lit. Keep going!"
		notice_time = 3
		_burst(CHECKPOINT - Vector2(0, 50), Color("baf5d1"), 24)
		_sound("checkpoint")
	if player.position.distance_to(GOAL) < 45:
		win()

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		notice_time = maxf(0, notice_time - delta)
		for i in range(motes.size() - 1, -1, -1):
			motes[i].life -= delta
			motes[i].pos += motes[i].vel * delta
			motes[i].vel.y += 240 * delta
			if motes[i].life <= 0:
				motes.remove_at(i)
	camera.position.x = clampf(player.position.x + 170, 576, WORLD_END - 576)
	queue_redraw()
	hud.queue_redraw()

func set_paused(value: bool) -> void:
	paused = value
	player.enabled = not value
	hud.update_overlay()

func respawn() -> void:
	deaths += 1
	_burst(player.position - Vector2(0, 15), Color("f59383"), 20)
	player.reset_at(CHECKPOINT if checkpoint_active else START)
	_sound("death")
	notice = "A new leap. You have this."
	notice_time = 2

func restart() -> void:
	collected.clear()
	checkpoint_active = false
	won = false
	paused = false
	elapsed = 0
	deaths = 0
	motes.clear()
	player.enabled = true
	player.reset_at(START)
	camera.position = Vector2(576, 324)
	camera.reset_smoothing()
	notice = "Find your way to the lighthouse."
	notice_time = 4
	hud.update_overlay()

func win() -> void:
	if won:
		return
	won = true
	player.enabled = false
	player.velocity = Vector2.ZERO
	_burst(GOAL - Vector2(0, 60), Color("ffe5a1"), 70)
	_sound("win")
	hud.update_overlay()
	print("SKYBOUND COMPLETE | gems=%d/10 time=%.2f falls=%d" % [collected.size(), elapsed, deaths])

func _burst(point: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var angle := randf_range(-PI, 0)
		motes.append({"pos": point, "vel": Vector2(cos(angle), sin(angle)) * randf_range(35, 150), "life": randf_range(0.3, 0.8), "color": color})

func _sound(key: String) -> void:
	if DisplayServer.get_name() != "headless":
		audio.stream = sounds[key]
		audio.play()

func _make_tone(key: String) -> AudioStreamWAV:
	var frequencies := {"jump": 440.0, "gem": 880.0, "checkpoint": 660.0, "death": 170.0, "win": 520.0}
	var duration := 0.36 if key in ["win", "checkpoint"] else 0.13
	var data := PackedByteArray()
	var count := int(22050 * duration)
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / 22050
		var hz: float = frequencies[key] * (1.0 + t * (2.0 if key != "death" else -2.0))
		var value := sin(TAU * hz * t) * pow(1.0 - float(i) / count, 2) * minf(t * 100, 1) * 15000
		data.encode_s16(i * 2, int(value))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

func _draw() -> void:
	var left := camera.get_screen_center_position().x - 576
	# Parallax landscape, drawn locally without external textures.
	draw_polygon(PackedVector2Array([Vector2(left - 8, 0), Vector2(left + 1160, 0), Vector2(left + 1160, 700), Vector2(left - 8, 700)]), PackedColorArray([Color("163847"), Color("163847"), Color("a9c9b5"), Color("a9c9b5")]))
	var sun := Vector2(left + 900 - left * 0.06, 180)
	draw_circle(sun, 89, Color(1, 0.87, 0.61, 0.045))
	draw_circle(sun, 67, Color(1, 0.87, 0.61, 0.065))
	draw_circle(sun, 47, Color("f5dda4"))
	for layer in range(3):
		var points := PackedVector2Array([Vector2(left - 100, 700)])
		for i in range(30):
			var x := left - 100 + i * 50
			var sample := x - left * (0.8 - layer * 0.18)
			var y := 360 + layer * 85 + sin(sample * 0.005 + layer * 4) * 65 + cos(sample * 0.013) * 24
			points.append(Vector2(x, y))
		points.append(Vector2(left + 1400, 700))
		draw_colored_polygon(points, [Color("426d70"), Color("598a83"), Color("7ba797")][layer])
	for i in range(16):
		var cloud_x := fposmod(i * 271.0 - clock * (5 + i % 3) - left * 0.12, 1450) - 150
		var p := Vector2(left + cloud_x, 155 + (i % 5) * 72)
		draw_set_transform(p, 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, 36 + i % 4 * 11, Color(0.84, 0.94, 0.85, 0.13))
		draw_set_transform(Vector2.ZERO)
	for rect in PLATFORMS:
		_draw_island(rect)
	for spike in SPIKES:
		for i in range(3):
			var p: Vector2 = spike.position + Vector2(i * spike.size.x / 3, 0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, 20), p + Vector2(spike.size.x / 6, 0), p + Vector2(spike.size.x / 3, 20)]), Color("e88b77"))
	for i in range(GEMS.size()):
		if i not in collected:
			var p: Vector2 = GEMS[i] + Vector2(0, sin(clock * 2.5 + i) * 5)
			draw_circle(p, 21, Color(1, 0.8, 0.45, 0.08))
			_draw_gem(p, 9, Color("ffe0a0"))
	_draw_checkpoint()
	_draw_lighthouse()
	_world_text(Vector2(65, 573), "01 / THE QUIET ASCENT", 16, Color("d1e4cc"))
	_world_text(Vector2(1580, 510), "02 / ABOVE THE CLOUDS", 16, Color("d1e4cc"))
	for mote in motes:
		var color: Color = mote.color
		color.a = minf(mote.life * 2, 1)
		draw_circle(mote.pos, 2.5, color)

func _draw_island(rect: Rect2) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var depth := minf(rect.size.y, 100)
	var shape := PackedVector2Array([Vector2(x, y + 5), Vector2(x + w, y + 5), Vector2(x + w - 12, y + depth * 0.65), Vector2(x + w * 0.66, y + depth + 22), Vector2(x + w * 0.35, y + depth), Vector2(x + 9, y + depth * 0.6)])
	draw_colored_polygon(shape, Color("294f53"))
	draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.6, y + 10), Vector2(x + w - 4, y + 10), Vector2(x + w - 12, y + depth * 0.65), Vector2(x + w * 0.66, y + depth + 22)]), Color("23434b"))
	draw_rect(Rect2(x, y, w, 9), Color("b4d4a0"))
	draw_rect(Rect2(x + 3, y + 9, w - 6, 7), Color("5e967d"))
	for i in range(int(w / 35)):
		var p := Vector2(x + 18 + i * 33, y)
		draw_line(p, p + Vector2(-3, -7 - i % 3 * 2), Color("c3d8a4"), 2)
		draw_line(p, p + Vector2(4, -5), Color("82b48c"), 2)
		if i % 4 == 0:
			draw_circle(p + Vector2(-3, -9), 2.5, Color("efc68a"))
	for i in range(3):
		var p := Vector2(x + w * (0.22 + i * 0.23), y + depth * 0.55)
		draw_line(p, p + Vector2(-3, 19 + i * 5), Color("568177"), 2)

func _draw_gem(p: Vector2, size: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -size * 1.4), p + Vector2(size, 0), p + Vector2(0, size * 1.4), p - Vector2(size, 0)]), color)
	draw_line(p + Vector2(0, -size), p + Vector2(-size * 0.6, 0), Color.WHITE, 1.5)

func _draw_checkpoint() -> void:
	var p := CHECKPOINT
	draw_line(p, p - Vector2(0, 77), Color("e2e5c1"), 4)
	var color := Color("b7f5cf") if checkpoint_active else Color("e3b87e")
	draw_colored_polygon(PackedVector2Array([p - Vector2(0, 77), p + Vector2(42, -70 + sin(clock * 3) * 3), p + Vector2(0, -49)]), color)
	if checkpoint_active:
		draw_circle(p - Vector2(0, 80), 12, Color(0.7, 1, 0.8, 0.15))
	_world_text(p + Vector2(-37, 27), "REST POINT", 12, Color("d9ebcc"))

func _draw_lighthouse() -> void:
	var p := GOAL
	if won:
		draw_colored_polygon(PackedVector2Array([p - Vector2(0, 113), p + Vector2(-430, -210), p + Vector2(-430, -35)]), Color(1, 0.9, 0.6, 0.09))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-24, 0), p + Vector2(24, 0), p + Vector2(16, -100), p + Vector2(-16, -100)]), Color("e6dfbb"))
	draw_rect(Rect2(p + Vector2(-19, -80), Vector2(38, 14)), Color("cc8068"))
	draw_rect(Rect2(p + Vector2(-13, -128), Vector2(26, 28)), Color("f8d786"))
	draw_rect(Rect2(p + Vector2(-25, -103), Vector2(50, 7)), Color("274a50"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-27, -128), p + Vector2(0, -147), p + Vector2(27, -128)]), Color("274a50"))
	draw_circle(p - Vector2(0, 114), 40 + sin(clock * 2) * 3, Color(1, 0.85, 0.5, 0.09))
	draw_style_box(_box(Color("34555a"), 7), Rect2(p + Vector2(-8, -27), Vector2(16, 27)))
	_world_text(p + Vector2(-62, 35), "THE FIRST LIGHT", 14, Color("f4e1ae"))

func _world_text(p: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
