extends RefCounted
## Local, movement-only arsenal. The host owns progression and enemy death rewards.
## Call update only while playing, and draw_effects from the host's _draw callback.

const MAX_PROJECTILES := 128
const MAX_EFFECTS := 80
const MINT := Color("99ebce")
const BLUE := Color("83cef0")
const AMBER := Color("ffc68b")
const LILAC := Color("d0b6f5")

var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var guardian_points: Array[Vector2] = []
var clocks: Dictionary = {}
var run_time := 0.0
var guardian_angle := 0.0
var guardian_visible := false
var guardian_evolved := false
var guardian_size := 12.0
var next_enemy_id := 1


func reset() -> void:
	projectiles.clear()
	effects.clear()
	guardian_points.clear()
	clocks.clear()
	run_time = 0.0
	guardian_angle = 0.0
	guardian_visible = false
	guardian_evolved = false
	guardian_size = 12.0
	next_enemy_id = 1


func update(game: Node2D, dt: float) -> void:
	run_time += dt
	for key: String in clocks:
		clocks[key] = maxf(0.0, float(clocks[key]) - dt)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life = float(effects[i].life) - dt
		if float(effects[i].life) <= 0.0:
			effects.remove_at(i)
	_update_guardian(game, dt)
	for weapon: String in ["lightning", "rocket", "brick", "soccer", "drone_a", "drone_b", "destroyer"]:
		var level: int = game.progression.get_level(weapon)
		if level <= 0 or float(clocks.get(weapon, 0.0)) > 0.0:
			continue
		if weapon in ["drone_a", "drone_b"] and game.progression.get_level("destroyer") > 0:
			continue
		_fire(game, weapon, level)
	_update_projectiles(game, dt)


func _enemy_id(enemy: Dictionary) -> int:
	if not enemy.has("_arsenal_id"):
		enemy["_arsenal_id"] = next_enemy_id
		next_enemy_id += 1
	return int(enemy["_arsenal_id"])


func _enemy_radius(enemy: Dictionary) -> float:
	match String(enemy.get("kind", "")):
		"boss": return 43.0
		"elite": return 31.0
	return 25.0


func _nearest(game: Node2D, origin: Vector2, reach: float = 850.0, excluded: Dictionary = {}) -> Dictionary:
	var target: Dictionary = {}
	var nearest := reach * reach
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) <= 0.0 or excluded.has(_enemy_id(enemy)):
			continue
		var point: Vector2 = enemy.p
		var distance := origin.distance_squared_to(point)
		if distance < nearest and game.world.clear_line(origin, point, 3.0):
			nearest = distance
			target = enemy
	return target


func _update_guardian(game: Node2D, dt: float) -> void:
	var level: int = game.progression.get_level("guardian")
	guardian_visible = false
	if level <= 0:
		guardian_points.clear()
		return
	guardian_evolved = level >= 6
	var active_time: float = (2.8 + level * 0.18) * game.duration_multiplier()
	var rest_time: float = 1.8 * game.cooldown_multiplier()
	guardian_visible = guardian_evolved or fmod(run_time, active_time + rest_time) < active_time
	guardian_angle = fmod(guardian_angle + dt * (3.8 if guardian_evolved else 2.7), TAU)
	var previous: Array[Vector2] = guardian_points.duplicate()
	guardian_points.clear()
	if not guardian_visible:
		return
	var count := 5 if guardian_evolved else 2 + floori(level / 2.0)
	var orbit: float = (110.0 if guardian_evolved else 82.0 + level * 4.0) * game.area_multiplier()
	guardian_size = (18.0 if guardian_evolved else 10.0 + level) * game.area_multiplier()
	var hero: Vector2 = game.hero
	for i in range(count):
		var point := hero + Vector2.from_angle(guardian_angle + i * TAU / count) * orbit
		guardian_points.append(point)
		var old := previous[i] if previous.size() == count else point
		for enemy: Dictionary in game.enemies:
			if float(enemy.hp) <= 0.0 or float(enemy.get("_guardian_next", 0.0)) > run_time:
				continue
			var enemy_point: Vector2 = enemy.p
			var closest := Geometry2D.get_closest_point_to_segment(enemy_point, old, point)
			if closest.distance_squared_to(enemy_point) > pow(guardian_size + _enemy_radius(enemy), 2.0):
				continue
			if not game.world.clear_line(hero, enemy_point, 3.0):
				continue
			enemy["_guardian_next"] = run_time + (0.18 if guardian_evolved else 0.35)
			var amount := 72.0 if guardian_evolved else 9.0 + level * 7.0
			game._damage_enemy(enemy, amount * game.attack_multiplier(), "guardian")
			var away := hero.direction_to(enemy_point)
			var knockback := 9.0 if enemy.get("kind", "") == "boss" else (32.0 if guardian_evolved else 19.0)
			var destination := enemy_point + away * knockback
			if game.world.clear_line(enemy_point, destination, _enemy_radius(enemy) * 0.65):
				enemy.p = destination
			enemy.slow = maxf(float(enemy.get("slow", 0.0)), 0.18)


func _fire(game: Node2D, weapon: String, level: int) -> void:
	var hero: Vector2 = game.hero
	var target := _nearest(game, hero)
	if target.is_empty():
		clocks[weapon] = 0.18
		return
	var direction := hero.direction_to(Vector2(target.p))
	var evolved := level >= 6
	var attack: float = game.attack_multiplier()
	var speed: float = game.projectile_multiplier()
	var duration: float = game.duration_multiplier()
	var area: float = game.area_multiplier()
	var interval := 1.0
	match weapon:
		"lightning":
			interval = 2.4 if evolved else 3.8 - level * 0.18
			var hit: Dictionary = {}
			var count := 7 if evolved else 1 + floori(level / 2.0)
			for _strike in range(count):
				var victim := _nearest(game, hero, 850.0, hit)
				if victim.is_empty():
					break
				var point: Vector2 = victim.p
				hit[_enemy_id(victim)] = true
				game._damage_enemy(victim, (115.0 if evolved else 32.0 + level * 13.0) * attack, weapon)
				_add_effect({"kind": "lightning", "p": point, "life": 0.3, "max_life": 0.3, "size": 22.0 * area, "color": BLUE})
				if evolved:
					_explode(game, point, 58.0 * area, 42.0 * attack, BLUE, weapon)
			game._play("pulse", target.p)
		"rocket":
			interval = 3.0 if evolved else 4.4 - level * 0.18
			var count := 3 if evolved else 1 + floori(level / 3.0)
			for i in range(count):
				var aim := direction.rotated((i - (count - 1) * 0.5) * 0.18)
				_add_projectile({"kind": "rocket", "weapon_id": weapon, "p": hero + aim * 28.0, "v": aim * 360.0 * speed,
					"life": 2.2, "damage": (170.0 if evolved else 45.0 + level * 18.0) * attack,
					"radius": 11.0, "blast": (145.0 if evolved else 62.0 + level * 8.0) * area,
					"target": target, "turn": 4.2, "color": AMBER, "evolved": evolved})
			game._play("shoot", hero)
		"brick":
			interval = 2.7 if evolved else 3.6 - level * 0.14
			var count := 8 if evolved else 1 + level
			for i in range(count):
				var aim := Vector2.from_angle(i * TAU / count) if evolved else direction.rotated((i - (count - 1) * 0.5) * 0.16)
				var velocity := aim * 395.0 * speed
				if not evolved:
					velocity.y -= 145.0
				_add_projectile({"kind": "brick", "weapon_id": weapon, "p": hero + aim * 26.0, "v": velocity,
					"life": 2.2 * duration, "damage": (125.0 if evolved else 22.0 + level * 13.0) * attack,
					"radius": (17.0 if evolved else 11.0) * area, "pierce": 100 if evolved else 2 + level,
					"gravity": 0.0 if evolved else 200.0, "color": LILAC, "evolved": evolved})
			game._play("shoot", hero)
		"soccer":
			interval = 3.3 if evolved else 4.5 - level * 0.13
			var count := 6 if evolved else 1 + floori(level / 2.0)
			for i in range(count):
				var aim := direction.rotated((i - (count - 1) * 0.5) * 0.5)
				_add_projectile({"kind": "soccer", "weapon_id": weapon, "p": hero + aim * 27.0, "v": aim * (620.0 if evolved else 360.0 + level * 20.0) * speed,
					"life": (5.0 if evolved else 3.2) * duration, "damage": (85.0 if evolved else 12.0 + level * 7.0) * attack,
					"radius": (15.0 if evolved else 11.0) * area, "color": MINT, "evolved": evolved})
			game._play("shoot", hero)
		"drone_a", "drone_b", "destroyer":
			var merged := weapon == "destroyer"
			interval = 0.26 if merged else (0.95 if weapon == "drone_a" else 1.1) - level * 0.08
			var origin := _drone_position(hero, weapon)
			var aim := origin.direction_to(Vector2(target.p))
			var count := 3 if merged else 1 + floori(level / 3.0)
			for i in range(count):
				var firing := aim.rotated((i - (count - 1) * 0.5) * 0.2)
				_add_projectile({"kind": "drone", "weapon_id": weapon, "p": origin, "v": firing * (610.0 if merged else 450.0) * speed,
					"life": 1.8 * duration, "damage": (54.0 if merged else 11.0 + level * 7.0) * attack,
					"radius": 6.0 * area, "pierce": 2 if merged else 1, "target": target,
					"turn": 4.0 if merged or weapon == "drone_a" else 0.0,
					"color": MINT if merged else (AMBER if weapon == "drone_a" else BLUE), "evolved": merged})
			game._play("shoot", origin)
	clocks[weapon] = maxf(0.09, interval * game.cooldown_multiplier())


func _add_projectile(projectile: Dictionary) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		return
	projectile["hits"] = {}
	projectile["age"] = 0.0
	projectiles.append(projectile)


func _add_effect(effect: Dictionary) -> void:
	if effects.size() >= MAX_EFFECTS:
		effects.remove_at(0)
	effects.append(effect)


func _explode(game: Node2D, point: Vector2, radius: float, amount: float, color: Color = AMBER, weapon_id: String = "") -> void:
	_add_effect({"kind": "blast", "p": point, "life": 0.4, "max_life": 0.4, "size": radius, "color": color})
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) <= 0.0:
			continue
		var enemy_point: Vector2 = enemy.p
		if enemy_point.distance_squared_to(point) <= pow(radius + _enemy_radius(enemy), 2.0) and game.world.clear_line(point, enemy_point, 3.0):
			game._damage_enemy(enemy, amount, weapon_id)


func _update_projectiles(game: Node2D, dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		var kind: String = projectile.kind
		var old: Vector2 = projectile.p
		var velocity: Vector2 = projectile.v
		var target: Dictionary = projectile.get("target", {})
		var turn: float = projectile.get("turn", 0.0)
		if not target.is_empty() and float(target.hp) > 0.0 and turn > 0.0:
			var desired := old.direction_to(Vector2(target.p))
			velocity = velocity.lerp(desired * velocity.length(), minf(1.0, turn * dt)).normalized() * velocity.length()
		velocity.y += float(projectile.get("gravity", 0.0)) * dt
		var destination := old + velocity * dt
		projectile.life = float(projectile.life) - dt
		projectile.age = float(projectile.age) + dt
		var radius: float = projectile.radius
		if not game.world.clear_line(old, destination, radius * 0.45):
			if kind == "soccer":
				var x_wall: bool = not game.world.clear_line(old, old + Vector2(velocity.x * dt, 0.0), radius * 0.45)
				var y_wall: bool = not game.world.clear_line(old, old + Vector2(0.0, velocity.y * dt), radius * 0.45)
				if x_wall:
					velocity.x = -velocity.x
				if y_wall:
					velocity.y = -velocity.y
				if not x_wall and not y_wall:
					velocity = -velocity
				destination = old + velocity * dt
				if not game.world.clear_line(old, destination, radius * 0.45):
					destination = old
			else:
				destination = old
				projectile.life = 0.0
		projectile.v = velocity
		projectile.p = destination
		var collided := false
		if float(projectile.life) > 0.0:
			for enemy: Dictionary in game.enemies:
				if float(enemy.hp) <= 0.0:
					continue
				var id := _enemy_id(enemy)
				if float(projectile.hits.get(id, 0.0)) > run_time:
					continue
				var enemy_point: Vector2 = enemy.p
				var closest := Geometry2D.get_closest_point_to_segment(enemy_point, old, destination)
				if closest.distance_squared_to(enemy_point) > pow(radius + _enemy_radius(enemy), 2.0):
					continue
				if not game.world.clear_line(closest, enemy_point, 2.0):
					continue
				if kind == "rocket":
					projectile.p = closest
					projectile.life = 0.0
					break
				game._damage_enemy(enemy, float(projectile.damage), String(projectile.get("weapon_id", "")))
				projectile.hits[id] = run_time + (0.22 if kind == "soccer" else 100.0)
				if kind == "soccer":
					var normal := (closest - enemy_point).normalized()
					if normal.length_squared() < 0.1:
						normal = -velocity.normalized()
					projectile.v = velocity.bounce(normal)
					projectile.p = closest
					collided = true
				else:
					projectile.pierce = int(projectile.get("pierce", 1)) - 1
					if int(projectile.pierce) <= 0:
						projectile.life = 0.0
						collided = true
				if collided:
					break
		if float(projectile.life) <= 0.0:
			if kind == "rocket":
				_explode(game, Vector2(projectile.p), float(projectile.blast), float(projectile.damage), AMBER, String(projectile.get("weapon_id", "")))
				game._play("slam", projectile.p)
			projectiles.remove_at(i)


func _drone_position(hero: Vector2, weapon: String) -> Vector2:
	if weapon == "destroyer":
		return hero + Vector2(sin(run_time * 2.2) * 17.0, -70.0)
	var side := -1.0 if weapon == "drone_a" else 1.0
	return hero + Vector2(side * 48.0, -35.0 + sin(run_time * 2.2 + side) * 9.0)


func draw_effects(game: Node2D) -> void:
	for effect: Dictionary in effects:
		var point: Vector2 = effect.p
		var progress: float = 1.0 - float(effect.life) / float(effect.max_life)
		var color: Color = effect.color
		color.a = 1.0 - progress
		if String(effect.kind) == "lightning":
			var bolt := PackedVector2Array([point + Vector2(-11, -220), point + Vector2(14, -157), point + Vector2(-17, -112), point + Vector2(10, -64), point])
			game.draw_polyline(bolt, Color(color, color.a * 0.2), 15.0, true)
			game.draw_polyline(bolt, color, 3.0, true)
			game.draw_circle(point, float(effect.size) * (0.5 + progress), Color(color, color.a * 0.25))
		else:
			var radius: float = float(effect.size) * (0.25 + progress * 0.75)
			game.draw_circle(point, radius, Color(color, color.a * 0.09))
			game.draw_arc(point, radius, 0.0, TAU, 40, color, 3.0 * (1.0 - progress) + 1.0, true)
	for projectile: Dictionary in projectiles:
		_draw_projectile(game, projectile)
	if guardian_visible:
		for point: Vector2 in guardian_points:
			var angle := guardian_angle * -2.0
			var arm := Vector2.from_angle(angle) * guardian_size
			var cross := arm.orthogonal()
			var color := AMBER if guardian_evolved else MINT
			game.draw_circle(point, guardian_size + 4.0, Color(color, 0.08))
			game.draw_line(point - arm, point + arm, color, 5.0, true)
			game.draw_line(point - cross, point + cross, color, 5.0, true)
			game.draw_circle(point, 4.0, Color("edf7ee"))
	var merged: bool = game.progression.get_level("destroyer") > 0
	for weapon: String in (["destroyer"] if merged else ["drone_a", "drone_b"]):
		if game.progression.get_level(weapon) <= 0:
			continue
		var point := _drone_position(game.hero, weapon)
		var color := MINT if merged else (AMBER if weapon == "drone_a" else BLUE)
		var span := 19.0 if merged else 13.0
		game.draw_line(point - Vector2(span, 0), point + Vector2(span, 0), color, 4.0, true)
		game.draw_circle(point - Vector2(span, 0), 6.0, Color(color, 0.25))
		game.draw_circle(point + Vector2(span, 0), 6.0, Color(color, 0.25))
		var body := Rect2(point - Vector2(9, 6), Vector2(18, 12))
		game.draw_rect(body, Color("193c3f"))
		game.draw_rect(body, color, false, 2.0)
		game.draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color("efffff"), 2.0)
		game.draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color("efffff"), 2.0)


func _draw_projectile(game: Node2D, projectile: Dictionary) -> void:
	var point: Vector2 = projectile.p
	var velocity: Vector2 = projectile.v
	var color: Color = projectile.color
	var radius: float = projectile.radius
	var kind: String = projectile.kind
	var direction := velocity.normalized()
	match kind:
		"rocket":
			var side := direction.orthogonal()
			game.draw_line(point - direction * 21.0, point, Color(color, 0.4), 6.0, true)
			game.draw_colored_polygon(PackedVector2Array([point + direction * 14.0, point - direction * 10.0 + side * 7.0, point - direction * 5.0, point - direction * 10.0 - side * 7.0]), color)
		"brick":
			var angle: float = float(projectile.age) * 6.0
			var arm := Vector2.from_angle(angle) * radius
			var across := arm.orthogonal() * 0.65
			game.draw_colored_polygon(PackedVector2Array([point - arm - across, point + arm - across, point + arm + across, point - arm + across]), color)
			game.draw_line(point - arm * 0.6, point + arm * 0.6, Color("604970"), 2.0, true)
			if bool(projectile.evolved):
				game.draw_circle(point - arm, radius * 0.55, color)
				game.draw_circle(point + arm, radius * 0.55, color)
		"soccer":
			game.draw_line(point - direction * radius * 2.5, point, Color(color, 0.22), radius, true)
			game.draw_circle(point, radius, color)
			game.draw_arc(point, radius * 0.75, float(projectile.age) * 5.0, float(projectile.age) * 5.0 + PI, 12, Color("30675c"), 2.0, true)
			game.draw_circle(point, radius * 0.3, Color("30675c"))
		"drone":
			game.draw_line(point - direction * 17.0, point, Color(color, 0.3), radius * 1.2, true)
			game.draw_line(point - direction * 8.0, point + direction * 4.0, color, radius, true)
