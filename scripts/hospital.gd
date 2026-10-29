extends Node2D
## Local survivor combat: movement, draft upgrades, loot and weapon evolutions.

const WorldScript = preload("res://scripts/hospital_world.gd")
const HudScript = preload("res://scripts/hospital_hud.gd")
const AudioScript = preload("res://scripts/hospital_audio.gd")
const WebScript = preload("res://scripts/hospital_web.gd")
const ProgressionScript = preload("res://scripts/hospital_progression.gd")
const ArsenalScript = preload("res://scripts/hospital_arsenal.gd")
const CampaignScript = preload("res://scripts/hospital_campaign.gd")
const START := Vector2(768, 576)
const DURATION := 180.0
const MAX_ENEMIES := 48
const UPGRADE_COMBAT_INTERVAL := 6.0
enum Mode { READY, PLAYING, PAUSED, WON, LOST, TRANSITION, CHOOSING, REST }
var campaign = CampaignScript.new()
var rest_from_title := false
var run_id := ""
var checkpoint_pending := false
var enemy_shots: Array[Dictionary] = []
var progression = ProgressionScript.new()
var arsenal = ArsenalScript.new()
var upgrade_choices: Array[String] = []
var choice_source := "level"
var choice_revision := 0
var upgrade_cooldown := 0.0
var rerolls_left := 1
var max_hp := 100.0
var coins := 0
var total_coins := 0
var pickups: Array[Dictionary] = []
var gem_amounts: Array[int] = []
var magnet_active := false
var xp_fraction := 0.0
var loot_clock := 15.0
var regen_clock := 5.0
var wave_index := 0
var last_chest_rewards: Array[String] = []

const STAGE_NAMES := ["응급병동", "격리병동", "수술동"]
var stage_index := 1
var cleared_stages := 0
var total_elapsed := 0.0
var transition_left := 0.0
var boss_spawned := false
var boss_defeated := false
var elite_clock := 0.0
var pulse_clock := 0.0
var pulse_flash := 0.0
var banner := ""
var banner_left := 0.0
var selected_skin := 0
var best_stage := 0
var measured_step_us := 0

var mode := Mode.READY
var hero := START
var facing := Vector2.DOWN
var aim_direction := Vector2.DOWN
var aim_hold := 0.0
var body_angle := 0.0
var moving := false
var hp := 100.0
var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var damage := 24.0
var fire_interval := 0.53
var fire_clock := 0.0
var spawn_clock := 0.0
var invulnerable := 0.0
var hit_flash := 0.0
var shake := 0.0
var muzzle := 0.0
var level_flash := 0.0
var animation_time := 0.0
var hero_animation := "idle"
var hero_animation_time := 0.0
var hero_frames: SpriteFrames
var best_time := 0.0
var best_kills := 0
var muted := false
var testing := false
var record_path := "user://hospital_records.cfg"
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var gems: Array[Vector2] = []
var particles: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var world: Node2D
var camera: Camera2D
var hud: Node2D
var sprites: Array[Texture2D] = []
var audio: Node
var rng := RandomNumberGenerator.new()
var web_adapter: Node
var touch_direction := Vector2.ZERO
var paused_mode := Mode.PLAYING
var pause_reason := "user"

func pause_run(reason: String = "user") -> void:
	if mode in [Mode.PLAYING, Mode.TRANSITION, Mode.CHOOSING]:
		pause_reason = reason
		paused_mode = mode
		mode = Mode.PAUSED
		touch_direction = Vector2.ZERO
		if audio:
			audio.sync(muted, true, testing, 0.0, reason != "focus")

func resume_run() -> void:
	if mode == Mode.PAUSED:
		mode = paused_mode

func ranking_score() -> int:
	return mini(100000000, kills * 100 + coins * 10 + cleared_stages * 10000 + (maxi(0, 900 - int(total_elapsed)) * 10 if mode == Mode.WON else 0))

func _ready() -> void:
	rng.randomize()
	world = WorldScript.new()
	add_child(world)
	# The environment renders behind the actors drawn on this node.
	world.show_behind_parent = true
	var atlas: Texture2D = load("res://assets/characters_atlas.png")
	for i in range(4):
		sprites.append(WorldScript.atlas_cell(atlas, i))
	hero_frames = load("res://assets/sprites/medic_directional_v1/sprites.tres")
	camera = Camera2D.new()
	camera.position = START
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HudScript.new()
	hud.game = self
	canvas.add_child(hud)
	audio = AudioScript.new()
	add_child(audio)
	if not testing:
		_load_records()
		campaign.load_profile()
	web_adapter = WebScript.new()
	web_adapter.game = self
	add_child(web_adapter)
	print("ENDLESS WARD | 1920x1080 | local survival ready")

func _process(dt: float) -> void:
	audio.select_music(0 if mode in [Mode.READY, Mode.REST] else (stage_in_sector() if mode in [Mode.PLAYING, Mode.PAUSED, Mode.TRANSITION, Mode.CHOOSING] else -1))
	audio.sync(muted, mode in [Mode.PAUSED, Mode.CHOOSING, Mode.REST], testing, dt)
	if mode == Mode.READY:
		advance_hero_animation(dt, false)

func advance_hero_animation(dt: float, walking: bool) -> void:
	var previous_frame := int(hero_animation_time * 8.0) % 4
	var next := "walk" if walking else "idle"
	if hero_animation != next:
		hero_animation = next
		hero_animation_time = 0.0
	else:
		hero_animation_time = fmod(hero_animation_time + dt, 1.0 if next == "idle" else 0.5)
	var current_frame := int(hero_animation_time * 8.0) % 4
	if walking and previous_frame != current_frame and current_frame in [1, 3]:
		_play("step")

func hero_frame_index() -> int:
	var clip := hero_clip()
	return int(hero_animation_time * hero_frames.get_animation_speed(clip)) % hero_frames.get_frame_count(clip)

func hero_texture() -> Texture2D:
	return hero_frames.get_frame_texture(hero_clip(), hero_frame_index())

func hero_clip() -> String:
	var direction := hero_view()
	return ("east" if direction == "west" else direction) + "_" + hero_animation

func hero_draw_scale() -> Vector2:
	return Vector2(-1, 1) if hero_view() == "west" else Vector2.ONE

func hero_draw_angle() -> float:
	# Upright character views must never rotate in the screen plane.
	return 0.0

func hero_view() -> String:
	var direction := aim_direction if aim_hold > 0 else facing
	if absf(direction.x) >= absf(direction.y):
		return "west" if direction.x < 0 else "east"
	return "north" if direction.y < 0 else "south"

func _notification(what: int) -> void:
	# Web canvas blur also fires when using our own HTML controls. Browser window/visibility
	# events are handled by the web adapter, so those controls must not pause the game.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and not testing and not OS.has_feature("web"):
		pause_run("focus")

func start_run(save_checkpoint: bool = true) -> void:
	rest_from_title = false
	checkpoint_pending = false
	run_id = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), rng.randi()]
	touch_direction = Vector2.ZERO
	audio.stop_all()
	progression.reset()
	arsenal.reset()
	upgrade_choices.clear()
	choice_revision += 1
	upgrade_cooldown = 0.0
	last_chest_rewards.clear()
	rerolls_left = 1
	max_hp = 100
	coins = 0
	pickups.clear()
	gem_amounts.clear()
	magnet_active = false
	xp_fraction = 0.0
	loot_clock = 15
	regen_clock = 5
	wave_index = 0
	stage_index = 1
	cleared_stages = 0
	total_elapsed = 0
	transition_left = 0
	boss_spawned = false
	boss_defeated = false
	elite_clock = 75
	pulse_clock = 1.2
	pulse_flash = 0
	banner = ""
	banner_left = 0
	hero = START
	facing = Vector2.DOWN
	aim_direction = Vector2.DOWN
	aim_hold = 0
	body_angle = 0
	moving = false
	hero_animation = "idle"
	hero_animation_time = 0.0
	hp = 100
	elapsed = 0
	kills = 0
	level = 1
	xp = 0
	damage = 24
	fire_interval = 0.53
	fire_clock = 0.2
	spawn_clock = 0.65
	invulnerable = 0
	hit_flash = 0
	shake = 0
	muzzle = 0
	level_flash = 0
	enemies.clear()
	shots.clear()
	enemy_shots.clear()
	gems.clear()
	particles.clear()
	numbers.clear()
	shockwaves.clear()
	world.set_stage(1)
	world.update_chunks(hero)
	camera.position = hero
	mode = Mode.PLAYING
	_recompute_stats()
	hp = max_hp
	if save_checkpoint:
		if not _save_checkpoint(1, true):
			mode = Mode.READY
			return
	_play("start")
	if web_adapter:
		web_adapter.emit_event("game-start")
	queue_redraw()

func begin_stage(index: int) -> void:
	stage_index = index
	boss_spawned = false
	boss_defeated = false
	elapsed = 0
	hero = START
	facing = Vector2.DOWN
	aim_direction = Vector2.DOWN
	aim_hold = 0
	body_angle = 0
	moving = false
	hero_animation = "idle"
	hero_animation_time = 0.0
	hp = minf(max_hp, hp + 25)
	invulnerable = 1.5
	spawn_clock = 1.0
	fire_clock = 0.2
	elite_clock = 75 if stage_in_sector() == 1 else 12
	pulse_clock = 0.8
	pulse_flash = 0
	muzzle = 0
	hit_flash = 0
	shake = 0
	level_flash = 0
	enemies.clear()
	shots.clear()
	enemy_shots.clear()
	gems.clear()
	particles.clear()
	numbers.clear()
	shockwaves.clear()
	pickups.clear()
	gem_amounts.clear()
	magnet_active = false
	arsenal.reset()
	loot_clock = 12
	wave_index = 0
	world.set_stage(index)
	world.update_chunks(hero)
	camera.position = hero
	camera.offset = Vector2.ZERO
	mode = Mode.PLAYING
	announce("STAGE %02d  /  %s" % [index, stage_name()])
	if stage_in_sector() == 2:
		spawn_enemy("elite")
		spawn_enemy("elite")
	elif is_boss_stage():
		boss_spawned = spawn_enemy("boss")
		_play("boss_intro")
	if not testing and not OS.has_feature("web") and not get_window().has_focus():
		pause_run()

func complete_stage() -> void:
	cleared_stages = maxi(cleared_stages, stage_index)
	if is_boss_stage():
		mode = Mode.REST
		rest_from_title = false
		touch_direction = Vector2.ZERO
		camera.offset = Vector2.ZERO
		hp = max_hp
		enemy_shots.clear()
		_play("stage_clear")
		checkpoint_pending = not _bank_sector()
		announce("구역 %d 돌파 · 정비 후 계속 진행" % sector_index())
		return
	mode = Mode.TRANSITION
	_play("stage_clear")
	transition_left = 3.2
	camera.offset = Vector2.ZERO
	announce("STAGE %02d CLEAR" % stage_index)

func stage_name() -> String:
	return STAGE_NAMES[stage_in_sector() - 1]

func stage_in_sector(index: int = -1) -> int:
	return posmod((stage_index if index < 0 else index) - 1, 3) + 1

func sector_index() -> int:
	return 1 + floori((stage_index - 1) / 3.0)

func is_boss_stage() -> bool:
	return stage_in_sector() == 3

func encounter_label() -> String:
	if sector_index() == 1:
		return "기본 감염 · 3개 병동마다 감독관"
	return ["중장갑 집결 · 탱커 증가", "포자 확산 · 원거리 감염자 증가", "급속 변이 · 돌진형 증가"][posmod(sector_index() - 2, 3)]

func primary_action() -> void:
	if mode == Mode.PAUSED:
		resume_run()
	elif mode == Mode.REST:
		leave_workshop()
	elif mode in [Mode.READY, Mode.LOST, Mode.WON]:
		if has_checkpoint():
			continue_checkpoint()
		else:
			start_run()

func has_checkpoint() -> bool:
	return not campaign.checkpoint.is_empty()

func _checkpoint_snapshot(next_stage: int) -> Dictionary:
	return {"stage": next_stage, "level": level, "xp": xp, "xp_fraction": clampf(xp_fraction, 0.0, 0.999999), "kills": kills, "coins": coins, "total_elapsed": total_elapsed, "rerolls": rerolls_left, "skin": selected_skin, "progression": progression.serialize(), "seed": str(rng.seed), "rng_state": str(rng.state), "run_id": run_id}

func _save_checkpoint(next_stage: int, replace_corrupt: bool = false) -> bool:
	var snapshot := _checkpoint_snapshot(next_stage)
	if testing:
		campaign.checkpoint = snapshot.duplicate(true)
		return true
	return campaign.update_checkpoint(snapshot, replace_corrupt)

func _bank_sector() -> bool:
	var old_profile: Dictionary = campaign.profile.duplicate(true)
	var awarded: int = campaign.reward_sector(sector_index(), run_id)
	if not _save_checkpoint(stage_index + 1):
		campaign.profile = old_profile
		return false
	if awarded > 0:
		last_chest_rewards.assign(["정비 재료 +%d" % awarded])
	return true

func continue_checkpoint() -> bool:
	if not mode in [Mode.READY, Mode.LOST, Mode.WON] or not has_checkpoint():
		return false
	var saved: Dictionary = campaign.checkpoint.duplicate(true)
	var restored = ProgressionScript.new()
	if not restored.restore(saved.get("progression", {})):
		campaign.error_message = "체크포인트 장비를 복구할 수 없습니다."
		return false
	start_run(false)
	progression = restored
	level = int(saved.level)
	xp = int(saved.xp)
	xp_fraction = float(saved.xp_fraction)
	kills = int(saved.kills)
	coins = int(saved.coins)
	total_elapsed = float(saved.total_elapsed)
	rerolls_left = int(saved.rerolls)
	selected_skin = int(saved.skin)
	run_id = str(saved.run_id)
	rng.seed = int(saved.seed)
	rng.state = int(saved.rng_state)
	# A checkpoint may retain several levels of XP. Allow combat before prompting.
	upgrade_cooldown = UPGRADE_COMBAT_INTERVAL
	_recompute_stats()
	hp = max_hp
	cleared_stages = int(saved.stage) - 1
	begin_stage(int(saved.stage))
	_check_level_up()
	return true

func open_workshop() -> void:
	if mode in [Mode.READY, Mode.LOST]:
		rest_from_title = true
		mode = Mode.REST
		touch_direction = Vector2.ZERO

func leave_workshop() -> void:
	if mode != Mode.REST:
		return
	if rest_from_title:
		return_to_title()
		return
	if checkpoint_pending:
		checkpoint_pending = not _bank_sector()
		if checkpoint_pending:
			return
	begin_stage(stage_index + 1)
	_check_level_up()

func upgrade_equipment(slot: String) -> bool:
	if mode != Mode.REST or checkpoint_pending:
		return false
	if testing:
		if not slot in ["coat", "gloves", "boots"] or campaign.profile.materials < campaign.upgrade_cost(slot):
			return false
		campaign.profile.materials -= campaign.upgrade_cost(slot)
		campaign.profile.equipment[slot] += 1
	elif not campaign.upgrade(slot):
		return false
	_recompute_stats()
	hp = max_hp
	_play("ui")
	return true

func return_to_title() -> void:
	if mode == Mode.REST and checkpoint_pending:
		checkpoint_pending = not _bank_sector()
		if checkpoint_pending:
			return
	mode = Mode.READY
	rest_from_title = false
	touch_direction = Vector2.ZERO
	camera.offset = Vector2.ZERO
	audio.stop_all()

func announce(message: String) -> void:
	banner = message
	banner_left = 3.1

func pulse_unlocked() -> bool:
	return progression.get_level("pulse") > 0

func boss_enemy() -> Dictionary:
	for e in enemies:
		if e.get("kind", "") == "boss" and e.hp > 0:
			return e
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == Mode.CHOOSING:
			if event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
				choose_upgrade(event.physical_keycode - KEY_1)
				return
			if event.physical_keycode == KEY_R:
				reroll_upgrades()
				return
		if mode == Mode.REST and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			upgrade_equipment(["coat", "gloves", "boots"][event.physical_keycode - KEY_1])
			return
		match event.physical_keycode:
			KEY_ENTER, KEY_SPACE:
				primary_action()
			KEY_ESCAPE:
				if mode in [Mode.PLAYING, Mode.TRANSITION, Mode.CHOOSING]:
					pause_run()
				elif mode == Mode.PAUSED:
					resume_run()
				elif mode == Mode.REST:
					return_to_title()
			KEY_N:
				if mode in [Mode.READY, Mode.LOST, Mode.WON]:
					start_run()
			KEY_G:
				open_workshop()
			KEY_M:
				muted = not muted
				audio.sync(muted, mode in [Mode.PAUSED, Mode.CHOOSING, Mode.REST], testing, 0.0)
			KEY_TAB:
				if mode == Mode.READY:
					selected_skin = 1 - selected_skin
					_play("ui")
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_R:
				if mode == Mode.WON or mode == Mode.LOST:
					start_run()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:
			return # ScreenTouch below handles touch without a second emulated click.
		_handle_ui_click(hud.get_local_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_handle_ui_click(event.position)

func _handle_ui_click(point: Vector2) -> void:
	if mode == Mode.CHOOSING:
		_handle_choice_click(point)
	elif mode == Mode.REST:
		for i in range(3):
			if hud.equipment_rect(i).has_point(point):
				upgrade_equipment(["coat", "gloves", "boots"][i])
				return
		if hud.main_button.has_point(point):
			leave_workshop()
		elif hud.title_button.has_point(point):
			return_to_title()
	elif mode in [Mode.READY, Mode.LOST, Mode.WON, Mode.PAUSED]:
		if hud.main_button.has_point(point):
			primary_action()
		elif mode != Mode.PAUSED and hud.new_run_button.has_point(point):
			start_run()
		elif mode in [Mode.READY, Mode.LOST] and hud.workshop_button.has_point(point):
			open_workshop()
		elif mode == Mode.READY and hud.skin_button.has_point(point):
			selected_skin = 1 - selected_skin
			_play("ui")

func _handle_choice_click(point: Vector2) -> void:
	for i in range(upgrade_choices.size()):
		if hud.choice_rect(i).has_point(point):
			choose_upgrade(i)
			return
	if hud.reroll_button.has_point(point):
		reroll_upgrades()

func movement_input() -> Vector2:
	if touch_direction.length_squared() > 0.01:
		return touch_direction
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()

func _physics_process(dt: float) -> void:
	if mode != Mode.PLAYING and mode != Mode.TRANSITION:
		return
	var started := Time.get_ticks_usec() if testing else 0
	step_game(dt, movement_input())
	if testing:
		measured_step_us = Time.get_ticks_usec() - started

func step_game(dt: float, input_direction: Vector2) -> void:
	if mode == Mode.TRANSITION:
		transition_left -= dt
		if transition_left <= 0:
			begin_stage(stage_index + 1)
		return
	if mode != Mode.PLAYING:
		return
	var effective_dt := minf(dt, maxf(0.0, DURATION - elapsed)) if not is_boss_stage() else dt
	upgrade_cooldown = maxf(0.0, upgrade_cooldown - effective_dt)
	elapsed += effective_dt
	total_elapsed += effective_dt
	invulnerable = maxf(0, invulnerable - dt)
	hit_flash = maxf(0, hit_flash - dt)
	shake = maxf(0, shake - dt * 25)
	muzzle = maxf(0, muzzle - dt)
	aim_hold = maxf(0, aim_hold - dt)
	level_flash = maxf(0, level_flash - dt)
	pulse_flash = maxf(0, pulse_flash - dt)
	banner_left = maxf(0, banner_left - dt)
	animation_time += dt
	var previous_hero := hero
	if input_direction.length_squared() > 0.01:
		facing = input_direction.normalized()
		hero = world.move_body(hero, facing * movement_speed() * dt)
	moving = hero.distance_squared_to(previous_hero) > 0.001
	advance_hero_animation(dt, moving)
	world.update_chunks(hero)
	camera.position = camera.position.lerp(hero, 1.0 - exp(-12 * dt))
	camera.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	_update_waves()
	spawn_clock -= dt
	if spawn_clock <= 0:
		spawn_clock = [0.82, 0.52, 0.32][stage() - 1] * (0.88 if stage_in_sector() == 2 else 1.0) / minf(1.5, 1.0 + 0.05 * (sector_index() - 1))
		if is_boss_stage():
			spawn_clock = 2.0
		spawn_enemy()
	if not is_boss_stage():
		elite_clock -= dt
		if elite_clock <= 0:
			elite_clock = 60 if stage_in_sector() == 1 else 25
			if _kind_count("elite") < 6:
				for i in range(mini(1 if stage_in_sector() == 1 else 2, 6 - _kind_count("elite"))):
					spawn_enemy("elite")
				announce("엘리트 감염자 접근  /  충격 범위를 피하세요")
	elif is_boss_stage() and not boss_spawned:
		boss_spawned = spawn_enemy("boss")
	fire_clock -= dt
	if fire_clock <= 0:
		_auto_fire()
	var body_direction := aim_direction if aim_hold > 0 else facing
	body_angle = rotate_toward(body_angle, body_direction.angle() - PI / 2.0, 30.0 * dt)
	_update_enemies(dt)
	_update_enemy_shots(dt)
	if hp <= 0:
		finish(false)
		queue_redraw()
		return
	if pulse_unlocked():
		pulse_clock -= dt
		if pulse_clock <= 0:
			fire_pulse()
	arsenal.update(self, dt)
	_update_shots(dt)
	_update_pickups(dt)
	regen_clock -= dt
	if regen_clock <= 0:
		regen_clock = 5.0
		hp = minf(max_hp, hp + max_hp * 0.01 * progression.get_level("regen"))
	_update_gems(dt)
	for p in particles:
		p.p += p.v * dt
		p.v *= exp(-5 * dt)
		p.life -= dt
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0)
	for n in numbers:
		n.p.y -= dt * 34
		n.life -= dt
	numbers = numbers.filter(func(n: Dictionary) -> bool: return n.life > 0)
	for wave in shockwaves:
		wave.life -= dt
	shockwaves = shockwaves.filter(func(wave: Dictionary) -> bool: return wave.life > 0)
	if hp <= 0:
		finish(false)
	elif mode == Mode.PLAYING:
		_check_stage_end()
	queue_redraw()

func stage() -> int:
	return mini(3, 1 + int(elapsed / 60.0))

func _kind_count(kind: String) -> int:
	var count := 0
	for e in enemies:
		if e.get("kind", "") == kind and e.hp > 0:
			count += 1
	return count

func make_enemy(point: Vector2, kind: String) -> Dictionary:
	var fast := kind in ["fast", "rusher"]
	var health := 36.0 + stage() * 5 + (stage_in_sector() - 1) * 12
	var speed := (117.0 if fast else 68.0) + stage() * 9
	if kind == "elite":
		health = 420 + level * 18
		speed = 108
	elif kind == "boss":
		health = 7600 + level * 100
		speed = 106
	elif kind == "tank":
		health *= 2.4
		speed = 62
	elif kind == "ranged":
		health *= 0.8
		speed = 80
	health *= enemy_health_multiplier()
	speed *= minf(1.35, 1.0 + 0.025 * (sector_index() - 1))
	return {"p": point, "kind": kind, "hp": health, "max_hp": health, "speed": speed, "fast": fast, "path": PackedVector2Array(), "repath": rng.randf_range(0, 0.8), "flash": 0.0, "phase": rng.randf_range(0, TAU), "attack": "chase", "clock": 2.0, "attack_number": 0, "aim": Vector2.DOWN, "slow": 0.0}

func enemy_health_multiplier() -> float:
	var cycle := float(sector_index() - 1)
	return 1.0 + 0.32 * cycle + 0.015 * cycle * cycle

func enemy_damage_multiplier() -> float:
	return 1.0 + 0.10 * (sector_index() - 1)

func movement_speed() -> float:
	var boots: float = campaign.equipment_level("boots")
	return 285.0 * (1.0 + 0.1 * progression.get_level("speed")) * (1.0 + 0.25 * boots / (boots + 10.0))

func spawn_enemy(kind: String = "") -> bool:
	if kind == "boss" and not boss_enemy().is_empty():
		return false
	if kind == "elite" and _kind_count("elite") >= 6:
		return false
	var limit := 22 if is_boss_stage() else MAX_ENEMIES
	if kind.is_empty() and enemies.size() >= limit:
		return false
	var removal := -1
	if enemies.size() >= MAX_ENEMIES:
		var farthest := -1.0
		for i in range(enemies.size()):
			if enemies[i].get("kind", "normal") in ["boss", "elite"]:
				continue
			var distance: float = enemies[i].p.distance_squared_to(hero)
			if distance > farthest:
				farthest = distance
				removal = i
		if removal < 0:
			return false
	for attempt in range(24):
		var angle := rng.randf_range(0, TAU)
		var p := hero + Vector2(cos(angle), sin(angle)) * rng.randf_range(730, 1020)
		if not world.blocked(p, 26) and not world.path_to(p, hero).is_empty():
			if removal >= 0:
				enemies.remove_at(removal)
			var chosen := kind
			if chosen.is_empty():
				chosen = "fast" if (elapsed > 45 or stage_index > 1) and rng.randf() < 0.24 else "normal"
				if sector_index() >= 2 and rng.randf() < 0.35:
					var variants := ["tank", "ranged", "rusher"]
					chosen = variants[posmod(sector_index() - 2, 3)] if rng.randf() < 0.65 else variants[rng.randi_range(0, 2)]
			enemies.append(make_enemy(p, chosen))
			return true
	return false

func _auto_fire() -> void:
	fire_clock = 0.09
	var nearest := 660.0 * 660.0
	var target := Vector2.ZERO
	var found := false
	for e in enemies:
		var distance := hero.distance_squared_to(e.p)
		if e.hp > 0 and distance < nearest and world.clear_line(hero, e.p, 5):
			nearest = distance
			target = e.p
			found = true
	if found:
		var direction := hero.direction_to(target)
		aim_direction = direction
		aim_hold = maxf(0.35, fire_interval + 0.12)
		var rank: int = progression.get_level("syringe")
		var count := 1 + int(rank >= 3) + int(rank >= 5)
		for i in range(count):
			if shots.size() >= 80:
				break
			var shot_direction := direction.rotated((i - (count - 1) * 0.5) * 0.095)
			shots.append({"p": hero + shot_direction * 27, "v": shot_direction * 880 * projectile_multiplier(), "life": 0.95, "damage": damage, "pierce": 2 if rank == 6 else 0, "hit": []})
		fire_clock = fire_interval
		muzzle = 0.07
		_play("shoot")

func _update_enemies(dt: float) -> void:
	var path_budget := 2
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e.hp <= 0:
			continue
		if e.p.distance_squared_to(hero) > 2350 * 2350:
			if e.get("kind", "") == "boss":
				_relocate_boss(e)
			else:
				enemies.remove_at(i)
			continue
		e.flash = maxf(0, e.flash - dt)
		e.slow = maxf(0, e.get("slow", 0.0) - dt)
		if e.get("kind", "") in ["ranged", "rusher"] and _variant_attack(e, dt):
			_contact_enemy(e)
			continue
		if e.get("kind", "") in ["elite", "boss"] and _special_attack(e, dt):
			_contact_enemy(e)
			continue
		e.repath -= dt
		var destination: Vector2 = hero
		# Visibility and A* are staggered, rather than repeated for every actor
		# on every physics tick. Wall collision still runs for every movement.
		if e.repath <= 0 and path_budget > 0:
			path_budget -= 1
			e.direct = world.clear_line(e.p, hero, 21)
			if not e.direct:
				e.path = world.path_to(e.p, hero)
			e.repath = rng.randf_range(0.45, 0.75)
		if not e.get("direct", false):
			while e.path.size() > 0 and e.p.distance_to(e.path[0]) < 25:
				e.path.remove_at(0)
			if e.path.size() > 0:
				destination = e.path[0]
		var direction: Vector2 = e.p.direction_to(destination)
		# Local repulsion avoids an unreadable single stack of enemies.
		for j in range(maxi(0, i - 8), mini(enemies.size(), i + 8)):
			if i == j:
				continue
			var away: Vector2 = e.p - enemies[j].p
			var squared := away.length_squared()
			if squared > 0.01 and squared < 1296:
				var distance := sqrt(squared)
				direction += away / distance * (36 - distance) / 36.0
		var speed_multiplier := 0.6 if e.slow > 0 else 1.0
		if e.get("kind", "") == "boss" and e.hp < e.max_hp * 0.5:
			speed_multiplier *= 1.2
		e.p = world.move_body(e.p, direction.limit_length() * e.speed * speed_multiplier * dt, 19)
		_contact_enemy(e)

func _contact_enemy(e: Dictionary) -> void:
	var kind: String = e.get("kind", "normal")
	var reach := 52 if kind == "boss" else (44 if kind == "elite" else 39)
	if e.p.distance_to(hero) < reach and invulnerable <= 0:
		take_damage(22 if kind == "boss" else (16 if kind == "elite" else (12 if e.fast else 9)))

func _variant_attack(e: Dictionary, dt: float) -> bool:
	e.clock -= dt
	if e.attack == "chase":
		if e.clock <= 0 and e.p.distance_to(hero) < 550 and world.clear_line(e.p, hero, 8):
			e.aim = e.p.direction_to(hero)
			e.attack = "shot_warning" if e.kind == "ranged" else "charge_warning"
			e.clock = 0.9
			return true
		return false
	if e.attack == "shot_warning" and e.clock <= 0:
		_spawn_enemy_shot(e.p, e.aim, 230, 12)
		e.attack = "chase"
		e.clock = 3.5
	elif e.attack == "charge_warning" and e.clock <= 0:
		e.attack = "charge"
		e.clock = 0.45
	elif e.attack == "charge":
		e.p = world.move_body(e.p, e.aim * 400 * dt, 19)
		if e.clock <= 0:
			e.attack = "chase"
			e.clock = 4.0
	return true

func _spawn_enemy_shot(point: Vector2, direction: Vector2, speed: float, power: float) -> void:
	if enemy_shots.size() < 80:
		enemy_shots.append({"p": point, "v": direction * speed, "life": 4.0, "damage": power})

func _update_enemy_shots(dt: float) -> void:
	for shot in enemy_shots:
		var before: Vector2 = shot.p
		shot.p += shot.v * dt
		shot.life -= dt
		if not world.clear_line(before, shot.p, 5):
			shot.life = 0
		elif Geometry2D.get_closest_point_to_segment(hero, before, shot.p).distance_to(hero) < 25:
			take_damage(shot.damage)
			shot.life = 0
	enemy_shots = enemy_shots.filter(func(shot: Dictionary) -> bool: return shot.life > 0)

func _relocate_boss(e: Dictionary) -> void:
	# An off-screen boss keeps its health and remains part of this stage.
	for i in range(16):
		var point: Vector2 = hero + Vector2.from_angle(i * TAU / 16) * 850
		if not world.blocked(point, 26) and not world.path_to(point, hero).is_empty():
			e.p = point
			e.attack = "chase"
			e.clock = 2.0
			e.path = PackedVector2Array()
			e.repath = 0.0
			announce("감독관 추적 중  /  거리를 유지하세요")
			return

func attack_radius(e: Dictionary) -> float:
	return 175.0 if e.get("kind", "") == "boss" else 116.0

func _special_attack(e: Dictionary, dt: float) -> bool:
	var boss: bool = e.kind == "boss"
	e.clock -= dt
	match e.attack:
		"chase":
			if e.clock <= 0:
				# A blocked special attacker retries on a short cooldown instead
				# of ray-testing through the same wall every physics frame.
				e.clock = 0.35
				if e.p.distance_to(hero) < (620 if boss else 310) and world.clear_line(e.p, hero, 8):
					e.attack_number += 1
					e.aim = e.p.direction_to(hero)
					e.attack = "charge_warning" if boss and e.attack_number % 2 == 1 else "slam_warning"
					if boss and sector_index() >= 2 and e.attack_number % 3 == 0:
						e.attack = "volley_warning"
					e.clock = 0.95 if boss else 0.85
					_play("charge_warning" if e.attack == "charge_warning" else ("boss_slam_warning" if boss else "elite_warning"), e.p)
					return true
			return false
		"volley_warning":
			if e.clock <= 0:
				var count := mini(16, 8 + sector_index())
				for i in range(count):
					_spawn_enemy_shot(e.p, Vector2.from_angle(e.aim.angle() + TAU * i / count), 205, 18)
				e.attack = "recover"
				e.clock = 1.0
			return true
		"charge_warning":
			if e.clock <= 0:
				e.attack = "charge"
				e.clock = 0.55
				_play("dash", e.p)
			return true
		"charge":
			var before: Vector2 = e.p
			e.p = world.move_body(e.p, e.aim * 490 * dt, 23)
			if e.clock <= 0 or e.p.distance_to(before) < 490 * dt * 0.35:
				e.attack = "recover"
				e.clock = 1.0
				_play("slam", e.p)
			return true
		"slam_warning":
			if e.clock <= 0:
				_play("slam", e.p)
				var radius := attack_radius(e)
				if e.p.distance_to(hero) <= radius + 20 and world.clear_line(e.p, hero, 8):
					take_damage(26 if boss else 18)
				if shockwaves.size() < 12:
					shockwaves.append({"p": e.p, "radius": radius, "life": 0.5})
				e.attack = "recover"
				e.clock = 1.0
			return true
		"recover":
			if e.clock <= 0:
				e.attack = "chase"
				e.clock = 2.6 if boss and e.hp < e.max_hp * 0.5 else (3.6 if boss else 4.5)
			return true
	return false

func fire_pulse() -> void:
	if not pulse_unlocked():
		return
	var rank: int = progression.get_level("pulse")
	pulse_clock = (1.8 if rank == 6 else 3.2) * cooldown_multiplier()
	pulse_flash = 0.5
	_play("pulse")
	for e in enemies:
		if e.hp > 0 and e.p.distance_to(hero) < pulse_radius() and world.clear_line(hero, e.p, 5):
			e.slow = (2.4 if rank == 6 else 1.2) * duration_multiplier()
			_damage_enemy(e, (30.0 + rank * 18) * attack_multiplier(), "pulse")

func _damage_enemy(e: Dictionary, amount: float, weapon_id: String = "") -> void:
	if e.hp <= 0:
		return
	if not weapon_id.is_empty():
		amount *= progression.damage_multiplier(weapon_id)
		if progression.trait_for(weapon_id) == "focus" and e.get("kind", "") == "boss":
			amount *= 1.4
		if progression.trait_for(weapon_id) == "blast":
			# Secondary hits have no weapon identity: no recursive explosions.
			for other in enemies:
				if other != e and other.hp > 0 and other.p.distance_squared_to(e.p) <= 75 * 75 and world.clear_line(e.p, other.p, 3):
					_damage_enemy(other, amount * 0.25)
	if e.get("kind", "") == "tank":
		amount *= 0.65
	var before: float = e.hp
	e.hp -= amount
	_play("impact", e.p)
	if e.get("kind", "") == "boss" and before > e.max_hp * 0.5 and e.hp <= e.max_hp * 0.5 and e.hp > 0:
		_play("enrage", e.p)
	e.flash = 0.12
	if numbers.size() < 64:
		numbers.append({"p": e.p + Vector2(-8, -55), "value": str(int(amount)), "life": 0.55})
	_burst(e.p, Color("acddd0"), 4)
	if e.hp > 0:
		return
	kills += 1
	if e.get("kind", "") != "boss":
		_play("enemy_down", e.p)
	var kind: String = e.get("kind", "normal")
	var reward := 30 if kind == "boss" else (18 if kind == "elite" else (3 if e.fast else 2))
	_spawn_gem(e.p, maxi(1, roundi(reward * (1.0 + 0.12 * (sector_index() - 1)))))
	_burst(e.p, Color("e9b997"), 12)
	if kind == "boss":
		boss_defeated = true
		announce("격리 감독관 처치")
	elif kind == "elite":
		spawn_pickup(e.p, "chest")
	elif rng.randf() < 0.08:
		var roll := rng.randf()
		spawn_pickup(e.p, "heal" if roll < 0.25 else ("magnet" if roll < 0.43 else ("bomb" if roll < 0.57 else "coin")))

func take_damage(amount: float) -> void:
	if invulnerable > 0 or mode != Mode.PLAYING:
		return
	var coat: float = campaign.equipment_level("coat")
	var reduction := 0.20 * coat / (coat + 10.0)
	hp = maxf(0, hp - amount * enemy_damage_multiplier() * (1.0 - 0.1 * progression.get_level("armor")) * (1.0 - reduction))
	invulnerable = 0.85
	hit_flash = 0.24
	shake = 7
	_burst(hero, Color("ee8474"), 12)
	_play("player_hit")

func _update_shots(dt: float) -> void:
	for b in shots:
		var old: Vector2 = b.p
		b.p += b.v * dt
		b.life -= dt
		if not world.clear_line(old, b.p, 3):
			b.life = 0
			_burst(old, Color("aacfc4"), 3)
			continue
		for e in enemies:
			if e.hp <= 0 or b.life <= 0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(e.p, old, b.p)
			var radius := 43 if e.get("kind", "") == "boss" else (31 if e.get("kind", "") == "elite" else 26)
			if closest.distance_to(e.p) < radius:
				var already_hit: Array = b.get("hit", [])
				if already_hit.has(e):
					continue
				already_hit.append(e)
				b.hit = already_hit
				b.life = b.life if int(b.get("pierce", 0)) > 0 else 0.0
				b.pierce = int(b.get("pierce", 0)) - 1
				_damage_enemy(e, float(b.get("damage", damage)), "syringe")
	shots = shots.filter(func(b: Dictionary) -> bool: return b.life > 0)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)

func _update_gems(dt: float) -> void:
	while gem_amounts.size() < gems.size():
		gem_amounts.append(1)
	for i in range(gems.size() - 1, -1, -1):
		if magnet_active or (gems[i].distance_to(hero) < 150 * (1.0 + progression.get_level("magnet")) and world.clear_line(gems[i], hero, 3)):
			gems[i] = gems[i].move_toward(hero, (1600 if magnet_active else 470) * dt)
		if gems[i].distance_to(hero) < 24:
			gems.remove_at(i)
			xp_fraction += gem_amounts[i] * (1.0 + 0.1 * progression.get_level("experience"))
			var earned := floori(xp_fraction + 0.000001)
			xp += earned
			xp_fraction -= earned
			gem_amounts.remove_at(i)
			_play("pickup")
	if gems.is_empty():
		magnet_active = false
	_check_level_up()

func _check_level_up() -> void:
	if mode == Mode.PLAYING and upgrade_cooldown <= 0.0 and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		level_flash = 2.4
		_burst(hero, Color("8de6ce"), 32)
		_play("level")
		upgrade_choices = progression.roll_choices(rng, 3)
		choice_revision += 1
		choice_source = "level"
		mode = Mode.CHOOSING
		touch_direction = Vector2.ZERO
		camera.offset = Vector2.ZERO

func choose_upgrade(index: int, expected_revision: int = -1) -> void:
	if expected_revision != -1 and expected_revision != choice_revision:
		return
	if mode != Mode.CHOOSING or index < 0 or index >= upgrade_choices.size():
		return
	var id := upgrade_choices[index]
	if not _apply_upgrade(id):
		return
	upgrade_choices.clear()
	mode = Mode.PLAYING
	upgrade_cooldown = UPGRADE_COMBAT_INTERVAL
	# Give the player a moment to resume movement after a blocking UI choice.
	invulnerable = maxf(invulnerable, 0.75)
	_play("ui")
	# Keep overflow XP queued instead of opening another modal in the same frame.
	_check_stage_end()

func reroll_upgrades(expected_revision: int = -1) -> void:
	if expected_revision != -1 and expected_revision != choice_revision:
		return
	if mode != Mode.CHOOSING or rerolls_left <= 0:
		return
	rerolls_left -= 1
	upgrade_choices = progression.roll_choices(rng, 3)
	choice_revision += 1
	_play("ui")

func _apply_upgrade(id: String) -> bool:
	if not progression.apply_upgrade(id):
		return false
	if id == "heal":
		hp = minf(max_hp, hp + max_hp * 0.3)
	elif id == "coins":
		_gain_coins(50)
	_recompute_stats()
	return true

func _recompute_stats() -> void:
	var old_max := max_hp
	max_hp = 100.0 * (1.0 + 0.2 * progression.get_level("health")) * (1.0 + 0.15 * campaign.equipment_level("coat") + 0.05 * campaign.equipment_level("boots"))
	hp = minf(max_hp, hp + maxf(0, max_hp - old_max))
	var rank: int = progression.get_level("syringe")
	damage = (24.0 + (rank - 1) * 14.0) * attack_multiplier()
	fire_interval = (0.14 if rank == 6 else 0.53 - (rank - 1) * 0.055) * cooldown_multiplier()

func attack_multiplier() -> float:
	return (1.0 + 0.1 * progression.get_level("attack")) * (1.0 + 0.1 * campaign.equipment_level("gloves"))

func cooldown_multiplier() -> float:
	return 1.0 - 0.08 * progression.get_level("cooldown")

func area_multiplier() -> float:
	return 1.0 + 0.1 * progression.get_level("area")

func duration_multiplier() -> float:
	return 1.0 + 0.1 * progression.get_level("duration")

func projectile_multiplier() -> float:
	return 1.0 + 0.1 * progression.get_level("projectile")

func pulse_radius() -> float:
	return (170.0 + 12 * progression.get_level("pulse")) * area_multiplier()

func _check_stage_end() -> void:
	if (not is_boss_stage() and elapsed >= DURATION) or (is_boss_stage() and boss_defeated):
		complete_stage()

func xp_needed() -> int:
	return 4 + level * 2

func _update_waves() -> void:
	if is_boss_stage():
		return
	var next_wave := mini(2, int(elapsed / 60.0))
	if next_wave > wave_index:
		wave_index = next_wave
		for i in range(8):
			spawn_enemy("fast" if i % 3 == 0 else "")
		announce("감염자 무리 접근  /  WAVE %d" % (wave_index + 1))

func _spawn_gem(point: Vector2, value: int) -> void:
	while gem_amounts.size() < gems.size():
		gem_amounts.append(1)
	if gems.size() < 180:
		gems.append(point)
		gem_amounts.append(value)
	else:
		# Keep all earned XP while bounding rendering and storage.
		var nearest := 0
		for i in range(1, gems.size()):
			if gems[i].distance_squared_to(point) < gems[nearest].distance_squared_to(point):
				nearest = i
		gem_amounts[nearest] += value

func spawn_pickup(point: Vector2, kind: String) -> void:
	if pickups.size() >= 64:
		# Special rewards must not vanish because too many coins were left behind.
		if kind == "chest":
			for item in pickups:
				if item.kind == "chest":
					item.count = int(item.get("count", 1)) + 1
					return
			pickups[0] = {"p": point, "kind": kind, "count": 1}
		return
	pickups.append({"p": point, "kind": kind, "count": 1})

func _update_pickups(dt: float) -> void:
	loot_clock -= dt
	if loot_clock <= 0:
		loot_clock = 20.0
		for attempt in range(16):
			var point := hero + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(190, 400)
			if not world.blocked(point, 18) and world.clear_line(hero, point, 6):
				var kinds := ["heal", "magnet", "bomb", "coin"]
				spawn_pickup(point, kinds[rng.randi_range(0, kinds.size() - 1)])
				break
	for i in range(pickups.size() - 1, -1, -1):
		var item: Dictionary = pickups[i]
		if item.p.distance_to(hero) < 34 * (1.0 + progression.get_level("magnet")) and world.clear_line(item.p, hero, 3):
			pickups.remove_at(i)
			for n in range(int(item.get("count", 1))):
				collect_pickup(item.kind)

func collect_pickup(kind: String) -> void:
	match kind:
		"heal":
			hp = minf(max_hp, hp + max_hp * 0.3)
			announce("응급 처치  /  최대 체력의 30% 회복")
		"magnet":
			magnet_active = true
			announce("자석  /  병동의 모든 경험치를 회수합니다")
		"bomb":
			# Screen bomb clears ordinary foes; elites/bosses take damage, never an instant kill.
			for e in enemies:
				if e.hp > 0 and absf(e.p.x - camera.position.x) < 960 and absf(e.p.y - camera.position.y) < 540:
					_damage_enemy(e, 300.0 * attack_multiplier() if e.get("kind", "normal") in ["elite", "boss"] else float(e.hp))
			if shockwaves.size() < 12:
				shockwaves.append({"p": hero, "radius": 850.0, "life": 0.5})
			shake = 5
			_play("pulse")
			announce("멸균 폭탄  /  화면 안의 감염자 소탕")
		"coin":
			_gain_coins(10)
			announce("보급 코인 획득  /  결과 점수에 반영")
		"chest":
			open_chest()
	_play("pickup")

func _gain_coins(base: int) -> void:
	var gained := roundi(base * (1.0 + 0.1 * progression.get_level("gold")))
	coins += gained
	total_coins += gained

func open_chest(reward_count: int = 0) -> void:
	var count := reward_count
	if count <= 0:
		var roll := rng.randf()
		count = 5 if roll < 0.05 else (3 if roll < 0.25 else 1)
	last_chest_rewards.clear()
	for i in range(clampi(count, 1, 5)):
		var pool: Array[String] = []
		var evolutions: Array[String] = []
		for id in progression.available_upgrades():
			if progression.can_evolve(id):
				evolutions.append(id)
			elif progression.is_owned_upgrade(id):
				pool.append(id)
		if not evolutions.is_empty():
			pool = evolutions
		if pool.is_empty():
			# Chests strengthen owned gear; no forced new weapon when building a loadout.
			var before := coins
			_gain_coins(50)
			last_chest_rewards.append("코인 +%d" % (coins - before))
			continue
		var id := pool[rng.randi_range(0, pool.size() - 1)]
		var info: Dictionary = progression.offer_info(id)
		if _apply_upgrade(id):
			last_chest_rewards.append(str(info.name))
	announce("보급 상자 ×%d  /  %s" % [count, " · ".join(last_chest_rewards.slice(0, 2))])
	_play("level")

func finish(won: bool) -> void:
	if mode in [Mode.WON, Mode.LOST]:
		return
	mode = Mode.WON if won else Mode.LOST
	audio.stop_all()
	audio.select_music(-1)
	_play("victory" if won else "loss")
	camera.offset = Vector2.ZERO
	if not testing:
		best_time = maxf(best_time, total_elapsed)
		best_kills = maxi(best_kills, kills)
		best_stage = maxi(best_stage, cleared_stages)
		var data := ConfigFile.new()
		data.set_value("records", "survival", best_time)
		data.set_value("records", "kills", best_kills)
		data.set_value("records", "stages", best_stage)
		data.set_value("records", "coins", total_coins)
		var result := data.save(record_path)
		if result != OK:
			push_warning("Could not save local records: " + error_string(result))
	print("RUN FINISHED | won=", won, " stage=", stage_index, " total_time=", snappedf(total_elapsed, 0.01), " kills=", kills)
	if web_adapter:
		web_adapter.emit_event("game-finished")

func _load_records() -> void:
	var data := ConfigFile.new()
	if data.load(record_path) == OK:
		best_time = data.get_value("records", "survival", 0.0)
		best_kills = data.get_value("records", "kills", 0)
		best_stage = data.get_value("records", "stages", 0)
		total_coins = data.get_value("records", "coins", 0)

func _burst(point: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		if particles.size() >= 240:
			break
		var angle := rng.randf_range(0, TAU)
		particles.append({"p": point, "v": Vector2.from_angle(angle) * rng.randf_range(30, 170), "life": rng.randf_range(0.15, 0.5), "color": color})

func _play(kind: String, point: Vector2 = Vector2.INF) -> void:
	if audio == null:
		return
	audio.sync(muted, mode in [Mode.PAUSED, Mode.CHOOSING, Mode.REST], testing, 0.0)
	if not muted and not testing:
		audio.play_event(kind, 0.0 if point == Vector2.INF else hero.distance_to(point))

func _draw() -> void:
	if sprites.is_empty():
		return
	for e in enemies:
		var attack: String = e.get("attack", "chase")
		if attack == "slam_warning":
			var radius := attack_radius(e)
			draw_circle(e.p, radius, Color(0.95, 0.28, 0.13, 0.12))
			draw_arc(e.p, radius, 0, TAU, 48, Color("ef9a73"), 3, true)
			draw_arc(e.p, radius * clampf(1.0 - e.clock / 0.95, 0, 1), 0, TAU, 48, Color(0.98, 0.64, 0.39, 0.6), 2, true)
		elif attack in ["charge_warning", "charge"]:
			var endpoint: Vector2 = world.move_body(e.p, e.aim * 270, 23)
			draw_line(e.p, endpoint, Color(0.95, 0.22, 0.12, 0.16), 94, true)
			draw_line(e.p, endpoint, Color("ee9a7c"), 3, true)
		elif attack == "shot_warning":
			draw_line(e.p, e.p + e.aim * 560, Color(0.85, 0.54, 1.0, 0.5), 2, true)
		elif attack == "volley_warning":
			draw_arc(e.p, 70 + 30 * (1.0 - clampf(e.clock, 0, 1)), 0, TAU, 48, Color("d792ed"), 4, true)
		if e.get("kind", "") in ["elite", "boss"]:
			draw_arc(e.p + Vector2(0, 7), 50 if e.kind == "boss" else 34, 0, TAU, 40, Color("e39d72"), 2, true)
		elif e.get("kind", "") in ["tank", "ranged", "rusher"]:
			var ring := Color("86b9da") if e.kind == "tank" else (Color("d792ed") if e.kind == "ranged" else Color("f1b667"))
			draw_arc(e.p + Vector2(0, 7), 29, 0, TAU, 24, ring, 2, true)
	for shot in enemy_shots:
		draw_circle(shot.p, 8, Color("b776cf"))
		draw_circle(shot.p, 3, Color("ffe3fa"))
	for wave in shockwaves:
		draw_arc(wave.p, wave.radius * (1.0 - wave.life / 0.5), 0, TAU, 48, Color(1, 0.59, 0.36, wave.life * 1.6), 5, true)
	if pulse_flash > 0:
		draw_circle(hero, pulse_radius() * (1 - pulse_flash / 0.5), Color(0.35, 0.9, 0.9, pulse_flash * 0.12))
		draw_arc(hero, pulse_radius() * (1 - pulse_flash / 0.5), 0, TAU, 48, Color(0.62, 0.95, 0.94, pulse_flash * 1.6), 4, true)
	arsenal.draw_effects(self)
	_draw_pickups()
	for p in gems:
		draw_circle(p, 13, Color(0.22, 0.95, 0.76, 0.09))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(5, 0), p + Vector2(0, 7), p + Vector2(-5, 0)]), Color("8cd9bb"))
	for b in shots:
		var direction: Vector2 = b.v.normalized()
		draw_line(b.p - direction * 22, b.p, Color(0.31, 0.95, 0.85, 0.2), 10, true)
		draw_line(b.p - direction * 16, b.p, Color("b8fff0"), 3, true)
	var actors: Array[Dictionary] = []
	for e in enemies:
		actors.append({"p": e.p, "enemy": e})
	actors.append({"p": hero, "hero": true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.p.y < b.p.y)
	# Render shadows together so sprites from the same atlas can batch.
	for actor in actors:
		var boss_shadow: bool = actor.has("enemy") and actor.enemy.get("kind", "") == "boss"
		var shadow := PackedVector2Array()
		for i in range(12):
			shadow.append(actor.p + Vector2(0, 9) + Vector2(cos(i * TAU / 12) * (46.0 if boss_shadow else 25.0), sin(i * TAU / 12) * (15.0 if boss_shadow else 8.5)))
		draw_colored_polygon(shadow, Color(0, 0.02, 0.02, 0.4))
	for actor in actors:
		if actor.has("hero"):
			_draw_hero()
		else:
			var e: Dictionary = actor.enemy
			var bob := sin(animation_time * (11 if e.fast else 6) + e.phase) * 2.0
			var kind: String = e.get("kind", "normal")
			var size := Vector2(114, 175) if kind == "boss" else (Vector2(78, 127) if kind == "elite" else Vector2(60, 100))
			var tint := Color(1.18, 0.78, 0.64) if kind == "boss" else (Color(1.12, 0.91, 0.65) if kind == "elite" else Color(0.83, 0.85, 0.79))
			if kind == "tank":
				size = Vector2(76, 115)
				tint = Color(0.65, 0.85, 1.15)
			elif kind == "ranged":
				tint = Color(1.1, 0.70, 1.2)
			elif kind == "rusher":
				tint = Color(1.2, 0.95, 0.6)
			_actor_sprite(3 if e.fast or kind == "boss" else 2, e.p, size, bob, Color(1.4, 1.3, 1.1) if e.flash > 0 else tint)
	for e in enemies:
		var elite: bool = e.get("kind", "") == "elite"
		if elite or e.hp < e.max_hp:
			var offset := Vector2(-28, -121) if elite else Vector2(-21, -90)
			var width := 56.0 if elite else 42.0
			draw_rect(Rect2(e.p + offset, Vector2(width, 4)), Color("182b2c"))
			draw_rect(Rect2(e.p + offset, Vector2(width * maxf(0, e.hp) / e.max_hp, 4)), Color("e3ab73") if elite else Color("d88778"))
			if elite:
				draw_string(hud.font, e.p + offset + Vector2(5, -8), "ELITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("efbb80"))
	for p in particles:
		var color: Color = p.color
		color.a = minf(1, p.life * 3)
		draw_circle(p.p, 2.5, color)
	for n in numbers:
		draw_string(hud.font, n.p, n.value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.88, 1, 0.91, minf(1, n.life * 3)))

func _draw_hero() -> void:
	draw_arc(hero + Vector2(0, 10), 32, 0, TAU, 48, Color(0.45, 0.95, 0.80, 0.3), 1.4, true)
	if invulnerable > 0 and fmod(invulnerable, 0.14) > 0.08:
		return
	draw_set_transform(hero, hero_draw_angle(), hero_draw_scale())
	var tint := Color(1.35, 0.9, 0.8) if hit_flash > 0 else skin_color()
	draw_texture_rect(hero_texture(), Rect2(-64, -64, 128, 128), false, tint)
	draw_set_transform(Vector2.ZERO)
	if muzzle > 0:
		draw_circle(hero + aim_direction * 40, 10, Color(0.7, 1, 0.89, 0.75))

func _draw_pickups() -> void:
	var colors := {"heal": Color("ef9b93"), "magnet": Color("99c5ff"), "bomb": Color("f6b069"), "coin": Color("ecd582"), "chest": Color("c3a2ff")}
	var names := {"heal": "회복", "magnet": "자석", "bomb": "폭탄", "coin": "코인", "chest": "상자"}
	for item in pickups:
		var p: Vector2 = item.p
		if p.distance_squared_to(camera.position) > 1250 * 1250:
			continue
		var color: Color = colors.get(item.kind, Color.WHITE)
		draw_circle(p, 27, Color(color, 0.12))
		draw_arc(p, 23, 0, TAU, 24, Color(color, 0.6), 1.5, true)
		match item.kind:
			"heal":
				draw_rect(Rect2(p - Vector2(5, 14), Vector2(10, 28)), color)
				draw_rect(Rect2(p - Vector2(14, 5), Vector2(28, 10)), color)
			"magnet":
				draw_arc(p - Vector2(0, 5), 12, 0, PI, 16, color, 7, true)
				draw_line(p + Vector2(-12, -14), p + Vector2(-12, -4), color, 7)
				draw_line(p + Vector2(12, -14), p + Vector2(12, -4), color, 7)
			"bomb":
				draw_circle(p + Vector2(0, 3), 12, color)
				draw_line(p + Vector2(5, -8), p + Vector2(11, -16), color, 3)
			"chest":
				draw_rect(Rect2(p - Vector2(16, 11), Vector2(32, 24)), color)
				draw_line(p + Vector2(-16, -2), p + Vector2(16, -2), Color("2c3248"), 3)
				draw_rect(Rect2(p - Vector2(3, 5), Vector2(6, 10)), Color("f3df9c"))
			"coin":
				draw_circle(p, 12, color)
				draw_arc(p, 8, 0, TAU, 20, Color("8b6b35"), 2, true)
		draw_string(hud.font, p + Vector2(-16, 43), names.get(item.kind, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)

func _actor_sprite(index: int, point: Vector2, size: Vector2, bob: float, tint: Color) -> void:
	draw_texture_rect(sprites[index], Rect2(point + Vector2(-size.x / 2, -size.y + 21 + bob), size), false, tint)

func skin_color() -> Color:
	return Color(0.78, 0.88, 1.15) if selected_skin == 1 else Color.WHITE
