extends SceneTree
## Real filesystem integration, isolated under res://test-output. No user:// access.
const CampaignScript = preload("res://scripts/hospital_campaign.gd")
var game
var checks := 0
var failures := 0
var sandbox := ""
var campaign_path := ""
var record_path := ""


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
	sandbox = "res://test-output/endless-persistence-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	campaign_path = sandbox.path_join("campaign.json")
	record_path = sandbox.path_join("records.cfg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	_new_game()
	_test_real_save_and_retry()
	game.free()
	_new_game()
	_test_fresh_load_and_failed_bank()
	game.free()
	_cleanup()
	print("ENDLESS PERSISTENCE COMPLETE | ", checks, " checks | ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _new_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	# _ready also calls _load_records, so override BOTH destinations before adding.
	game.testing = true
	game.muted = true
	game.record_path = record_path
	game.campaign.path = campaign_path
	root.add_child(game)
	_disable_processing(game)
	game.testing = false
	# Simulate real startup only after all save destinations are isolated.
	game._load_records()
	game.audio.sync(true, true, false, 0.0)


func _disable_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_processing(child)


func _disk_snapshot() -> Dictionary:
	var reader = CampaignScript.new()
	reader.path = campaign_path
	if not reader.load_profile():
		return {}
	return {"profile": reader.profile.duplicate(true), "checkpoint": reader.checkpoint.duplicate(true)}


func _resume_if_paused() -> void:
	# A headless host may report window focus loss; normal resume is sufficient.
	if game.mode == game.Mode.PAUSED:
		game.resume_run()


func _defeat_boss() -> void:
	_resume_if_paused()
	var boss: Dictionary = game.boss_enemy()
	if boss.is_empty():
		check(false, "boss exists before persistence fixture defeat")
		return
	game._damage_enemy(boss, float(boss.hp) + 1.0)
	game._check_stage_end()


func _test_real_save_and_retry() -> void:
	game.start_run()
	var disk := _disk_snapshot()
	check(FileAccess.file_exists(campaign_path) and disk.checkpoint.stage == 1 and disk.profile.materials == 0, "new expedition writes a readable first-stage checkpoint through real I/O")
	game.progression.restore({"weapons": {"syringe": 6}, "supplies": {"experience": 1}, "mastery": {"syringe": 7}, "traits": {"syringe": "focus"}})
	game._recompute_stats()
	game.level = 12
	game.xp = 3
	game.xp_fraction = 0.25
	game.kills = 32
	game.total_elapsed = 123.0
	game._gain_coins(30)
	game.begin_stage(3)
	_defeat_boss()
	disk = _disk_snapshot()
	check(game.mode == game.Mode.REST and not game.checkpoint_pending and disk.checkpoint.stage == 4 and disk.profile.materials == 11, "boss completion atomically banks stage four and sector materials on disk")
	check(disk.checkpoint.run_id == game.run_id and disk.checkpoint.progression.mastery.syringe == 7 and disk.checkpoint.progression.traits.syringe == "focus", "real checkpoint retains run identity, mastery and trait")
	check(game.upgrade_equipment("coat"), "workshop equipment purchase succeeds through real profile persistence")
	disk = _disk_snapshot()
	check(disk.profile.equipment.coat == 1 and disk.profile.materials == 6 and disk.checkpoint.stage == 4, "equipment write preserves checkpoint and spends materials exactly once")
	game.leave_workshop()
	_resume_if_paused()
	game._gain_coins(10)
	check(game.coins == 40 and game.total_coins == 40, "newly collected coins update lifetime totals when collected")
	game.finish(false)
	game.finish(false)
	check(game.total_coins == 40, "repeated finish cannot recount the carried coin balance")
	var retries_ok := true
	for _retry in range(2):
		retries_ok = game.continue_checkpoint() and retries_ok
		_resume_if_paused()
		retries_ok = retries_ok and game.coins == 30 and game.total_coins == 40
		game.finish(false)
		retries_ok = retries_ok and game.total_coins == 40
	check(retries_ok, "checkpoint death retries restore carried coins without adding them to lifetime totals again")
	var records := ConfigFile.new()
	check(records.load(record_path) == OK and int(records.get_value("records", "coins", -1)) == 40, "real record file contains only actually collected lifetime coins")


func _test_fresh_load_and_failed_bank() -> void:
	check(game.total_coins == 40, "fresh scene loads lifetime records from the isolated record file")
	check(game.campaign.load_profile(), "fresh campaign instance loads the persisted profile and checkpoint")
	var saved: Dictionary = game.campaign.checkpoint.duplicate(true)
	check(game.continue_checkpoint(), "fresh scene can continue a persisted checkpoint")
	_resume_if_paused()
	check(game.stage_index == 4 and game.run_id == saved.run_id and game.progression.serialize() == saved.progression and game.campaign.equipment_level("coat") == 1, "fresh continuation restores stage, run identity, mastery, trait and equipment")
	check(game.hp == game.max_hp and game.max_hp > 100.0 and game.coins == 30 and game.total_coins == 40, "fresh continuation heals to upgraded maximum without recounting saved coins")
	var previous_profile: Dictionary = game.campaign.profile.duplicate(true)
	var previous_checkpoint: Dictionary = game.campaign.checkpoint.duplicate(true)
	var previous_file := FileAccess.get_file_as_string(campaign_path)
	var blocker_path := sandbox.path_join("not-a-directory")
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("Persistence test blocker. This is an ordinary file.")
	blocker.close()
	game.campaign.path = blocker_path.path_join("campaign.json")
	game.begin_stage(6)
	_defeat_boss()
	check(game.mode == game.Mode.REST and game.checkpoint_pending and not game.campaign.error_message.is_empty(), "failed sector save leaves the hero in the workshop with a pending retry")
	check(game.campaign.profile == previous_profile and game.campaign.checkpoint == previous_checkpoint and FileAccess.get_file_as_string(campaign_path) == previous_file, "failed bank rolls back rewards and checkpoint while preserving the prior disk payload")
	check(not game.upgrade_equipment("coat") and game.campaign.profile == previous_profile, "equipment spending is blocked until the pending sector is safely banked")
	game.leave_workshop()
	check(game.mode == game.Mode.REST and game.checkpoint_pending and game.campaign.profile == previous_profile, "retrying a still-invalid destination cannot leave the workshop or duplicate rewards")
	game.campaign.path = campaign_path
	game.leave_workshop()
	_resume_if_paused()
	var disk := _disk_snapshot()
	check(game.stage_index == 7 and not game.checkpoint_pending and disk.checkpoint.stage == 7, "restoring a writable destination banks the pending sector and resumes stage seven")
	check(game.campaign.profile.materials == int(previous_profile.materials) + 14 and disk.profile.materials == game.campaign.profile.materials and disk.profile.rewarded_sector == 2, "successful recovery grants the second-sector materials exactly once")
	var material_balance: int = game.campaign.profile.materials
	game.leave_workshop()
	game.finish(false)
	check(game.continue_checkpoint(), "recovered real checkpoint remains resumable after another death")
	_resume_if_paused()
	check(game.stage_index == 7 and game.campaign.profile.materials == material_balance and game.total_coins == 40, "repeat leave and death/retry cannot repeat banked materials or carried coins")


func _cleanup() -> void:
	# Exact test-owned leaves only; no recursive deletion or user profile access.
	for name in ["campaign.json", "campaign.json.bak", "campaign.json.tmp", "records.cfg", "not-a-directory"]:
		var path := sandbox.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
