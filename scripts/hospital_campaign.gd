extends RefCounted
## Local permanent equipment and resumable boss checkpoints.
## Tests override path; loading never writes or silently resets an unreadable save.

const ProgressionScript = preload("res://scripts/hospital_progression.gd")
const VERSION := 1
const MAX_STAGE := 1000000000
const MAX_SECTOR := 333333333
const MAX_EQUIPMENT_LEVEL := 1000000
const MAX_CURRENCY := 1000000000000
const MAX_FILE_BYTES := 131072
const EQUIPMENT_SLOTS := ["coat", "gloves", "boots"]

var profile: Dictionary = {
	"materials": 0,
	"equipment": {"coat": 0, "gloves": 0, "boots": 0},
	"highest_stage": 1,
	"rewarded_sector": 0,
	"reward_run_id": "",
}
var checkpoint: Dictionary = {}
var path := "user://hospital_campaign_v1.json"
var error_message := ""
var has_load_error := false
var recovered_backup := false


func load_profile() -> bool:
	error_message = ""
	recovered_backup = false
	var primary_exists := FileAccess.file_exists(path)
	var backup_exists := FileAccess.file_exists(path + ".bak")
	if not primary_exists and not backup_exists:
		has_load_error = false
		return true
	var payload := _read_payload(path) if primary_exists else {}
	if payload.is_empty() and backup_exists:
		payload = _read_payload(path + ".bak")
		recovered_backup = not payload.is_empty()
	if payload.is_empty():
		has_load_error = true
		error_message = "저장 파일과 백업을 읽지 못했습니다. 기존 파일은 보존됩니다. 새 원정을 시작하면 새 저장을 만듭니다."
		return false
	profile = payload["profile"]
	checkpoint = payload["checkpoint"]
	has_load_error = false
	if recovered_backup:
		error_message = "저장 파일을 백업에서 복구했습니다."
	return true


func save_profile() -> bool:
	# An explicit save may replace a failed load; preserve corrupt originals first.
	return _save_current(true)


func update_checkpoint(snapshot: Dictionary, replace_corrupt: bool = false) -> bool:
	var validated := _validated_checkpoint(snapshot)
	if validated.is_empty() and not snapshot.is_empty():
		error_message = "체크포인트 데이터가 올바르지 않아 저장하지 않았습니다."
		return false
	var previous := checkpoint.duplicate(true)
	checkpoint = validated
	if _save_current(replace_corrupt):
		return true
	checkpoint = previous
	return false


func reward_sector(sector: int, run_id: String = "legacy") -> int:
	if sector < 1 or sector > MAX_SECTOR or not _valid_run_id(run_id):
		return 0
	if str(profile.get("reward_run_id", "")) != run_id:
		profile["reward_run_id"] = run_id
		profile["rewarded_sector"] = 0
	if sector <= int(profile["rewarded_sector"]):
		return 0
	var previous_materials := int(profile["materials"])
	profile["materials"] = mini(MAX_CURRENCY, previous_materials + 8 + sector * 3)
	profile["rewarded_sector"] = sector
	profile["highest_stage"] = maxi(int(profile["highest_stage"]), mini(MAX_STAGE, sector * 3 + 1))
	return int(profile["materials"]) - previous_materials


func equipment_level(slot: String) -> int:
	return int(profile["equipment"].get(slot, 0)) if slot in EQUIPMENT_SLOTS else 0


func upgrade_cost(slot: String) -> int:
	return 5 + 3 * equipment_level(slot) if slot in EQUIPMENT_SLOTS else -1


func upgrade(slot: String) -> bool:
	if slot not in EQUIPMENT_SLOTS or equipment_level(slot) >= MAX_EQUIPMENT_LEVEL:
		error_message = "강화할 수 없는 장비입니다."
		return false
	var cost := upgrade_cost(slot)
	if int(profile["materials"]) < cost:
		error_message = "강화 재료가 부족합니다."
		return false
	var previous := profile.duplicate(true)
	profile["materials"] = int(profile["materials"]) - cost
	profile["equipment"][slot] = equipment_level(slot) + 1
	if _save_current(false):
		return true
	profile = previous
	return false


func _save_current(replace_corrupt: bool) -> bool:
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		error_message = "브라우저 저장소를 사용할 수 없습니다. 사이트 데이터 저장을 허용한 뒤 다시 열어 주세요."
		return false
	if has_load_error and not replace_corrupt:
		error_message = "기존 저장 파일을 읽을 수 없습니다. 새 원정에서 새 저장을 시작해 주세요."
		return false
	var document := _validated_document({"version": VERSION, "profile": profile, "checkpoint": checkpoint})
	if document.is_empty():
		error_message = "저장 데이터 검증에 실패했습니다. 기존 저장은 변경하지 않았습니다."
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary := absolute_path + ".tmp"
	var backup := absolute_path + ".bak"
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		error_message = "저장 폴더를 만들 수 없습니다."
		return false
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error_message = "임시 저장 파일을 만들 수 없습니다."
		return false
	file.store_string(JSON.stringify(document))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_payload(temporary).is_empty():
		DirAccess.remove_absolute(temporary)
		error_message = "저장 파일 쓰기를 완료하지 못했습니다."
		return false
	# A bad primary must never replace the known-good backup. Keep corruption for
	# recovery, including when the player deliberately starts a new expedition.
	var prior_primary := ""
	if FileAccess.file_exists(absolute_path):
		var primary_valid := not _read_payload(absolute_path).is_empty()
		prior_primary = backup if primary_valid else _corrupt_path(absolute_path)
		if primary_valid and FileAccess.file_exists(backup):
			if DirAccess.remove_absolute(backup) != OK:
				return _save_failure(temporary, "이전 백업 파일을 갱신할 수 없습니다.")
		if DirAccess.rename_absolute(absolute_path, prior_primary) != OK:
			return _save_failure(temporary, "기존 저장 파일을 보존할 수 없습니다.")
	if DirAccess.rename_absolute(temporary, absolute_path) != OK:
		if not prior_primary.is_empty():
			DirAccess.rename_absolute(prior_primary, absolute_path)
		return _save_failure(temporary, "새 저장 파일로 교체할 수 없습니다.")
	error_message = ""
	has_load_error = false
	recovered_backup = false
	return true


func _save_failure(temporary: String, message: String) -> bool:
	DirAccess.remove_absolute(temporary)
	error_message = message
	return false


func _corrupt_path(original: String) -> String:
	var candidate := original + ".corrupt." + str(Time.get_ticks_usec())
	while FileAccess.file_exists(candidate):
		candidate += "_"
	return candidate


func _read_payload(filename: String) -> Dictionary:
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return {}
	return _validated_document(json.data)


func _validated_document(data: Dictionary) -> Dictionary:
	if not _bounded_tree(data) or not _keys_match(data, ["version", "profile", "checkpoint"]):
		return {}
	if not _integer(data["version"], VERSION, VERSION):
		return {}
	if not data["profile"] is Dictionary or not data["checkpoint"] is Dictionary:
		return {}
	var validated_profile := _validated_profile(data["profile"])
	var validated_checkpoint := _validated_checkpoint(data["checkpoint"])
	if validated_profile.is_empty() or (validated_checkpoint.is_empty() and not data["checkpoint"].is_empty()):
		return {}
	return {"version": VERSION, "profile": validated_profile, "checkpoint": validated_checkpoint}


func _validated_profile(data: Dictionary) -> Dictionary:
	if not _keys_match(data, ["materials", "equipment", "highest_stage", "rewarded_sector", "reward_run_id"]):
		return {}
	if not _integer(data["materials"], 0, MAX_CURRENCY) or not _integer(data["highest_stage"], 1, MAX_STAGE):
		return {}
	if not _integer(data["rewarded_sector"], 0, MAX_SECTOR):
		return {}
	if not data["reward_run_id"] is String or (data["reward_run_id"] != "" and not _valid_run_id(data["reward_run_id"])):
		return {}
	if int(data["rewarded_sector"]) > 0 and data["reward_run_id"] == "":
		return {}
	if not data["equipment"] is Dictionary or not _keys_match(data["equipment"], EQUIPMENT_SLOTS):
		return {}
	var equipment := {}
	for slot in EQUIPMENT_SLOTS:
		if not _integer(data["equipment"][slot], 0, MAX_EQUIPMENT_LEVEL):
			return {}
		equipment[slot] = int(data["equipment"][slot])
	return {
		"materials": int(data["materials"]), "equipment": equipment,
		"highest_stage": int(data["highest_stage"]), "rewarded_sector": int(data["rewarded_sector"]),
		"reward_run_id": data["reward_run_id"],
	}


func _validated_checkpoint(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var keys := ["stage", "level", "xp", "xp_fraction", "kills", "coins", "total_elapsed", "rerolls", "skin", "progression", "seed", "rng_state", "run_id"]
	if not _bounded_tree(data) or not _keys_match(data, keys):
		return {}
	if not _integer(data["stage"], 1, MAX_STAGE) or not _integer(data["level"], 1, MAX_STAGE):
		return {}
	for key in ["xp", "kills", "coins"]:
		if not _integer(data[key], 0, MAX_CURRENCY):
			return {}
	if not _number(data["xp_fraction"], 0.0, 1.0) or not _number(data["total_elapsed"], 0.0, float(MAX_CURRENCY)):
		return {}
	if not _integer(data["rerolls"], 0, 1) or not _integer(data["skin"], 0, 1):
		return {}
	if not _valid_run_id(data["run_id"]) or not _decimal_int64(data["seed"]) or not _decimal_int64(data["rng_state"]):
		return {}
	if not data["progression"] is Dictionary or not _keys_match(data["progression"], ["weapons", "supplies", "mastery", "traits"]):
		return {}
	var progression = ProgressionScript.new()
	if not progression.restore(data["progression"]):
		return {}
	var result := data.duplicate(true)
	for key in ["stage", "level", "xp", "kills", "coins", "rerolls", "skin"]:
		result[key] = int(data[key])
	result["xp_fraction"] = float(data["xp_fraction"])
	result["total_elapsed"] = float(data["total_elapsed"])
	result["progression"] = progression.serialize()
	return result


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _decimal_int64(value: Variant) -> bool:
	return value is String and value.length() <= 20 and value.is_valid_int() and str(value.to_int()) == value


func _valid_run_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true


func _keys_match(data: Dictionary, keys: Array) -> bool:
	if data.size() != keys.size():
		return false
	for key in keys:
		if not data.has(key):
			return false
	return true


func _bounded_tree(value: Variant, depth: int = 0, budget: Array = [512]) -> bool:
	# Pass a fresh counter on the top-level call; no huge/deep nested save payloads.
	if depth == 0:
		budget = [512]
	budget[0] -= 1
	if budget[0] < 0 or depth > 8:
		return false
	if value is Dictionary:
		if value.size() > 64:
			return false
		for key in value:
			if not key is String or key.length() > 128 or not _bounded_tree(value[key], depth + 1, budget):
				return false
	elif value is Array:
		if value.size() > 64:
			return false
		for child in value:
			if not _bounded_tree(child, depth + 1, budget):
				return false
	elif value is String:
		return value.length() <= 256
	elif not (value is int or value is float or value is bool or value == null):
		return false
	return true
