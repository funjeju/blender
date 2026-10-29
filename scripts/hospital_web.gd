extends Node
## Thin local browser adapter. The game never knows the host's API or credentials.
var game: Node
var clock := 0.0
var last_mode := -1

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.wardHost && window.wardHost.ready()")
	_publish()

func _process(dt: float) -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.wardHost ? window.wardHost.drain() : '[]'")
	var commands = JSON.parse_string(str(raw))
	if commands is Array:
		for item in commands:
			if not item is Dictionary:
				continue
			match item.get("command", ""):
				"start":
					if game.mode == game.Mode.READY:
						game.primary_action()
				"restart": game.start_run()
				"primary": game.primary_action()
				"new_run":
					if game.mode in [game.Mode.READY, game.Mode.LOST, game.Mode.REST]:
						game.start_run()
				"workshop": game.open_workshop()
				"upgrade_equipment":
					if game.mode == game.Mode.REST:
						game.upgrade_equipment(str(item.get("slot", "")))
				"return_title":
					if game.mode == game.Mode.REST:
						game.return_to_title()
				"pause": game.pause_run(str(item.get("reason", "host")))
				"resume": game.resume_run()
				"choose": game.choose_upgrade(int(item.get("index", -1)), int(item.get("revision", -2)))
				"reroll": game.reroll_upgrades(int(item.get("revision", -2)))
				"move":
					if game.mode == game.Mode.PLAYING:
						game.touch_direction = Vector2(float(item.get("x", 0)), float(item.get("y", 0))).limit_length(1.0)
				"mute": game.muted = not game.muted
				"dispose":
					game.audio.stop_all()
					JavaScriptBridge.eval("window.wardHost.dispose()")
					get_tree().quit()
	clock += dt
	if clock >= 0.1 or game.mode != last_mode:
		clock = 0
		_publish()

func _publish() -> void:
	last_mode = game.mode
	var state := {"mode": game.Mode.keys()[game.mode].to_lower(), "pauseReason": game.pause_reason, "stage": game.stage_index, "clearedStages": game.cleared_stages, "kills": game.kills, "durationMs": int(game.total_elapsed * 1000), "score": game.ranking_score(), "muted": game.muted, "heroX": game.hero.x, "heroY": game.hero.y, "view": game.hero_view()}
	state["level"] = game.level
	state["rerolls"] = game.rerolls_left
	state["choiceRevision"] = game.choice_revision
	state["sector"] = game.sector_index()
	state["encounter"] = game.stage_in_sector()
	state["restFromTitle"] = game.rest_from_title
	state["checkpointPending"] = game.checkpoint_pending
	state["materials"] = int(game.campaign.profile["materials"])
	state["equipment"] = game.campaign.profile["equipment"].duplicate()
	state["costs"] = {
		"coat": game.campaign.upgrade_cost("coat"),
		"gloves": game.campaign.upgrade_cost("gloves"),
		"boots": game.campaign.upgrade_cost("boots"),
	}
	state["hasCheckpoint"] = not game.campaign.checkpoint.is_empty()
	state["checkpointStage"] = int(game.campaign.checkpoint.get("stage", 1))
	state["highestStage"] = int(game.campaign.profile["highest_stage"])
	state["saveError"] = game.campaign.error_message
	var choices: Array[Dictionary] = []
	if game.mode == game.Mode.CHOOSING:
		for id in game.upgrade_choices:
			var info: Dictionary = game.progression.offer_info(id)
			choices.append({"name": info.name, "description": info.description, "requirement": info.requirement, "level": info.next_level, "evolution": info.evolution, "category": info.get("category", "weapon")})
	state["choices"] = choices
	JavaScriptBridge.eval("window.wardHost && window.wardHost.update(" + JSON.stringify(state) + ")")

func emit_event(kind: String) -> void:
	if OS.has_feature("web"):
		_publish()
		JavaScriptBridge.eval("window.wardHost && window.wardHost.event(" + JSON.stringify(kind) + ")")
