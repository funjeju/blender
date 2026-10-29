extends SceneTree
## Local integration checks. testing is set before _ready so no user save is read or written.
var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_test_campaign_and_equipment()
	_test_weapon_damage()
	_test_scaling_and_bounds()
	print("ENDLESS CAMPAIGN COMPLETE | ", checks, " checks | ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _test_campaign_and_equipment() -> void:
	check(game.campaign.profile.materials == 0 and not game.has_checkpoint(), "test instance starts in memory without loading user progress")
	game.start_run()
	check(game.has_checkpoint() and game.campaign.checkpoint.stage == 1, "new expedition banks a first-stage retry checkpoint")
	var first_normal: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "normal")
	var first_health: float = first_normal.hp
	var first_speed: float = first_normal.speed
	check(not game.upgrade_equipment("coat"), "permanent equipment upgrades are restricted to a workshop")
	game.progression.restore({"weapons": {"syringe": 6}, "supplies": {"experience": 1}, "mastery": {"syringe": 4}, "traits": {"syringe": "focus"}})
	game._recompute_stats()
	game.level = 20
	game.xp = 2
	game.xp_fraction = 0.4
	game.kills = 123
	game.coins = 76
	game.total_elapsed = 111.5
	game.rerolls_left = 0
	game.selected_skin = 1
	game.begin_stage(3)
	_defeat_boss()
	check(game.mode == game.Mode.REST and game.stage_index == 3 and game.cleared_stages == 3, "third boss enters a workshop instead of ending the expedition")
	check(game.campaign.checkpoint.stage == 4 and game.campaign.profile.materials > 0, "boss clear banks stage four and grants equipment materials")
	var saved: Dictionary = game.campaign.checkpoint.duplicate(true)
	var saved_materials: int = game.campaign.profile.materials
	check(saved.progression.mastery.syringe == 4 and saved.progression.traits.syringe == "focus", "checkpoint includes weapon mastery and the chosen trait")
	check(game.campaign.reward_sector(1, game.run_id) == 0 and game.campaign.profile.materials == saved_materials, "repeated sector reward cannot duplicate materials within a run")
	var before_hp: float = game.max_hp
	var coat_cost: int = game.campaign.upgrade_cost("coat")
	check(game.upgrade_equipment("coat") and game.max_hp > before_hp and game.hp == game.max_hp and game.campaign.profile.materials == saved_materials - coat_cost, "coat upgrade spends its displayed materials and raises restored health")
	var before_attack: float = game.attack_multiplier()
	var gloves_cost: int = game.campaign.upgrade_cost("gloves")
	check(game.upgrade_equipment("gloves") and game.attack_multiplier() > before_attack and game.campaign.profile.materials == saved_materials - coat_cost - gloves_cost, "gloves spend materials and improve all-weapon attack")
	var inventory: Dictionary = game.campaign.profile.duplicate(true)
	check(not game.upgrade_equipment("boots") and not game.upgrade_equipment("unknown") and game.campaign.profile == inventory, "insufficient materials and invalid slots cannot change permanent progress")
	var paused_time: float = game.total_elapsed
	game.step_game(3.0, Vector2.RIGHT)
	check(game.mode == game.Mode.REST and game.total_elapsed == paused_time, "workshop pauses timers and combat")
	game.leave_workshop()
	var next_normal: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "normal")
	check(game.stage_index == 4 and game.mode == game.Mode.PLAYING and game.stage_in_sector() == 1 and game.sector_index() == 2, "leaving the first workshop starts the next three-stage sector")
	check(next_normal.hp > first_health and next_normal.speed >= first_speed and game.enemy_damage_multiplier() > 1.0, "new sector increases enemy health, attack and movement")
	check(game.world.current_theme == 0 and game.progression.serialize() == saved.progression, "stage four cycles map themes while retaining the evolved build")
	game._apply_upgrade("mastery:syringe")
	game.coins = 999
	game.hp = 0
	game.finish(false)
	check(game.mode == game.Mode.LOST and game.has_checkpoint(), "death retains the last banked checkpoint")
	check(game.continue_checkpoint() and game.stage_index == 4 and game.mode == game.Mode.PLAYING, "death retry resumes the banked sector start")
	check(game.progression.serialize() == saved.progression and game.coins == saved.coins and game.level == saved.level and game.xp == saved.xp and is_equal_approx(game.xp_fraction, saved.xp_fraction), "retry restores growth and currencies from checkpoint instead of failed combat")
	check(game.selected_skin == saved.skin and game.rerolls_left == saved.rerolls and game.run_id == saved.run_id and game.cleared_stages == 3, "retry preserves skin, rerolls, run reward identity and cleared stages")
	check(game.campaign.profile == inventory and game.hp == game.max_hp and game.max_hp > before_hp, "retry retains purchased equipment and resumes at full upgraded health")
	check(not game.continue_checkpoint(), "continuing cannot reset an already active fight")
	game.return_to_title()
	game.open_workshop()
	check(game.mode == game.Mode.REST and game.rest_from_title, "title can open permanent equipment management")
	game.leave_workshop()
	check(game.mode == game.Mode.READY and game.campaign.checkpoint == saved, "leaving the title workshop preserves the checkpoint without skipping a stage")
	check(game.continue_checkpoint() and game.stage_index == 4, "title continue returns to the same saved stage")
	game.begin_stage(6)
	_defeat_boss()
	check(game.mode == game.Mode.REST and game.stage_index == 6 and game.campaign.checkpoint.stage == 7, "sixth boss opens another workshop and banks stage seven")
	var before_speed: float = game.movement_speed()
	check(game.upgrade_equipment("boots") and game.movement_speed() > before_speed, "later boss materials can improve permanent movement equipment")
	var earned: int = game.campaign.profile.materials
	check(game.campaign.reward_sector(2, game.run_id) == 0 and game.campaign.profile.materials == earned, "second sector reward is also idempotent")
	game.leave_workshop()
	check(game.stage_index == 7 and game.mode == game.Mode.PLAYING and game.sector_index() == 3 and game.stage_in_sector() == 1, "second workshop continues into a third sector")
	game.elapsed = 179.99
	game.step_game(0.01, Vector2.ZERO)
	check(game.mode == game.Mode.TRANSITION, "later ordinary stages retain the short three-minute clear rule")
	game.step_game(3.3, Vector2.ZERO)
	check(game.stage_index == 8 and game.mode == game.Mode.PLAYING and game.world.current_theme == 1, "later intermission advances into the next themed ward")
	var permanent: Dictionary = game.campaign.profile.equipment.duplicate()
	game.start_run()
	check(game.stage_index == 1 and game.progression.mastery.is_empty() and game.progression.traits.is_empty() and game.campaign.profile.equipment == permanent and game.max_hp > 100.0, "new expedition resets its build while retaining permanent equipment")


func _defeat_boss() -> void:
	var boss: Dictionary = game.boss_enemy()
	if boss.is_empty():
		check(false, "boss exists before simulated defeat")
		return
	game._damage_enemy(boss, float(boss.hp) + 1.0)
	game._check_stage_end()


func _target(point: Vector2, kind: String = "normal") -> Dictionary:
	var enemy: Dictionary = game.make_enemy(point, kind)
	enemy.hp = 1000000.0
	enemy.max_hp = 1000000.0
	return enemy


func _test_weapon_damage() -> void:
	game.start_run()
	game.begin_stage(3)
	game.enemies.clear()
	for weapon: String in ["syringe", "pulse", "guardian", "lightning", "rocket", "brick", "soccer", "destroyer"]:
		game.progression.weapons = {weapon: 6}
		game.progression.mastery = {weapon: 4}
		game.progression.traits = {}
		var enemy := _target(game.hero + Vector2(100, 0))
		game._damage_enemy(enemy, 10.0, weapon)
		check(is_equal_approx(1000000.0 - float(enemy.hp), 16.0), "%s damage receives its own mastery exactly once" % weapon)
	game.progression.weapons = {"syringe": 6, "pulse": 6}
	game.progression.mastery = {"syringe": 4, "pulse": 4}
	game.progression.traits = {"syringe": "focus"}
	var normal := _target(game.hero + Vector2(100, 0))
	var boss := _target(game.hero + Vector2(100, 0), "boss")
	game._damage_enemy(normal, 10.0, "syringe")
	game._damage_enemy(boss, 10.0, "syringe")
	check(is_equal_approx(1000000.0 - float(normal.hp), 16.0) and is_equal_approx(1000000.0 - float(boss.hp), 22.4), "focus adds forty percent only against bosses after mastery")
	var untyped := _target(game.hero + Vector2(100, 0))
	game._damage_enemy(untyped, 10.0)
	check(is_equal_approx(1000000.0 - float(untyped.hp), 10.0), "unattributed pickup damage does not inherit weapon mastery")
	game.progression.traits = {"syringe": "blast"}
	var primary := _target(game.hero + Vector2(100, 0))
	var secondary := _target(game.hero + Vector2(130, 0))
	var distant := _target(game.hero + Vector2(350, 0))
	game.enemies.assign([primary, secondary, distant])
	game._damage_enemy(primary, 40.0, "syringe")
	check(is_equal_approx(1000000.0 - float(primary.hp), 64.0) and is_equal_approx(1000000.0 - float(secondary.hp), 16.0) and distant.hp == 1000000.0, "blast splashes twenty-five percent nearby without recursive or distant damage")
	game.progression.traits = {}
	game._recompute_stats()
	var syringe_target := _target(game.hero + Vector2(60, 0))
	game.enemies.assign([syringe_target])
	game._auto_fire()
	game.shots.resize(1)
	game._update_shots(0.05)
	check(is_equal_approx(1000000.0 - float(syringe_target.hp), game.damage * 1.6), "live syringe projectile path carries mastery to impact")
	var pulse_target := _target(game.hero + Vector2(100, 0))
	game.enemies.assign([pulse_target])
	game.fire_pulse()
	check(is_equal_approx(1000000.0 - float(pulse_target.hp), (30.0 + 6.0 * 18.0) * game.attack_multiplier() * 1.6), "live pulse path applies its own mastery multiplier")


func _test_scaling_and_bounds() -> void:
	game.start_run()
	game.begin_stage(4)
	var earlier: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "normal")
	var labels: Array[String] = []
	for index in [4, 7, 10]:
		game.begin_stage(index)
		labels.append(game.encounter_label())
	check(labels[0] != labels[1] and labels[1] != labels[2] and labels[0] != labels[2], "later sectors rotate distinct encounter rules")
	game.begin_stage(1000)
	check(game.stage_index == 1000 and game.stage_in_sector() == 1 and game.sector_index() == 334 and not game.is_boss_stage(), "stage one thousand maps to a valid ordinary ward without ending")
	var safe := is_finite(game.enemy_health_multiplier()) and is_finite(game.enemy_damage_multiplier())
	for kind: String in ["normal", "fast", "elite", "boss", "tank", "ranged", "rusher"]:
		var enemy: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), kind)
		safe = safe and is_finite(float(enemy.hp)) and float(enemy.hp) > 0.0 and is_finite(float(enemy.speed)) and float(enemy.speed) > 0.0 and float(enemy.speed) < 200.0
	var later: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "normal")
	check(safe and later.hp > earlier.hp, "very late enemies keep growing with finite health and bounded movement")
	game.enemies.clear()
	for _index in range(200):
		game.spawn_enemy()
	check(game.enemies.size() <= game.MAX_ENEMIES and game.enemies.size() > 0, "late normal spawns retain the forty-eight-enemy performance cap")
	game.campaign.profile.equipment.boots = 1000000
	check(is_finite(game.movement_speed()) and game.movement_speed() <= 285.0 * 1.25, "permanent movement growth approaches a safe speed ceiling")
	game.progression.supplies = {"cooldown": 5, "armor": 5}
	game._recompute_stats()
	check(game.cooldown_multiplier() >= 0.6 and game.fire_interval > 0.0, "late equipment retains a positive firing interval")
	game.enemies.clear()
	game.enemy_shots.clear()
	game.begin_stage(1002)
	check(game.is_boss_stage() and game._kind_count("boss") == 1 and game.world.current_theme == 2, "late multiples of three still spawn one boss in the arena")
	game.enemies.clear()
	var ranged: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "ranged")
	ranged.clock = 0.0
	game._variant_attack(ranged, 0.01)
	check(ranged.attack == "shot_warning" and game.enemy_shots.is_empty(), "ranged enemy warns before launching its first projectile")
	game._variant_attack(ranged, 1.0)
	check(game.enemy_shots.size() == 1 and ranged.attack == "chase", "ranged warning resolves into a projectile and recovery interval")
	var rusher: Dictionary = game.make_enemy(game.hero + Vector2(200, 0), "rusher")
	rusher.clock = 0.0
	game._variant_attack(rusher, 0.01)
	var locked: Vector2 = rusher.aim
	game.hero += Vector2(0, 60)
	game._variant_attack(rusher, 1.0)
	check(rusher.attack == "charge" and rusher.aim == locked, "rusher keeps its warned direction when the hero dodges")
	for _index in range(200):
		game._spawn_enemy_shot(game.hero + Vector2(200, 0), Vector2.RIGHT, 230.0, 12.0)
	check(game.enemy_shots.size() == 80, "enemy projectiles stop at eighty even in very late sectors")
	game._update_enemy_shots(5.0)
	check(game.enemy_shots.is_empty(), "enemy projectiles expire and release their bounded slots")
	var tank := _target(game.hero + Vector2(200, 0), "tank")
	var normal := _target(game.hero + Vector2(200, 0))
	game._damage_enemy(tank, 100.0)
	game._damage_enemy(normal, 100.0)
	check(is_equal_approx(1000000.0 - float(tank.hp), 65.0) and is_equal_approx(1000000.0 - float(normal.hp), 100.0), "tank enemy has a distinct damage-resistance rule")
	game.campaign.profile.equipment.coat = 1000000
	game._recompute_stats()
	game.hp = game.max_hp
	game.invulnerable = 0.0
	var before_hp: float = game.hp
	game.take_damage(10.0)
	check(game.hp < before_hp and before_hp - game.hp < 10.0 * game.enemy_damage_multiplier(), "high armor mitigates scaled damage without ever making the hero immune")
