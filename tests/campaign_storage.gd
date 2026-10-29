extends SceneTree
## Persistence tests only use a unique res://test-output folder, never user://.

const CampaignScript = preload("res://scripts/hospital_campaign.gd")
var checks := 0
var failures := 0
var sandbox := ""


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
	sandbox = "res://test-output/campaign_storage_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	_test_roundtrip()
	_test_rewards_and_equipment()
	_test_corruption_recovery()
	_test_validation()
	_test_failed_writes()
	_clean_up()
	print("CAMPAIGN STORAGE COMPLETE | ", checks, " checks | ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _campaign(filename: String):
	var campaign = CampaignScript.new()
	campaign.path = sandbox.path_join(filename)
	return campaign


func _snapshot() -> Dictionary:
	return {
		"stage": 4, "level": 12, "xp": 17, "xp_fraction": 0.375,
		"kills": 250, "coins": 91, "total_elapsed": 375.25,
		"rerolls": 1, "skin": 0, "seed": "9223372036854775807",
		"rng_state": "-9223372036854775808", "run_id": "test-expedition-1",
		"progression": {"weapons": {"syringe": 6, "pulse": 2}, "supplies": {"experience": 1}, "mastery": {"syringe": 4}, "traits": {"syringe": "focus"}},
	}


func _write(filename: String, content: String) -> void:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _test_roundtrip() -> void:
	var campaign = _campaign("roundtrip.json")
	check(campaign.load_profile() and campaign.profile.materials == 0 and campaign.checkpoint.is_empty(), "missing save produces a usable new profile without writing")
	check(not FileAccess.file_exists(campaign.path), "loading a new profile does not create a file")
	campaign.profile.materials = 123
	campaign.profile.equipment.coat = 2
	var snapshot := _snapshot()
	check(campaign.update_checkpoint(snapshot), "profile and checkpoint save together")
	snapshot.progression.mastery.syringe = 999
	check(campaign.checkpoint.progression.mastery.syringe == 4, "checkpoint owns a deep copy independent of caller mutations")
	var loaded = _campaign("roundtrip.json")
	check(loaded.load_profile() and loaded.profile == campaign.profile and loaded.checkpoint == campaign.checkpoint, "nested profile and checkpoint roundtrip without losing values")
	check(loaded.checkpoint.stage is int and loaded.profile.materials is int and loaded.checkpoint.progression.mastery.syringe is int, "JSON integers are restored to integer game values")
	check(loaded.checkpoint.seed == "9223372036854775807" and loaded.checkpoint.rng_state == "-9223372036854775808", "RNG signed 64-bit values retain exact decimal strings")
	check(campaign.save_profile() and FileAccess.file_exists(campaign.path + ".bak"), "subsequent atomic save keeps the previous complete payload as backup")
	check(not FileAccess.file_exists(campaign.path + ".tmp"), "successful saves leave no temporary payload")
	loaded.checkpoint.progression.weapons.syringe = 1
	check(campaign.checkpoint.progression.weapons.syringe == 6, "separately loaded profiles do not alias each other")


func _test_rewards_and_equipment() -> void:
	var campaign = _campaign("equipment.json")
	check(campaign.reward_sector(1, "run-a") == 11 and campaign.profile.highest_stage == 4, "first boss grants eleven materials and records stage four")
	check(campaign.reward_sector(1, "run-a") == 0 and campaign.reward_sector(0, "run-a") == 0 and campaign.profile.materials == 11, "same-run repeated and invalid bosses cannot duplicate materials")
	check(campaign.reward_sector(2, "run-a") == 14 and campaign.profile.materials == 25 and campaign.profile.highest_stage == 7, "later sectors increase material rewards and highest stage")
	check(campaign.reward_sector(1, "run-a") == 0, "older bosses in the same saved expedition do not reward again")
	check(campaign.reward_sector(1, "run-b") == 11 and campaign.profile.highest_stage == 7, "fresh expeditions can farm old bosses without losing highest stage")
	check(campaign.upgrade_cost("coat") == 5 and campaign.upgrade("coat") and campaign.equipment_level("coat") == 1 and campaign.profile.materials == 31, "equipment purchase subtracts the correct price and saves its level")
	check(campaign.upgrade_cost("coat") == 8 and campaign.upgrade_cost("boots") == 5, "upgrade prices grow per equipment slot")
	var loaded = _campaign("equipment.json")
	check(loaded.load_profile() and loaded.equipment_level("coat") == 1 and loaded.reward_sector(1, "run-b") == 0, "permanent gear and reward id survive reloading")
	var before: Dictionary = campaign.profile.duplicate(true)
	check(not campaign.upgrade("invalid") and campaign.profile == before and campaign.upgrade_cost("invalid") == -1, "unknown equipment cannot spend materials")
	campaign.profile.materials = 0
	check(not campaign.upgrade("boots") and campaign.equipment_level("boots") == 0, "insufficient materials leave equipment unchanged")
	campaign.profile.materials = CampaignScript.MAX_CURRENCY - 1
	check(campaign.reward_sector(2, "run-b") == 1 and campaign.profile.materials == CampaignScript.MAX_CURRENCY, "materials saturate safely at the finite currency limit")
	campaign.profile.equipment.coat = CampaignScript.MAX_EQUIPMENT_LEVEL
	check(not campaign.upgrade("coat") and campaign.equipment_level("coat") == CampaignScript.MAX_EQUIPMENT_LEVEL, "equipment cannot overflow its practical level limit")


func _test_corruption_recovery() -> void:
	var campaign = _campaign("recovery.json")
	campaign.profile.materials = 10
	campaign.save_profile()
	campaign.profile.materials = 20
	campaign.save_profile()
	_write(campaign.path, "{broken json")
	var recovered = _campaign("recovery.json")
	check(recovered.load_profile() and recovered.recovered_backup and recovered.profile.materials == 10, "corrupt primary recovers the last complete backup")
	check(FileAccess.get_file_as_string(campaign.path) == "{broken json", "backup recovery does not silently rewrite the damaged primary")
	recovered.profile.materials = 15
	check(recovered.save_profile(), "recovered profile can be saved again")
	var backup_content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(campaign.path + ".bak"))
	check(backup_content.profile.materials == 10, "saving after recovery preserves the known-good backup")
	var corrupt_files := 0
	for filename in DirAccess.get_files_at(sandbox):
		if filename.begins_with("recovery.json.corrupt."):
			corrupt_files += 1
	check(corrupt_files == 1, "damaged primary is archived when a deliberate save replaces it")
	_write(campaign.path, "bad-primary")
	_write(campaign.path + ".bak", "bad-backup")
	var previous: Dictionary = recovered.profile.duplicate(true)
	check(not recovered.load_profile() and recovered.has_load_error and recovered.profile == previous, "two corrupt files preserve the valid in-memory profile and expose failure")
	check(not recovered.update_checkpoint(_snapshot()) and FileAccess.get_file_as_string(campaign.path) == "bad-primary", "automatic checkpoints cannot overwrite an unresolved corrupt save")
	check(not recovered.upgrade("boots") and recovered.profile == previous, "upgrades roll back when a corrupt save blocks persistence")
	check(recovered.update_checkpoint(_snapshot(), true) and not recovered.has_load_error, "explicit new expedition can create a new save after corruption")
	check(FileAccess.get_file_as_string(campaign.path + ".bak") == "bad-backup", "explicit replacement keeps the old failed backup available")
	var fresh = _campaign("recovery.json")
	check(fresh.load_profile() and fresh.checkpoint.stage == 4, "explicit replacement produces a loadable checkpoint")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.path))
	_write(campaign.path + ".bak", JSON.stringify({"version": 1, "profile": previous, "checkpoint": _snapshot()}))
	check(fresh.load_profile() and fresh.recovered_backup, "missing primary after an interrupted rename can recover from backup")


func _test_validation() -> void:
	var campaign = _campaign("validation.json")
	check(campaign.update_checkpoint(_snapshot()), "validation fixture begins with a valid checkpoint")
	var original: Dictionary = campaign.checkpoint.duplicate(true)
	var variants: Array[Dictionary] = []
	for change in [{"stage": 0}, {"stage": 1.5}, {"level": -1}, {"xp": -1}, {"coins": CampaignScript.MAX_CURRENCY + 1}, {"xp_fraction": 1.1}, {"xp_fraction": NAN}, {"total_elapsed": INF}, {"rerolls": 2}, {"skin": 2}, {"seed": "9223372036854775808"}, {"rng_state": "1.0"}, {"run_id": ""}]:
		var bad := _snapshot()
		bad.merge(change, true)
		variants.append(bad)
	var missing := _snapshot()
	missing.erase("xp")
	variants.append(missing)
	var unknown := _snapshot()
	unknown["unexpected"] = 1
	variants.append(unknown)
	var invalid_progression := _snapshot()
	invalid_progression.progression.weapons["unknown"] = 1
	variants.append(invalid_progression)
	var oversized := _snapshot()
	oversized.run_id = "a".repeat(129)
	variants.append(oversized)
	var all_rejected := true
	for bad in variants:
		all_rejected = not campaign.update_checkpoint(bad) and campaign.checkpoint == original and all_rejected
	check(all_rejected, "invalid ranges, unknown keys, missing fields, malformed RNG and bad progression reject atomically")
	var before: Dictionary = campaign.profile.duplicate(true)
	campaign.profile.equipment.coat = -1
	var saved_text := FileAccess.get_file_as_string(campaign.path)
	check(not campaign.save_profile() and FileAccess.get_file_as_string(campaign.path) == saved_text, "invalid equipment cannot overwrite a valid save")
	campaign.profile = before
	_write(campaign.path, JSON.stringify({"version": 2, "profile": before, "checkpoint": original}))
	check(not campaign.load_profile() and campaign.profile == before, "unsupported future save versions do not reset valid in-memory state")
	_write(campaign.path, " ".repeat(CampaignScript.MAX_FILE_BYTES + 1))
	check(not campaign.load_profile(), "oversized files reject before JSON parsing")
	var oversized_tree := _snapshot()
	for index in range(65):
		oversized_tree.progression.weapons["extra" + str(index)] = 1
	check(not campaign.update_checkpoint(oversized_tree), "oversized nested containers are rejected")


func _test_failed_writes() -> void:
	var campaign = _campaign("failure.json")
	campaign.profile.materials = 50
	campaign.update_checkpoint(_snapshot())
	var previous_profile: Dictionary = campaign.profile.duplicate(true)
	var previous_checkpoint: Dictionary = campaign.checkpoint.duplicate(true)
	var previous_file := FileAccess.get_file_as_string(campaign.path)
	var temporary := ProjectSettings.globalize_path(campaign.path + ".tmp")
	DirAccess.make_dir_absolute(temporary)
	check(not campaign.upgrade("boots") and campaign.profile == previous_profile, "failed file creation rolls back equipment and material spending")
	var next := _snapshot()
	next.stage = 7
	check(not campaign.update_checkpoint(next) and campaign.checkpoint == previous_checkpoint, "failed checkpoint save rolls back the checkpoint in memory")
	check(FileAccess.get_file_as_string(campaign.path) == previous_file and not campaign.error_message.is_empty(), "failed writes preserve the original file and explain the failure")
	DirAccess.remove_absolute(temporary)
	check(campaign.update_checkpoint(next), "retry succeeds once the write failure is removed")


func _clean_up() -> void:
	# This directory was created exclusively by this test invocation.
	assert(sandbox.begins_with("res://test-output/campaign_storage_"))
	for filename in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
