extends Node2D
## Resolution-independent interface drawn in the 1920x1080 design space.

const MINT := Color("9cddc5")
const INK := Color("e5eee7")
const MUTED := Color("8baba4")
const RED := Color("e99783")
const GOLD := Color("f0d48c")
const LILAC := Color("c6b0f1")
var game: Node2D
var font: Font
var title_font: Font
var main_button := Rect2(520, 684, 360, 68)
var continue_button := Rect2()
var new_run_button := Rect2()
var workshop_button := Rect2()
var title_button := Rect2()
var skin_button := Rect2(1068, 772, 332, 50)
var reroll_button := Rect2(770, 790, 380, 58)
var vignette: Texture2D
const EQUIPMENT_SLOTS := ["coat", "gloves", "boots"]
const EQUIPMENT_NAMES := ["방호복", "전술 장갑", "구조화"]

func _ready() -> void:
	font = preload("res://assets/fonts/Pretendard-Regular.otf")
	title_font = font
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.42, 0.77, 1])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0.02, 0.03, 0.03), Color(0, 0.025, 0.035, 0.36), Color(0, 0.02, 0.03, 0.72)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 288
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.48)
	texture.fill_to = Vector2(1, 1)
	vignette = texture

func _process(_dt: float) -> void:
	queue_redraw()

func label_at(point: Vector2, value: String, size: int = 20, color: Color = INK, title: bool = false) -> void:
	draw_string(title_font if title else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color = Color(0.025, 0.065, 0.074, 0.94), border: Color = Color(0.39, 0.65, 0.58, 0.25), radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _fit_text(value: String, width: float, size: int) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return value
	var shortened := value
	while not shortened.is_empty() and font.get_string_size(shortened + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		shortened = shortened.substr(0, shortened.length() - 1)
	return shortened + "…"

func _wrapped(point: Vector2, value: String, width: float, size: int, color: Color, line_height: float, max_lines: int = 4) -> void:
	var line := ""
	var lines: Array[String] = []
	for character in value:
		if character == "\n":
			lines.append(line)
			line = ""
		elif font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			lines.append(line)
			line = character
		else:
			line += character
	if not line.is_empty():
		lines.append(line)
	for i in range(mini(lines.size(), max_lines)):
		var value_line := lines[i]
		if i == max_lines - 1 and lines.size() > max_lines:
			value_line = _fit_text(value_line + "…", width, size)
		label_at(point + Vector2(0, i * line_height), value_line, size, color)

func _stars(item_level: int) -> String:
	if item_level > 5:
		return "EVO"
	return "★".repeat(clampi(item_level, 0, 5)) + "☆".repeat(maxi(0, 5 - item_level))

func _item_name(id: String, compact: bool = false) -> String:
	if game.progression.WEAPONS.has(id):
		var definition: Dictionary = game.progression.WEAPONS[id]
		if game.progression.get_level(id) > 5:
			return str(definition.evo_name)
		return str(definition.short if compact else definition.name)
	if game.progression.SUPPLIES.has(id):
		var definition: Dictionary = game.progression.SUPPLIES[id]
		return str(definition.short if compact else definition.name)
	return str(game.progression.offer_info(id).get("name", id))

func choice_rect(index: int) -> Rect2:
	if index < 0 or index >= game.upgrade_choices.size():
		return Rect2()
	return Rect2(370 + index * 400, 360, 380, 380)

func equipment_rect(index: int) -> Rect2:
	if index < 0 or index >= 3:
		return Rect2()
	return Rect2(390 + index * 380, 628, 350, 58)

func _mastery_level(id: String) -> int:
	return int(game.progression.mastery.get(id, 0))

func _gear_rank(id: String) -> String:
	var mastery := _mastery_level(id)
	return "EVO · 숙련 %d" % mastery if mastery > 0 else _stars(game.progression.get_level(id))

func _equipment_summary() -> String:
	return "방호복 +%d   ·   장갑 +%d   ·   구조화 +%d" % [game.campaign.equipment_level("coat"), game.campaign.equipment_level("gloves"), game.campaign.equipment_level("boots")]

func _inventory_compact() -> void:
	panel(Rect2(40, 153, 470, 185), Color(0.025, 0.065, 0.074, 0.9))
	label_at(Vector2(58, 178), "장비", 15, MINT)
	label_at(Vector2(333, 178), "6 무기 + 6 보급품", 13, MUTED)
	_inventory_row(game.progression.weapons, Vector2(57, 189), MINT)
	_inventory_row(game.progression.supplies, Vector2(57, 260), LILAC)

func _inventory_row(items: Dictionary, point: Vector2, accent: Color) -> void:
	var ids: Array = items.keys()
	for i in range(6):
		var rect := Rect2(point + Vector2(i * 73, 0), Vector2(68, 60))
		panel(rect, Color("122d2d"), Color(0.39, 0.65, 0.58, 0.16), 5)
		if i >= ids.size():
			label_at(rect.position + Vector2(26, 34), "+", 20, Color("42605a"))
			continue
		var id: String = str(ids[i])
		var item_level: int = game.progression.get_level(id)
		label_at(rect.position + Vector2(5, 23), _fit_text(_item_name(id, true), 58, 13), 13, accent)
		var rank := "숙련 %d" % _mastery_level(id) if _mastery_level(id) > 0 else _stars(item_level)
		label_at(rect.position + Vector2(5, 46), rank, 11, GOLD if item_level < 6 else RED)

func _upgrade_selection() -> void:
	main_button = Rect2()
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.025, 0.03, 0.86))
	panel(Rect2(330, 202, 1260, 696), Color(0.025, 0.065, 0.074, 0.99), Color(0.54, 0.83, 0.7, 0.5), 18)
	label_at(Vector2(370, 258), "LEVEL %02d  /  UPGRADE" % game.level, 19, MINT)
	label_at(Vector2(370, 316), "이번에는 무엇을 강화할까요?", 35, INK)
	label_at(Vector2(1208, 313), "전투가 일시정지됩니다", 17, MUTED)
	for i in range(game.upgrade_choices.size()):
		var info: Dictionary = game.progression.offer_info(game.upgrade_choices[i])
		var rect := choice_rect(i)
		var hover := rect.has_point(get_local_mouse_position())
		var evolution := bool(info.get("evolution", false))
		var category := str(info.get("category", "weapon"))
		var accent := RED if evolution else (GOLD if category in ["mastery", "trait"] else (LILAC if category == "supply" else MINT))
		panel(rect, Color("17443d") if hover else Color("102b2b"), accent if hover else Color(accent, 0.36), 12)
		draw_rect(Rect2(rect.position + Vector2(16, 16), Vector2(4, 30)), accent)
		var category_name := "궁극 진화" if evolution else str({"supply": "보급품", "fallback": "즉시 보급", "mastery": "진화 무기 숙련", "trait": "전투 특성"}.get(category, "무기"))
		label_at(rect.position + Vector2(32, 39), category_name, 16, accent)
		panel(Rect2(rect.position + Vector2(320, 17), Vector2(38, 33)), Color(accent, 0.13), Color(accent, 0.2), 5)
		label_at(rect.position + Vector2(333, 41), str(i + 1), 20, accent)
		label_at(rect.position + Vector2(24, 101), _fit_text(str(info.get("name", "장비 강화")), 332, 30), 30, INK)
		var next_level: int = int(info.get("next_level", 1))
		var rank := _stars(next_level)
		if category == "fallback":
			rank = "즉시 획득"
		elif category == "mastery":
			rank = "숙련 %d → %d" % [int(info.get("level", 0)), next_level]
		elif category == "trait":
			rank = "특성 선택"
		label_at(rect.position + Vector2(25, 140), rank, 22, GOLD if not evolution else RED)
		if category not in ["fallback", "trait"]:
			label_at(rect.position + Vector2(270, 139), "새 장비" if int(info.get("level", 0)) == 0 and category != "mastery" else ("진화" if evolution else "강화 +1"), 16, accent)
		draw_line(rect.position + Vector2(24, 160), rect.position + Vector2(356, 160), Color(accent, 0.2), 1)
		_wrapped(rect.position + Vector2(24, 196), str(info.get("description", "")), 332, 20, INK, 29, 3)
		var requirement := str(info.get("requirement", ""))
		if not requirement.is_empty():
			panel(Rect2(rect.position + Vector2(18, 292), Vector2(344, 69)), Color(0.02, 0.06, 0.06, 0.7), Color(accent, 0.15), 6)
			_wrapped(rect.position + Vector2(30, 317), requirement, 320, 15, accent, 23, 2)
		else:
			label_at(rect.position + Vector2(24, 332), "효과는 획득 즉시 적용됩니다.", 16, MUTED)
	var can_reroll: bool = game.rerolls_left > 0
	var reroll_hover := reroll_button.has_point(get_local_mouse_position()) and can_reroll
	panel(reroll_button, Color("245449") if reroll_hover else Color("163732"), MINT if can_reroll else Color("36504a"), 7)
	label_at(reroll_button.position + Vector2(41, 38), "다시 뽑기  /  R  ·  %d회 남음" % game.rerolls_left, 20, MINT if can_reroll else MUTED)
	label_at(Vector2(370, 875), "카드를 클릭하거나 1 · 2 · 3으로 선택", 16, MUTED)
	label_at(Vector2(1050, 875), "5성 + 짝 보급품 → 진화 → 숙련 강화 · 특성 선택", 15, GOLD)

func _pause_screen() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.025, 0.03, 0.87))
	panel(Rect2(470, 177, 980, 726), Color(0.025, 0.065, 0.074, 0.99))
	label_at(Vector2(520, 230), "PAUSED  /  LOADOUT", 18, MINT)
	label_at(Vector2(520, 282), "잠시 숨 고르기", 38, INK)
	label_at(Vector2(520, 316), "무기 5성 + 짝 보급품 1성 이상 → 진화 선택 / 상자 우선 진화", 18, GOLD)
	label_at(Vector2(520, 362), "자동 무기  /  %d · 6" % game.progression.weapons.size(), 20, MINT)
	label_at(Vector2(975, 362), "지속 보급품  /  %d · 6" % game.progression.supplies.size(), 20, LILAC)
	_inventory_details(game.progression.weapons, Vector2(520, 383), MINT, true)
	_inventory_details(game.progression.supplies, Vector2(975, 383), LILAC, false)
	main_button = Rect2(520, 792, 880, 62)
	_button("계속하기  /  ENTER 또는 ESC")
	label_at(Vector2(520, 881), "금화 %d  ·  강화 재료 %d  ·  %s" % [game.coins, int(game.campaign.profile.materials), _equipment_summary()], 16, MUTED)

func _inventory_details(items: Dictionary, point: Vector2, accent: Color, show_pair: bool) -> void:
	var ids: Array = items.keys()
	for i in range(6):
		var rect := Rect2(point + Vector2(0, i * 64), Vector2(425, 57))
		panel(rect, Color("102b2b"), Color(accent, 0.15), 6)
		if i >= ids.size():
			label_at(rect.position + Vector2(17, 36), "빈 슬롯  /  레벨 업으로 획득", 16, Color("68877d"))
			continue
		var id := str(ids[i])
		var info: Dictionary = game.progression.offer_info(id)
		var item_level: int = game.progression.get_level(id)
		label_at(rect.position + Vector2(16, 24), _fit_text(_item_name(id), 245, 18), 18, accent)
		label_at(rect.position + Vector2(275, 24), _gear_rank(id), 13, GOLD if item_level < 6 else RED)
		var detail := str(info.get("requirement", "")) if show_pair else str(info.get("description", ""))
		if item_level > 5:
			detail = "궁극 진화 완료 · 숙련 %d" % _mastery_level(id)
			var trait_id: String = str(game.progression.traits.get(id, ""))
			if not trait_id.is_empty():
				detail += " · " + ("집중" if trait_id == "focus" else "폭발")
		label_at(rect.position + Vector2(16, 46), _fit_text(detail, 392, 13), 13, MUTED)

func _draw() -> void:
	if game == null or font == null:
		return
	continue_button = Rect2()
	new_run_button = Rect2()
	workshop_button = Rect2()
	title_button = Rect2()
	draw_texture_rect(vignette, Rect2(0, 0, 1920, 1080), false)
	if game.mode == game.Mode.READY:
		_title_screen()
		return
	_draw_play_hud()
	if game.mode == game.Mode.TRANSITION:
		_stage_transition()
	elif game.mode == game.Mode.CHOOSING:
		_upgrade_selection()
	elif game.mode == game.Mode.PAUSED:
		_pause_screen()
	elif game.mode == game.Mode.REST:
		_workshop_screen()
	elif game.mode == game.Mode.WON:
		_overlay("복도는 계속 이어집니다.", "ENDLESS WARD", "장비를 정비하고 다음 병동으로 향하세요.", "계속하기  /  ENTER")
	elif game.mode == game.Mode.LOST:
		var description := "체크포인트의 장비와 레벨로 다시 도전할 수 있습니다." if game.has_checkpoint() else "정비한 영구 장비를 가지고 다시 도전해 보세요."
		_overlay("다음에는 조금 더 멀리.", "SIGNAL LOST", description, "체크포인트 이어하기  /  ENTER" if game.has_checkpoint() else "다시 도전하기  /  ENTER")
	elif game.banner_left > 0:
		panel(Rect2(605, 272, 710, 64), Color(0.04, 0.12, 0.13, 0.94))
		label_at(Vector2(635, 313), game.banner, 22, MINT)
	elif game.level_flash > 0:
		panel(Rect2(715, 272, 490, 76), Color(0.04, 0.16, 0.15, 0.94))
		label_at(Vector2(749, 303), "LEVEL %02d  /  장비 강화 완료" % game.level, 23, MINT)
		label_at(Vector2(749, 330), "경험치를 모아 다음 장비를 선택하세요.", 16, MUTED)

func _draw_play_hud() -> void:
	panel(Rect2(40, 32, 395, 100))
	draw_rect(Rect2(40, 54, 4, 55), MINT)
	label_at(Vector2(65, 65), "ENDLESS WARD", 23, INK, true)
	label_at(Vector2(65, 98), "STAGE %02d  ·  %s" % [game.stage_index, game.stage_name()], 18, MUTED)
	panel(Rect2(457, 32, 315, 100))
	label_at(Vector2(478, 64), "SECTOR %02d  ·  %d / 3" % [game.sector_index(), game.stage_in_sector()], 16, MINT)
	label_at(Vector2(478, 101), _fit_text(game.encounter_label(), 276, 19), 19, INK)
	panel(Rect2(795, 24, 330, 126))
	var left := maxi(0, ceili(game.DURATION - game.elapsed))
	var boss: Dictionary = game.boss_enemy()
	var boss_active := not boss.is_empty()
	label_at(Vector2(873, 103), "BOSS" if boss_active else "%02d:%02d" % [floori(float(left) / 60.0), left % 60], 60, INK, true)
	label_at(Vector2(880, 132), "감독관을 처치하세요" if boss_active else "이 병동 생존까지", 15, MUTED)
	draw_rect(Rect2(814, 39, 290 * minf(1, game.elapsed / game.DURATION), 3), RED if boss_active else MINT)
	panel(Rect2(1515, 32, 365, 100))
	label_at(Vector2(1540, 64), "처치", 17, MUTED)
	label_at(Vector2(1540, 106), "%03d" % game.kills, 36, INK, true)
	label_at(Vector2(1666, 64), "위험 단계", 17, MUTED)
	for i in range(3):
		draw_rect(Rect2(1667 + i * 50, 85, 38, 14), RED if i < game.stage() else Color("253d3b"))
	panel(Rect2(40, 905, 470, 134))
	label_at(Vector2(64, 938), "VITAL SIGNS", 15, MINT, true)
	label_at(Vector2(344, 938), "%03d / %03d" % [ceili(game.hp), ceili(game.max_hp)], 19, INK, true)
	_ecg(Vector2(64, 961), 85, MINT)
	draw_rect(Rect2(174, 955, 310, 15), Color("213937"))
	draw_rect(Rect2(174, 955, 310 * clampf(game.hp / game.max_hp, 0, 1), 15), MINT if game.hp > game.max_hp * 0.3 else RED)
	label_at(Vector2(64, 1014), "LV.%02d" % game.level, 22, INK, true)
	label_at(Vector2(168, 1012), "주사기 공격력 %d" % int(game.damage * game.progression.damage_multiplier("syringe")), 17, MUTED)
	label_at(Vector2(360, 1012), "금화 %d" % game.coins, 17, GOLD)
	_inventory_compact()
	panel(Rect2(655, 983, 610, 56))
	if game.xp >= game.xp_needed() and game.upgrade_cooldown > 0:
		label_at(Vector2(682, 1019), "다음 강화까지 전투 %d초 · 경험치 보관 중" % ceili(game.upgrade_cooldown), 18, MINT)
	else:
		label_at(Vector2(682, 1019), "W A S D / 방향키   이동     ·     공격은 자동", 18, MUTED)
	label_at(Vector2(1540, 1019), "ESC  일시정지   ·   M  " + ("소리 켜기" if game.muted else "음소거"), 17, MUTED)
	# Thin experience rail across the bottom, separate from health.
	draw_rect(Rect2(40, 1058, 1840, 4), Color("183630"))
	draw_rect(Rect2(40, 1058, 1840 * clampf(float(game.xp) / game.xp_needed(), 0, 1), 4), MINT)
	_minimap()
	if not boss.is_empty():
		panel(Rect2(605, 171, 710, 74), Color(0.10, 0.045, 0.04, 0.94), Color(0.8, 0.4, 0.3, 0.4))
		label_at(Vector2(630, 200), "격리 감독관  /  " + ("폭주" if boss.hp < boss.max_hp * 0.5 else "보스"), 19, RED)
		label_at(Vector2(1173, 200), "%d / %d" % [maxi(0, ceili(boss.hp)), int(boss.max_hp)], 15, MUTED)
		draw_rect(Rect2(630, 216, 660, 9), Color("3b2420"))
		draw_rect(Rect2(630, 216, 660 * maxf(0, boss.hp) / boss.max_hp, 9), RED)
		# A fixed HUD arrow remains readable when the boss moves off screen.
		var direction: Vector2 = game.hero.direction_to(boss.p)
		var marker := Vector2(960, 540) + direction * Vector2(710, 320)
		if game.hero.distance_to(boss.p) > 540:
			label_at(marker, "◆ 감독관", 18, RED)
	if game.hit_flash > 0:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.8, 0.18, 0.10, game.hit_flash * 0.4))
	if game.elapsed < 5:
		var hint := "경험치 수집 → 레벨 업 → 무기 또는 보급품 선택"
		if boss_active:
			hint = "돌진 경로와 충격파 예고를 피하며 감독관을 처치하세요."
		elif game.stage_index > 1:
			hint = "엘리트를 처치해 상자를 획득하세요. 무기와 보급품은 유지됩니다."
		label_at(Vector2(620, 745), hint, 21, INK)

func _minimap() -> void:
	var rect := Rect2(1680, 162, 200, 150)
	panel(rect, Color(0.02, 0.06, 0.065, 0.82))
	label_at(rect.position + Vector2(14, 25), "WARD / 무한 구역", 13, MUTED)
	var base := rect.position + Vector2(100, 93)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var o := base + Vector2(x * 62, y * 37)
			draw_line(o + Vector2(-31, 0), o + Vector2(31, 0), Color("385b55"), 5)
			draw_line(o + Vector2(0, -19), o + Vector2(0, 19), Color("385b55"), 5)
	var local: Vector2 = game.hero - Vector2(game.world.center_chunk) * game.world.MODULE
	var point: Vector2 = base + (local / game.world.MODULE - Vector2(0.5, 0.5)) * Vector2(62, 37)
	draw_circle(point, 4, MINT)

func _title_screen() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.015, 0.04, 0.045, 0.53))
	label_at(Vector2(64, 70), "+  EMERGENCY DEPARTMENT", 19, MINT, true)
	label_at(Vector2(1595, 70), "LOCAL  /  SINGLE PLAYER", 16, MUTED, true)
	panel(Rect2(420, 155, 1080, 775), Color(0.024, 0.063, 0.071, 0.96), Color(0.45, 0.7, 0.62, 0.4), 18)
	draw_rect(Rect2(470, 238, 42, 4), MINT)
	label_at(Vector2(530, 249), "ANOTHER WARD. ANOTHER CHANCE.", 16, MINT, true)
	label_at(Vector2(510, 357), "ENDLESS", 86, INK, true)
	label_at(Vector2(510, 451), "WARD", 112, INK, true)
	label_at(Vector2(518, 505), "끝없이 이어지는 병원", 27, MINT)
	label_at(Vector2(520, 553), "3분 생존 → 3분 생존 → 보스 → 다음 구역", 20, INK)
	label_at(Vector2(520, 586), "진화 이후에도 숙련과 특성으로 계속 성장합니다.", 18, GOLD)
	label_at(Vector2(520, 619), "보스를 넘으면 정비실에서 저장하고 장비를 강화하세요.", 17, MUTED)
	var checkpoint: bool = game.has_checkpoint()
	var saved_stage: int = int(game.campaign.checkpoint.get("stage", 1))
	panel(Rect2(520, 641, 470, 61), Color("123330"), Color(MINT, 0.18), 6)
	label_at(Vector2(537, 666), "저장된 여정  ·  STAGE %02d부터" % saved_stage if checkpoint else "새로운 여정  ·  STAGE 01부터", 18, MINT)
	label_at(Vector2(537, 690), "최고 도달 %d 병동  ·  강화 재료 %d" % [int(game.campaign.profile.highest_stage), int(game.campaign.profile.materials)], 14, MUTED)
	main_button = Rect2(520, 721, 470, 62)
	continue_button = main_button
	_button("이어하기  /  ENTER" if checkpoint else "생존 시작  /  ENTER")
	new_run_button = Rect2(520, 797, 226, 48)
	workshop_button = Rect2(762, 797, 228, 48)
	_secondary_button(new_run_button, "새 여정  /  N", MUTED)
	_secondary_button(workshop_button, "장비 정비  /  G", MINT)
	label_at(Vector2(523, 877), "WASD 이동 · 1 / 2 / 3 선택 · R 다시 뽑기", 16, MUTED)
	label_at(Vector2(523, 902), "새 여정은 체크포인트를 교체합니다. 영구 장비는 유지됩니다.", 14, MUTED)
	var save_error: String = str(game.campaign.error_message)
	if not save_error.is_empty():
		_wrapped(Vector2(520, 961), save_error, 940, 17, RED, 25, 2)
	# Use the actual generated character and bed, not a disconnected title mockup.
	panel(Rect2(1045, 247, 380, 510), Color(0.10, 0.19, 0.18, 0.65), Color(0.3, 0.5, 0.45, 0.15))
	for i in range(10):
		draw_line(Vector2(1058, 280 + i * 46), Vector2(1410, 280 + i * 46), Color(0.4, 0.65, 0.55, 0.06))
	draw_texture_rect(game.hero_texture(), Rect2(1010, 246, 450, 450), false, game.skin_color())
	draw_rect(Rect2(1071, 705, 324, 1), Color(0.5, 0.8, 0.7, 0.3))
	label_at(Vector2(1080, 735), "SUBJECT 01   /   MEDIC", 17, MINT, true)
	panel(skin_button, Color(0.12, 0.23, 0.22, 0.9))
	label_at(skin_button.position + Vector2(18, 33), "외형: " + ("격리 대응" if game.selected_skin else "응급의") + "  /  TAB 변경", 18, MINT)
	label_at(Vector2(65, 1020), "01 / ENDLESS WARD", 16, MUTED, true)
	label_at(Vector2(1375, 1020), "SURVIVAL / ELITE / BOSS", 18, MUTED, true)

func _workshop_screen() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.035, 0.04, 0.92))
	panel(Rect2(340, 153, 1240, 772), Color(0.025, 0.075, 0.079, 0.99), Color(MINT, 0.4), 18)
	label_at(Vector2(390, 216), "SAFE ROOM  /  PERMANENT EQUIPMENT", 19, MINT)
	label_at(Vector2(390, 274), "다음 병동을 위한 정비", 39, INK)
	label_at(Vector2(1240, 213), "강화 재료", 17, MUTED)
	label_at(Vector2(1240, 259), "%d" % int(game.campaign.profile.materials), 39, GOLD)
	var next_stage: int = int(game.campaign.checkpoint.get("stage", 1)) if game.rest_from_title else game.stage_index + 1
	var pending: bool = game.checkpoint_pending
	if game.rest_from_title:
		label_at(Vector2(390, 313), "강화한 장비는 다음 여정과 체크포인트 재도전에 적용됩니다.", 20, MUTED)
	elif pending:
		label_at(Vector2(390, 313), "저장을 완료하지 못했습니다. 재시도 후 다음 병동으로 출발하세요.", 20, RED)
	else:
		label_at(Vector2(390, 313), "구역 %d 돌파  ·  STAGE %02d 체크포인트  ·  체력 완전 회복" % [game.sector_index(), next_stage], 20, MINT)
	var descriptions := ["최대 체력 +15% / 단계\n받는 피해 점진 감소 · 최대 20%", "모든 무기 피해 +10% / 단계\n진화 무기와 숙련에도 함께 적용", "최대 체력 +5% / 단계\n이동 속도 점진 증가 · 최대 25%"]
	for i in range(3):
		var slot: String = EQUIPMENT_SLOTS[i]
		var rect := Rect2(390 + i * 380, 352, 350, 354)
		var accent := [MINT, GOLD, LILAC][i] as Color
		panel(rect, Color("102f30"), Color(accent, 0.3), 12)
		label_at(rect.position + Vector2(24, 40), "%02d  /  영구 장비" % (i + 1), 16, accent)
		label_at(rect.position + Vector2(24, 91), EQUIPMENT_NAMES[i], 33, INK)
		var equipment_level: int = game.campaign.equipment_level(slot)
		label_at(rect.position + Vector2(24, 133), "+%d → +%d" % [equipment_level, equipment_level + 1], 27, accent)
		_wrapped(rect.position + Vector2(24, 182), descriptions[i], 302, 18, MUTED, 29, 3)
		var cost: int = game.campaign.upgrade_cost(slot)
		var affordable: bool = int(game.campaign.profile.materials) >= cost and not pending
		label_at(rect.position + Vector2(24, 255), "필요 재료 %d" % cost, 18, GOLD if affordable else MUTED)
		var upgrade_label := "강화  /  %d" % (i + 1) if affordable else "재료 부족  /  %d" % (i + 1)
		if pending:
			upgrade_label = "저장 완료 후 강화"
		_secondary_button(equipment_rect(i), upgrade_label, accent if affordable else MUTED)
	label_at(Vector2(390, 742), "재료: 여정마다 구역 보스 첫 처치 보상  ·  금화: 기록 점수에 반영", 17, MUTED)
	main_button = Rect2(390, 773, 1110 if game.rest_from_title else 730, 64)
	continue_button = main_button
	var continue_label := "메뉴로 돌아가기  /  ENTER" if game.rest_from_title else "STAGE %02d로 출발  /  ENTER" % next_stage
	_button("저장 재시도 후 출발  /  ENTER" if pending else continue_label)
	if not game.rest_from_title:
		title_button = Rect2(1150, 773, 350, 64)
		_secondary_button(title_button, "저장 후 메뉴로  /  ESC" if pending else "메뉴로  /  ESC", MINT)
	var error: String = str(game.campaign.error_message)
	_wrapped(Vector2(390, 879), error if not error.is_empty() else "로컬 자동 저장 · 영구 장비와 강화 재료는 새 여정에서도 유지됩니다.", 1110, 17, RED if not error.is_empty() else MUTED, 24, 2)

func _overlay(headline: String, caption: String, description: String, button: String) -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.035, 0.04, 0.8))
	panel(Rect2(550, 222, 820, 674), Color(0.025, 0.075, 0.079, 0.98))
	label_at(Vector2(620, 320), caption, 20, RED if game.mode == game.Mode.LOST else MINT, true)
	label_at(Vector2(620, 393), headline, 40, INK)
	label_at(Vector2(620, 444), description, 18, MUTED)
	_ecg(Vector2(620, 487), 675, MINT)
	label_at(Vector2(620, 552), "전체 생존 시간", 17, MUTED)
	label_at(Vector2(863, 552), "처치 수", 17, MUTED)
	label_at(Vector2(1113, 552), "도달 레벨", 17, MUTED)
	var seconds := int(game.total_elapsed)
	label_at(Vector2(620, 608), "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60], 38, INK, true)
	label_at(Vector2(863, 608), "%03d" % game.kills, 38, INK, true)
	label_at(Vector2(1113, 608), "%02d" % game.level, 38, INK, true)
	main_button = Rect2(620, 666, 680, 66)
	continue_button = main_button
	_button(button)
	new_run_button = Rect2(620, 748, 330, 47)
	workshop_button = Rect2(970, 748, 330, 47)
	_secondary_button(new_run_button, "새 여정  /  N", MUTED)
	_secondary_button(workshop_button, "장비 정비  /  G", MINT)
	label_at(Vector2(620, 832), "도달 STAGE %02d  ·  최고 %d 병동  ·  금화 %d" % [game.stage_index, int(game.campaign.profile.highest_stage), game.coins], 17, GOLD)
	label_at(Vector2(620, 866), "새 여정은 체크포인트를 교체합니다. 영구 장비는 유지됩니다.", 16, MUTED)

func _stage_transition() -> void:
	main_button = Rect2()
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.015, 0.035, 0.04, 0.87))
	panel(Rect2(540, 250, 840, 570), Color(0.025, 0.075, 0.079, 0.98))
	label_at(Vector2(610, 320), "STAGE %02d CLEAR" % game.stage_index, 25, MINT, true)
	label_at(Vector2(610, 393), game.stage_name() + " 목표 달성", 40, INK)
	var next_name: String = game.STAGE_NAMES[game.stage_in_sector(game.stage_index + 1) - 1]
	label_at(Vector2(610, 460), "다음: STAGE %02d  /  %s" % [game.stage_index + 1, next_name], 27, INK)
	label_at(Vector2(610, 518), "엘리트와 상자에 대비해 장비 조합을 완성하세요.", 21, RED)
	label_at(Vector2(610, 580), "레벨·무기·보급품·경험치 유지  /  체력 25 회복", 20, MUTED)
	label_at(Vector2(610, 655), "%d초 후 자동 이동" % maxi(1, ceili(game.transition_left)), 30, MINT)
	draw_rect(Rect2(610, 698, 700 * clampf(1 - game.transition_left / 3.2, 0, 1), 5), MINT)
	_ecg(Vector2(610, 758), 700, MINT)

func _button(value: String) -> void:
	var hover := main_button.has_point(get_local_mouse_position())
	panel(main_button, Color("b9f0d6") if hover else MINT, Color(0, 0, 0, 0), 7)
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
	label_at(main_button.position + Vector2((main_button.size.x - width) / 2, 44), value, 23, Color("153a32"))

func _secondary_button(rect: Rect2, value: String, accent: Color) -> void:
	var hover := rect.has_point(get_local_mouse_position())
	panel(rect, Color("245449") if hover else Color("163732"), Color(accent, 0.7 if hover else 0.3), 7)
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	label_at(rect.position + Vector2((rect.size.x - width) / 2, rect.size.y / 2 + 7), value, 19, accent)

func _ecg(point: Vector2, width: float, color: Color) -> void:
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.31, -6), Vector2(0.36, 8), Vector2(0.42, -18), Vector2(0.48, 17), Vector2(0.54, -3), Vector2(0.60, 0), Vector2(1, 0)])
	var points := PackedVector2Array()
	for p in shape:
		points.append(point + Vector2(p.x * width, p.y))
	draw_polyline(points, color, 1.6, true)
