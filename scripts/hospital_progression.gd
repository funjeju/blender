extends RefCounted
## Local, deterministic loadout rules. Combat effects are applied by hospital.gd.

const MAX_WEAPON_SLOTS := 6
const MAX_SUPPLY_SLOTS := 6
const MAX_LEVEL := 5
const EVOLUTION_LEVEL := 6
const TRAIT_MASTERY_LEVEL := 3
# Largest exactly representable JSON integer. This is a storage safety limit,
# not a reachable gameplay cap (one upgrade per level would take millions of years).
const MAX_SAFE_INTEGER := 9007199254740991

const WEAPONS := {
	"syringe": {
		"name": "자동 주사기", "short": "주사기", "pair": "experience",
		"description": "가까운 적에게 주사침을 자동 발사합니다. 강화하면 발사량과 위력이 증가합니다.",
		"evo_name": "무한 수액포", "color": Color(0.36, 0.9, 0.95),
	},
	"pulse": {
		"name": "살균 파동", "short": "살균파", "pair": "regen",
		"description": "주변의 적을 주기적으로 살균합니다. 강화하면 범위와 피해가 증가합니다.",
		"evo_name": "중환자실 결계", "color": Color(0.34, 0.95, 0.72),
	},
	"guardian": {
		"name": "회전 메스", "short": "회전메스", "pair": "duration",
		"description": "몸 주위를 회전하는 메스로 적을 밀어냅니다. 강화하면 메스 수와 위력이 증가합니다.",
		"evo_name": "무균 수술진", "color": Color(0.73, 0.84, 0.97),
	},
	"lightning": {
		"name": "제세동 낙뢰", "short": "제세동", "pair": "cooldown",
		"description": "적의 위치에 전격을 떨어뜨립니다. 강화하면 타격 수와 피해가 증가합니다.",
		"evo_name": "연쇄 제세동", "color": Color(0.99, 0.86, 0.3),
	},
	"rocket": {
		"name": "응급 로켓", "short": "로켓", "pair": "area",
		"description": "가까운 적에게 폭발하는 응급탄을 발사합니다. 강화하면 폭발 피해가 증가합니다.",
		"evo_name": "격리 구역 폭격", "color": Color(1.0, 0.56, 0.33),
	},
	"brick": {
		"name": "구급 상자 투척", "short": "구급상자", "pair": "health",
		"description": "무거운 구급 상자를 던져 적을 관통합니다. 강화하면 투척 수와 피해가 증가합니다.",
		"evo_name": "중량 구급 탄막", "color": Color(0.9, 0.49, 0.57),
	},
	"soccer": {
		"name": "재활 반사구", "short": "반사구", "pair": "speed",
		"description": "주변에서 튕기는 재활 공으로 적을 공격합니다. 강화하면 공 수와 위력이 증가합니다.",
		"evo_name": "초고속 재활구", "color": Color(0.63, 0.95, 0.45),
	},
	"drone_a": {
		"name": "A형 의료 드론", "short": "드론 A", "pair": "drone_b",
		"description": "의료 드론이 연속 탄환을 발사합니다. A형·B형을 모두 5성으로 만들면 합체합니다.",
		"evo_name": "통합 구조 드론", "color": Color(0.38, 0.71, 1.0),
	},
	"drone_b": {
		"name": "B형 의료 드론", "short": "드론 B", "pair": "drone_a",
		"description": "의료 드론이 확산 탄환을 발사합니다. A형·B형을 모두 5성으로 만들면 합체합니다.",
		"evo_name": "통합 구조 드론", "color": Color(0.91, 0.49, 1.0),
	},
	"destroyer": {
		"name": "통합 구조 드론", "short": "구조드론", "pair": "",
		"description": "두 의료 드론을 합쳐 강력한 탄막을 발사합니다. 무기 슬롯 한 칸이 비워집니다.",
		"evo_name": "통합 구조 드론", "color": Color(1.0, 0.45, 0.72),
	},
}

const SUPPLIES := {
	"experience": {
		"name": "연구 노트", "short": "연구노트",
		"description": "획득 경험치가 단계마다 10% 증가합니다. 자동 주사기의 진화 재료입니다.",
		"color": Color(0.63, 0.72, 1.0),
	},
	"cooldown": {
		"name": "응급 호출기", "short": "호출기",
		"description": "무기 재사용 시간이 단계마다 8% 감소합니다. 제세동 낙뢰의 진화 재료입니다.",
		"color": Color(0.99, 0.86, 0.3),
	},
	"duration": {
		"name": "지속 처방", "short": "지속처방",
		"description": "무기 지속 시간이 단계마다 10% 증가합니다. 회전 메스의 진화 재료입니다.",
		"color": Color(0.73, 0.84, 0.97),
	},
	"area": {
		"name": "확산 증폭기", "short": "증폭기",
		"description": "공격 범위가 단계마다 10% 증가합니다. 응급 로켓의 진화 재료입니다.",
		"color": Color(1.0, 0.56, 0.33),
	},
	"health": {
		"name": "체력 보충제", "short": "보충제",
		"description": "최대 체력이 단계마다 20% 증가합니다. 구급 상자 투척의 진화 재료입니다.",
		"color": Color(0.96, 0.44, 0.54),
	},
	"speed": {
		"name": "의료용 운동화", "short": "운동화",
		"description": "이동 속도가 단계마다 10% 증가합니다. 재활 반사구의 진화 재료입니다.",
		"color": Color(0.63, 0.95, 0.45),
	},
	"attack": {
		"name": "고농축 소독액", "short": "소독액",
		"description": "모든 무기 피해가 단계마다 10% 증가합니다.",
		"color": Color(1.0, 0.57, 0.42),
	},
	"magnet": {
		"name": "자동 수거기", "short": "수거기",
		"description": "경험치와 아이템 수거 범위가 단계마다 100% 증가합니다.",
		"color": Color(0.48, 0.83, 1.0),
	},
	"armor": {
		"name": "방호 가운", "short": "방호가운",
		"description": "받는 피해가 단계마다 10% 감소합니다.",
		"color": Color(0.7, 0.83, 0.94),
	},
	"regen": {
		"name": "회복 수액", "short": "회복수액",
		"description": "5초마다 단계당 최대 체력의 1%를 회복합니다. 살균 파동의 진화 재료입니다.",
		"color": Color(0.34, 0.95, 0.72),
	},
	"projectile": {
		"name": "압력 주입기", "short": "주입기",
		"description": "투사체 속도가 단계마다 10% 증가합니다.",
		"color": Color(0.72, 0.63, 1.0),
	},
	"gold": {
		"name": "보급 명세서", "short": "명세서",
		"description": "획득 코인이 단계마다 10% 증가합니다.",
		"color": Color(1.0, 0.81, 0.37),
	},
}

var weapons: Dictionary = {"syringe": 1}
var supplies: Dictionary = {}
var mastery: Dictionary = {}
var traits: Dictionary = {}


func reset() -> void:
	weapons = {"syringe": 1}
	supplies = {}
	mastery = {}
	traits = {}


func get_level(id: String) -> int:
	return int(weapons.get(id, supplies.get(id, 0)))


func is_evolved(id: String) -> bool:
	return WEAPONS.has(id) and get_level(id) >= EVOLUTION_LEVEL


func damage_multiplier(weapon_id: String) -> float:
	return 1.0 + 0.15 * int(mastery.get(weapon_id, 0)) if is_evolved(weapon_id) else 1.0


func trait_for(weapon_id: String) -> String:
	return String(traits.get(weapon_id, "")) if is_evolved(weapon_id) else ""


func is_owned_upgrade(id: String) -> bool:
	# Chests may grant mastery, but the player must choose a permanent trait.
	if id.begins_with("mastery:"):
		var parts := id.split(":")
		return parts.size() == 2 and is_evolved(parts[1])
	return weapons.has(id) or supplies.has(id)


func can_evolve(id: String) -> bool:
	if id == "destroyer":
		return not weapons.has("destroyer") and get_level("drone_a") == MAX_LEVEL and get_level("drone_b") == MAX_LEVEL
	if not WEAPONS.has(id) or id in ["drone_a", "drone_b"]:
		return false
	if get_level(id) != MAX_LEVEL:
		return false
	var pair: String = WEAPONS[id]["pair"]
	return supplies.has(pair) and get_level(pair) >= 1


func available_upgrades() -> Array[String]:
	var result: Array[String] = []
	for key in WEAPONS:
		var id: String = key
		if id == "destroyer":
			if can_evolve(id):
				result.append(id)
			continue
		# A fused drone permanently replaces its two component weapons in this run.
		if weapons.has("destroyer") and id in ["drone_a", "drone_b"]:
			continue
		var current := get_level(id)
		if current == 0 and weapons.size() < MAX_WEAPON_SLOTS:
			result.append(id)
		elif current > 0 and (current < MAX_LEVEL or can_evolve(id)):
			result.append(id)
	for key in SUPPLIES:
		var id: String = key
		var current := get_level(id)
		if current == 0 and supplies.size() < MAX_SUPPLY_SLOTS:
			result.append(id)
		elif current > 0 and current < MAX_LEVEL:
			result.append(id)
	for id: String in weapons:
		if not is_evolved(id):
			continue
		var current_mastery := int(mastery.get(id, 0))
		if current_mastery < MAX_SAFE_INTEGER:
			result.append("mastery:" + id)
		if current_mastery >= TRAIT_MASTERY_LEVEL and not traits.has(id):
			result.append("trait:%s:focus" % id)
			result.append("trait:%s:blast" % id)
	return result


func roll_choices(rng: RandomNumberGenerator, count: int = 3) -> Array[String]:
	var pool := available_upgrades()
	if pool.is_empty():
		pool.assign(["heal", "coins"])
	var result: Array[String] = []
	for _index in range(mini(maxi(count, 0), pool.size())):
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


func apply_upgrade(id: String) -> bool:
	var available := available_upgrades()
	if id in ["heal", "coins"]:
		return available.is_empty()
	if not available.has(id):
		return false
	if id.begins_with("mastery:"):
		var weapon_id := id.split(":")[1]
		mastery[weapon_id] = int(mastery.get(weapon_id, 0)) + 1
	elif id.begins_with("trait:"):
		var parts := id.split(":")
		traits[parts[1]] = parts[2]
	elif id == "destroyer":
		weapons.erase("drone_a")
		weapons.erase("drone_b")
		weapons["destroyer"] = EVOLUTION_LEVEL
	elif WEAPONS.has(id):
		weapons[id] = get_level(id) + 1
	else:
		supplies[id] = get_level(id) + 1
	return true


func offer_info(id: String) -> Dictionary:
	if id.begins_with("mastery:") or id.begins_with("trait:"):
		return _advanced_offer_info(id)
	if id in ["heal", "coins"]:
		return {
			"name": "응급 회복" if id == "heal" else "추가 보급금",
			"short": "회복" if id == "heal" else "보급금",
			"description": "최대 체력의 30%를 즉시 회복합니다." if id == "heal" else "기본 보급 코인 50개를 획득합니다. 보급 명세서의 추가 획득 효과가 적용됩니다.",
			"category": "fallback", "level": 0, "next_level": 0,
			"evolution": false, "requirement": "모든 장비 강화 완료",
			"color": Color(0.34, 0.95, 0.72) if id == "heal" else Color(1.0, 0.81, 0.37),
		}
	if not WEAPONS.has(id) and not SUPPLIES.has(id):
		return {}
	var weapon := WEAPONS.has(id)
	var definition: Dictionary = WEAPONS[id] if weapon else SUPPLIES[id]
	var current := get_level(id)
	var evolution := can_evolve(id)
	var requirement := ""
	if weapon:
		if id in ["drone_a", "drone_b", "destroyer"]:
			requirement = "A형 의료 드론 5성 + B형 의료 드론 5성"
		else:
			var pair: String = definition["pair"]
			requirement = "%s 5성 + %s 1성 이상" % [definition["name"], SUPPLIES[pair]["name"]]
	var display_name: String = definition["evo_name"] if weapon and (evolution or is_evolved(id)) else definition["name"]
	var description: String = definition["description"]
	if evolution and id != "destroyer":
		description = "진화: %s의 최종 형태를 해금합니다.\n%s" % [definition["name"], description]
	return {
		"name": display_name, "short": definition["short"],
		"description": description, "category": "weapon" if weapon else "supply",
		"level": current,
		"next_level": EVOLUTION_LEVEL if evolution or id == "destroyer" else maxi(current, mini(current + 1, MAX_LEVEL)),
		"evolution": evolution, "requirement": requirement,
		"color": definition["color"],
	}


func _advanced_offer_info(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() < 2 or not WEAPONS.has(parts[1]) or not is_evolved(parts[1]):
		return {}
	var weapon_id := parts[1]
	var definition: Dictionary = WEAPONS[weapon_id]
	var current := int(mastery.get(weapon_id, 0))
	if parts[0] == "mastery" and parts.size() == 2:
		return {
			"name": "%s · 숙련" % definition["evo_name"], "short": definition["short"],
			"description": "숙련 단계마다 이 무기의 피해가 기본 진화 피해의 15%%만큼 증가합니다.\n피해 배율 %.2f배 → %.2f배" % [damage_multiplier(weapon_id), 1.0 + 0.15 * (current + 1)],
			"category": "mastery", "level": current, "next_level": current + 1,
			"evolution": false, "requirement": "진화 무기 · 숙련 3단계에서 고유 특성 선택",
			"color": definition["color"],
		}
	if parts[0] == "trait" and parts.size() == 3 and parts[2] in ["focus", "blast"]:
		var focus := parts[2] == "focus"
		return {
			"name": "%s · %s" % [definition["evo_name"], "집중" if focus else "폭발"],
			"short": definition["short"],
			"description": "이 무기의 보스 대상 피해가 40% 증가합니다.\n무기당 특성 하나만 선택할 수 있습니다." if focus else "이 무기의 명중 지점 반경 75 안의 다른 적에게 25%의 추가 피해를 줍니다.\n무기당 특성 하나만 선택할 수 있습니다.",
			"category": "trait", "level": 0, "next_level": 1,
			"evolution": false, "requirement": "숙련 3단계 이상 · 집중 / 폭발 중 하나 선택",
			"color": definition["color"],
		}
	return {}


func serialize() -> Dictionary:
	return {"weapons": weapons.duplicate(true), "supplies": supplies.duplicate(true),
		"mastery": mastery.duplicate(true), "traits": traits.duplicate(true)}


func snapshot() -> Dictionary:
	return serialize()


func restore(data: Dictionary) -> bool:
	# Validate into isolated containers before touching the live build. JSON numbers
	# may be floats, but only finite, exact integers are legitimate save values.
	if not data.get("weapons") is Dictionary or not data.get("supplies") is Dictionary:
		return false
	if not data.get("mastery", {}) is Dictionary or not data.get("traits", {}) is Dictionary:
		return false
	var saved_weapons: Dictionary = data["weapons"]
	var saved_supplies: Dictionary = data["supplies"]
	var saved_mastery: Dictionary = data.get("mastery", {})
	var saved_traits: Dictionary = data.get("traits", {})
	if saved_weapons.is_empty() or saved_weapons.size() > MAX_WEAPON_SLOTS or saved_supplies.size() > MAX_SUPPLY_SLOTS:
		return false
	var next_weapons: Dictionary = {}
	var next_supplies: Dictionary = {}
	var next_mastery: Dictionary = {}
	var next_traits: Dictionary = {}
	for id in saved_weapons:
		if not id is String or not WEAPONS.has(id) or not _valid_integer(saved_weapons[id], 1, EVOLUTION_LEVEL):
			return false
		var level := int(saved_weapons[id])
		if id in ["drone_a", "drone_b"] and level > MAX_LEVEL:
			return false
		if id == "destroyer" and (level != EVOLUTION_LEVEL or saved_weapons.has("drone_a") or saved_weapons.has("drone_b")):
			return false
		next_weapons[id] = level
	for id in saved_supplies:
		if not id is String or not SUPPLIES.has(id) or not _valid_integer(saved_supplies[id], 1, MAX_LEVEL):
			return false
		next_supplies[id] = int(saved_supplies[id])
	for id in saved_mastery:
		if not id is String or int(next_weapons.get(id, 0)) != EVOLUTION_LEVEL or not _valid_integer(saved_mastery[id], 0, MAX_SAFE_INTEGER):
			return false
		next_mastery[id] = int(saved_mastery[id])
	for id in saved_traits:
		if not id is String or int(next_weapons.get(id, 0)) != EVOLUTION_LEVEL or int(next_mastery.get(id, 0)) < TRAIT_MASTERY_LEVEL:
			return false
		if not saved_traits[id] is String or saved_traits[id] not in ["focus", "blast"]:
			return false
		next_traits[id] = saved_traits[id]
	weapons = next_weapons
	supplies = next_supplies
	mastery = next_mastery
	traits = next_traits
	return true


func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric == floor(numeric) and numeric >= minimum and numeric <= maximum
