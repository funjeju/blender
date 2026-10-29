extends SceneTree
## Reward cadence and XP preservation, using in-memory saves only.

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
	_test_burst_and_duplicate_input()
	_test_selection_grace()
	_test_combat_time_only()
	_test_stage_completion()
	_test_checkpoint_and_new_run()
	_test_chests()
	print("REWARD PACING COMPLETE | ", checks, " checks | ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _quiet_combat() -> void:
	game.enemies.clear()
	game.enemy_shots.clear()
	game.shots.clear()
	game.gems.clear()
	game.gem_amounts.clear()
	game.pickups.clear()
	game.spawn_clock = 10000
	game.elite_clock = 10000
	game.loot_clock = 10000


func _test_burst_and_duplicate_input() -> void:
	game.start_run()
	game.rng.seed = 261025
	_quiet_combat()
	game._spawn_gem(game.hero, 120)
	game.collect_pickup("magnet")
	game._update_gems(0.1)
	check(game.mode == game.Mode.CHOOSING and game.level == 2 and game.xp == 114, "magnet burst opens exactly one level and preserves the remaining XP")
	var first_revision: int = game.choice_revision
	game.choose_upgrade(0, first_revision)
	var build: Dictionary = game.progression.serialize().duplicate(true)
	check(game.mode == game.Mode.PLAYING and game.upgrade_choices.is_empty() and game.level == 2 and game.xp == 114, "selection resumes combat despite several banked rewards")
	check(is_equal_approx(game.upgrade_cooldown, game.UPGRADE_COMBAT_INTERVAL), "selection starts the configured combat interval")
	game.choose_upgrade(0, first_revision)
	game.reroll_upgrades(first_revision)
	game._check_level_up()
	check(game.mode == game.Mode.PLAYING and game.progression.serialize() == build and game.xp == 114 and game.rerolls_left == 1, "duplicate input and polling cannot consume rewards during combat")
	game.step_game(game.UPGRADE_COMBAT_INTERVAL - 0.5, Vector2.ZERO)
	check(game.mode == game.Mode.PLAYING and game.level == 2 and game.xp == 114, "banked XP does not interrupt the protected combat interval")
	game.step_game(0.5, Vector2.ZERO)
	check(game.mode == game.Mode.CHOOSING and game.level == 3 and game.xp == 106, "next reward opens once after the configured actual combat time")
	game.choose_upgrade(0, first_revision)
	game.reroll_upgrades(first_revision)
	check(game.mode == game.Mode.CHOOSING and game.progression.serialize() == build and game.rerolls_left == 1, "stale choice and reroll events cannot affect the new reward")
	game.choose_upgrade(0, game.choice_revision)
	check(game.mode == game.Mode.PLAYING and game.level == 3 and game.xp == 106, "second valid selection resumes combat with all remaining XP")


func _test_selection_grace() -> void:
	game.start_run()
	_quiet_combat()
	game.xp = game.xp_needed()
	game._check_level_up()
	var revision: int = game.choice_revision
	game.choose_upgrade(-1, revision)
	check(game.mode == game.Mode.CHOOSING and game.invulnerable == 0, "invalid choice does not grant resume protection")
	game.choose_upgrade(0, revision)
	var health: float = game.hp
	game.take_damage(9)
	check(is_equal_approx(game.invulnerable, 0.75) and game.hp == health, "valid selection grants a short grace period against immediate contact damage")
	game.step_game(0.5, Vector2.ZERO)
	game.choose_upgrade(0, revision)
	check(is_equal_approx(game.invulnerable, 0.25), "duplicate selection cannot refresh the protection during combat")
	game.step_game(0.25, Vector2.ZERO)
	game.take_damage(9)
	check(game.hp < health, "normal enemy damage resumes after the short grace period expires")
	game.upgrade_cooldown = 0
	game.xp = game.xp_needed()
	game._check_level_up()
	game.invulnerable = 0.1
	game.choose_upgrade(0, revision)
	check(game.mode == game.Mode.CHOOSING and is_equal_approx(game.invulnerable, 0.1), "stale selection cannot grant protection for a subsequent reward")
	game.invulnerable = 2.0
	game.choose_upgrade(0, game.choice_revision)
	check(game.mode == game.Mode.PLAYING and game.invulnerable == 2.0, "valid selection preserves longer protection already in effect")


func _test_combat_time_only() -> void:
	game.start_run()
	_quiet_combat()
	game.xp = 100
	game._check_level_up()
	game.choose_upgrade(0)
	game.pause_run("test")
	game.step_game(30, Vector2.ZERO)
	check(game.mode == game.Mode.PAUSED and game.upgrade_cooldown == game.UPGRADE_COMBAT_INTERVAL, "pause time cannot spend the combat interval")
	game.resume_run()
	game.mode = game.Mode.TRANSITION
	game.transition_left = 3.2
	game.step_game(1, Vector2.ZERO)
	check(game.upgrade_cooldown == game.UPGRADE_COMBAT_INTERVAL, "intermission time cannot spend the combat interval")
	game.step_game(3, Vector2.ZERO)
	check(game.mode == game.Mode.PLAYING and game.stage_index == 2 and game.upgrade_cooldown == game.UPGRADE_COMBAT_INTERVAL, "stage transitions retain the remaining combat interval")
	_quiet_combat()
	game.mode = game.Mode.REST
	game.step_game(30, Vector2.ZERO)
	check(game.mode == game.Mode.REST and game.upgrade_cooldown == game.UPGRADE_COMBAT_INTERVAL, "workshop time cannot spend the combat interval")
	game.mode = game.Mode.PLAYING
	game.elapsed = game.DURATION - 0.5
	game.step_game(2, Vector2.ZERO)
	check(is_equal_approx(game.upgrade_cooldown, game.UPGRADE_COMBAT_INTERVAL - 0.5), "only actual remaining stage time counts toward reward cadence")


func _test_stage_completion() -> void:
	game.start_run()
	_quiet_combat()
	game.elapsed = game.DURATION
	game.xp = 120
	game._check_level_up()
	game.choose_upgrade(0)
	check(game.mode == game.Mode.TRANSITION and game.level == 2 and game.xp == 114, "last-second selection lets a cleared stage advance without draining queued XP")
	game.step_game(4, Vector2.ZERO)
	check(game.mode == game.Mode.PLAYING and game.stage_index == 2 and game.level == 2 and game.xp == 114, "new stage begins in combat with rewards still banked")


func _test_checkpoint_and_new_run() -> void:
	game.start_run()
	game.level = 10
	game.xp = 120
	check(game._save_checkpoint(4), "buffered XP can be banked in an in-memory checkpoint")
	game.return_to_title()
	check(game.continue_checkpoint(), "checkpoint resumes successfully with buffered rewards")
	check(game.mode == game.Mode.PLAYING and game.stage_index == 4 and game.level == 10 and game.xp == 120 and game.upgrade_cooldown == game.UPGRADE_COMBAT_INTERVAL, "checkpoint resumes combat before showing a queued reward")
	_quiet_combat()
	game.step_game(game.UPGRADE_COMBAT_INTERVAL, Vector2.ZERO)
	check(game.mode == game.Mode.CHOOSING and game.level == 11 and game.xp == 96, "checkpoint XP grants its next reward after the combat interval")
	game.choose_upgrade(0)
	game.start_run()
	check(game.upgrade_cooldown == 0 and game.level == 1 and game.xp == 0, "new expedition clears the previous reward interval")
	game.xp = game.xp_needed()
	game._check_level_up()
	check(game.mode == game.Mode.CHOOSING and game.level == 2, "first earned reward remains immediately available in a new expedition")


func _test_chests() -> void:
	game.start_run()
	game.open_chest(3)
	check(game.mode == game.Mode.PLAYING and game.progression.get_level("syringe") == 4 and game.upgrade_choices.is_empty(), "multi-reward chest upgrades gear immediately without opening a selection")
	check(game.upgrade_cooldown == 0 and game.xp == 0, "automatic chest rewards do not consume or postpone level-up XP")
