extends Node2D
## Repeating, connected wards. Only the surrounding 3x3 modules are retained.

const MODULE := Vector2(1536, 1152)
const CELL := 64
const ROOMS := [Rect2(64, 64, 576, 384), Rect2(896, 64, 576, 384), Rect2(64, 704, 576, 384), Rect2(896, 704, 576, 384)]
var chunks: Dictionary = {}
var local_walls: Array[Rect2] = []
var local_solids: Array[Rect2] = []
var solid_buckets: Dictionary = {}
var center_chunk := Vector2i(99999, 99999)
var visible_chunks := Rect2i()
var navigation := AStarGrid2D.new()
var atlas: Texture2D
var props: Array[Texture2D] = []
var font: Font
var glow: Texture2D
var current_theme := 0

func set_stage(index: int) -> void:
	var next := posmod(index - 1, 3)
	if next == current_theme and not local_solids.is_empty():
		return
	current_theme = next
	local_walls.clear()
	local_solids.clear()
	solid_buckets.clear()
	_build_geometry()
	center_chunk = Vector2i(99999, 99999)
	update_chunks(Vector2(768, 576))
	queue_redraw()

func _ready() -> void:
	atlas = load("res://assets/hospital_atlas.png")
	font = preload("res://assets/fonts/Pretendard-Regular.otf")
	for i in range(4):
		props.append(atlas_cell(atlas, i, i != 0))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.35, 0.92, 0.82, 0.16), Color(0.2, 0.8, 0.7, 0)])
	var light := GradientTexture2D.new()
	light.gradient = gradient
	light.width = 128
	light.height = 128
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.5)
	light.fill_to = Vector2(1, 0.5)
	glow = light
	_build_geometry()
	update_chunks(Vector2(768, 576))

static func atlas_cell(texture: Texture2D, index: int, trim: bool = true) -> AtlasTexture:
	var size := Vector2i(texture.get_width() >> 1, texture.get_height() >> 1)
	var corner := Vector2i(index % 2, index >> 1) * size
	var region := Rect2i(corner, size)
	if trim:
		var image := texture.get_image().get_region(region)
		# Generated sheets contain faint alpha specks in their padding. Bound
		# the visible subject, rather than stretching those specks into a sprite.
		var low := size
		var high := Vector2i.ZERO
		for y in range(8, size.y - 8, 2):
			for x in range(8, size.x - 8, 2):
				if image.get_pixel(x, y).a > 0.35:
					low = low.min(Vector2i(x, y))
					high = high.max(Vector2i(x, y))
		var used := Rect2i((low - Vector2i(3, 3)).max(Vector2i.ZERO), (high - low + Vector2i(7, 7)).min(size - (low - Vector2i(3, 3)).max(Vector2i.ZERO)))
		region = Rect2i(corner + used.position, used.size)
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = region
	result.filter_clip = true
	return result

func _build_geometry() -> void:
	if current_theme == 2:
		# A spacious operating theatre, with connected doorways on four sides.
		for y in [64, 1064]:
			local_walls.append(Rect2(64, y, 576, 24))
			local_walls.append(Rect2(896, y, 576, 24))
		for x in [64, 1448]:
			local_walls.append(Rect2(x, 64, 24, 384))
			local_walls.append(Rect2(x, 704, 24, 384))
		for point in [Vector2(160, 140), Vector2(1270, 140), Vector2(160, 850), Vector2(1270, 850)]:
			local_solids.append(Rect2(point, Vector2(80, 150)))
		for point in [Vector2(350, 120), Vector2(1070, 120), Vector2(350, 930), Vector2(1070, 930)]:
			local_solids.append(Rect2(point, Vector2(110, 90)))
		local_solids.append_array(local_walls)
		_index_solids()
		return
	for i in range(ROOMS.size()):
		var r: Rect2 = ROOMS[i]
		var x := r.position.x
		var y := r.position.y
		var w := r.size.x
		var h := r.size.y
		var top_room := i < 2
		# Doors face both the central horizontal and vertical corridors.
		for edge_y in [y, y + h - 24]:
			var door: bool = (top_room and edge_y > y) or (not top_room and edge_y == y)
			if door:
				local_walls.append(Rect2(x, edge_y, 224, 24))
				local_walls.append(Rect2(x + 352, edge_y, w - 352, 24))
			else:
				local_walls.append(Rect2(x, edge_y, w, 24))
		for edge_x in [x, x + w - 24]:
			var inward: bool = (i % 2 == 0 and edge_x > x) or (i % 2 == 1 and edge_x == x)
			if inward:
				local_walls.append(Rect2(edge_x, y, 24, 128))
				local_walls.append(Rect2(edge_x, y + 256, 24, h - 256))
			else:
				local_walls.append(Rect2(edge_x, y, 24, h))
		# Furniture has the same footprint as the rendered bed/desk.
		local_solids.append(Rect2(x + 65, y + 74, 72, 140))
		local_solids.append(Rect2(x + 211, y + 74, 72, 140))
		local_solids.append(Rect2(x + 390, y + 48, 116, 92))
	local_solids.append_array(local_walls)
	_index_solids()

func _index_solids() -> void:
	# Broad phase: collision probes only inspect nearby furniture and walls.
	for solid in local_solids:
		var expanded := solid.grow(32)
		for y in range(floori(expanded.position.y / CELL), floori(expanded.end.y / CELL) + 1):
			for x in range(floori(expanded.position.x / CELL), floori(expanded.end.x / CELL) + 1):
				var bucket := Vector2i(x, y)
				if not solid_buckets.has(bucket):
					solid_buckets[bucket] = []
				solid_buckets[bucket].append(solid)

func chunk_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / MODULE.x), floori(point.y / MODULE.y))

func update_chunks(point: Vector2) -> void:
	var first := chunk_at(point - Vector2(992, 572))
	var last := chunk_at(point + Vector2(992, 572))
	var visible_next := Rect2i(first, last - first + Vector2i.ONE)
	if visible_next != visible_chunks:
		visible_chunks = visible_next
		queue_redraw()
	var next := chunk_at(point)
	if next == center_chunk:
		return
	center_chunk = next
	chunks.clear()
	for y in range(-1, 2):
		for x in range(-1, 2):
			var key := next + Vector2i(x, y)
			chunks[key] = Vector2(key) * MODULE
	# Pathfinding uses a bounded window and is rebuilt only across module borders.
	navigation.region = Rect2i((next - Vector2i.ONE) * Vector2i(24, 18), Vector2i(72, 54))
	navigation.cell_size = Vector2(CELL, CELL)
	navigation.offset = Vector2(32, 32)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var region := navigation.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if blocked(Vector2(x * CELL + 32, y * CELL + 32), 23):
				navigation.set_point_solid(Vector2i(x, y))
	queue_redraw()

func blocked(point: Vector2, radius: float = 20) -> bool:
	var local := point - Vector2(chunk_at(point)) * MODULE
	var bucket := Vector2i(floori(local.x / CELL), floori(local.y / CELL))
	for solid: Rect2 in solid_buckets.get(bucket, []):
		if solid.grow(radius).has_point(local):
			return true
	return false

func move_body(point: Vector2, velocity: Vector2, radius: float = 20) -> Vector2:
	# Separate axes permit sliding along walls. Small substeps prevent tunnelling.
	var steps := maxi(1, ceili(velocity.length() / 10.0))
	var step := velocity / float(steps)
	for i in range(steps):
		if not blocked(point + Vector2(step.x, 0), radius):
			point.x += step.x
		if not blocked(point + Vector2(0, step.y), radius):
			point.y += step.y
	return point

func clear_line(from: Vector2, to: Vector2, radius: float = 8) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 22.0))
	for i in range(1, steps + 1):
		if blocked(from.lerp(to, float(i) / steps), radius):
			return false
	return true

func path_to(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := Vector2i(floori(from.x / CELL), floori(from.y / CELL))
	var b := Vector2i(floori(to.x / CELL), floori(to.y / CELL))
	if not navigation.is_in_boundsv(a) or not navigation.is_in_boundsv(b):
		return PackedVector2Array()
	# Find a reachable nearby cell when an actor stands beside a wall.
	a = _open_cell(a)
	b = _open_cell(b)
	if a == Vector2i(999999, 999999) or b == Vector2i(999999, 999999):
		return PackedVector2Array()
	return navigation.get_point_path(a, b)

func _open_cell(cell: Vector2i) -> Vector2i:
	if not navigation.is_point_solid(cell):
		return cell
	for radius in range(1, 4):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var p := cell + Vector2i(x, y)
				if navigation.is_in_boundsv(p) and not navigation.is_point_solid(p):
					return p
	return Vector2i(999999, 999999)

func _draw() -> void:
	if atlas == null:
		return
	for key in chunks:
		if visible_chunks.has_point(key):
			_draw_module(chunks[key], key)

func _draw_module(origin: Vector2, key: Vector2i) -> void:
	var floor_tint: Color = [Color(0.60, 0.71, 0.71), Color(0.70, 0.59, 0.54), Color(0.54, 0.65, 0.76)][current_theme]
	for y in range(3):
		for x in range(4):
			draw_texture_rect(props[0], Rect2(origin + Vector2(x, y) * 384, Vector2(384, 384)), false, floor_tint)
	# Painted wayfinding strips continue through every module boundary.
	draw_rect(Rect2(origin + Vector2(734, 0), Vector2(5, 1152)), Color(0.28, 0.76, 0.67, 0.28))
	draw_rect(Rect2(origin + Vector2(797, 0), Vector2(5, 1152)), Color(0.28, 0.76, 0.67, 0.28))
	draw_rect(Rect2(origin + Vector2(0, 542), Vector2(1536, 5)), Color(0.28, 0.76, 0.67, 0.28))
	draw_rect(Rect2(origin + Vector2(0, 605), Vector2(1536, 5)), Color(0.28, 0.76, 0.67, 0.28))
	if current_theme == 2:
		_draw_theatre(origin)
	for i in range(0 if current_theme == 2 else ROOMS.size()):
		var r: Rect2 = ROOMS[i]
		var p := origin + r.position
		draw_rect(Rect2(p + Vector2(24, 24), r.size - Vector2(48, 48)), Color(0.11, 0.22, 0.24, 0.14))
		for footprint in [Rect2(65, 74, 72, 140), Rect2(211, 74, 72, 140), Rect2(390, 48, 116, 92), Rect2(405, 263, 67, 72)]:
			draw_rect(Rect2(p + footprint.position + Vector2(5, 7), footprint.size), Color(0, 0.02, 0.03, 0.25))
		_prop(1, Rect2(p + Vector2(65, 74), Vector2(72, 140)))
		_prop(1, Rect2(p + Vector2(211, 74), Vector2(72, 140)))
		_prop(3, Rect2(p + Vector2(390, 48), Vector2(116, 92)))
		_prop(2, Rect2(p + Vector2(405, 263), Vector2(67, 72)))
		# Curtain rail and partially drawn curtain between the beds.
		draw_line(p + Vector2(174, 45), p + Vector2(174, 224), Color("738f8e"), 3, true)
		for n in range(8):
			draw_rect(Rect2(p + Vector2(169, 46 + n * 10), Vector2(12, 7)), Color("8a5845") if current_theme == 1 else Color("436963"))
		var ward := absi(key.x * 31 + key.y * 17 + i) % 900 + 100
		var label_p := p + Vector2(228, 300 if i < 2 else 61)
		draw_string(font, label_p, "WARD %03d" % ward, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.86, 0.83, 0.7))
		# Light pools and small wall fixtures.
		draw_texture_rect(glow, Rect2(p + Vector2(164, 78), Vector2(240, 240)), false)
		draw_rect(Rect2(p + Vector2(230, 29), Vector2(104, 5)), Color("92c6b9"))
	for wall in local_walls:
		var r := Rect2(origin + wall.position, wall.size)
		draw_rect(Rect2(r.position + Vector2(7, 12), r.size + Vector2(4, 6)), Color(0, 0.03, 0.04, 0.4))
		draw_rect(r, Color("263b40"))
		draw_rect(Rect2(r.position, r.size - Vector2(0, 7)), Color("788c89"))
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), Color("b1bfad"))
	var sign_position := origin + Vector2(656, 487)
	draw_rect(Rect2(sign_position, Vector2(224, 39)), Color("24423e"))
	var sign_text: String = ["EMERGENCY  +", "ISOLATION  +", "SURGERY  +"][current_theme]
	draw_string(font, sign_position + Vector2(19, 26), sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("efad83") if current_theme == 1 else Color("93d2bc"))
	# Small irregular litter; deterministic per module, with no collision.
	for n in range(7):
		var seed_value := absi(key.x * 137 + key.y * 313 + n * 197)
		var paper := origin + Vector2(670 + seed_value % 180, 80 + (seed_value * 17) % 960)
		var corners := PackedVector2Array()
		for corner in [Vector2(-5, -7), Vector2(5, -7), Vector2(5, 7), Vector2(-5, 7)]:
			corners.append(paper + corner.rotated(float(n) * 0.7))
		draw_colored_polygon(corners, Color(0.65, 0.71, 0.63, 0.5))

func _prop(index: int, rect: Rect2) -> void:
	draw_texture_rect(props[index], rect, false, Color(0.85, 0.93, 0.89))

func _draw_theatre(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(312, 248), Vector2(912, 656)), Color(0.10, 0.22, 0.30, 0.16))
	draw_rect(Rect2(origin + Vector2(312, 248), Vector2(912, 656)), Color(0.60, 0.77, 0.84, 0.4), false, 3)
	draw_arc(origin + Vector2(768, 576), 245, 0, TAU, 64, Color(0.5, 0.75, 0.8, 0.18), 2, true)
	for point in [Vector2(160, 140), Vector2(1270, 140), Vector2(160, 850), Vector2(1270, 850)]:
		_prop(1, Rect2(origin + point, Vector2(80, 150)))
	for point in [Vector2(350, 120), Vector2(1070, 120), Vector2(350, 930), Vector2(1070, 930)]:
		_prop(3, Rect2(origin + point, Vector2(110, 90)))
	draw_string(font, origin + Vector2(594, 350), "OPERATING THEATRE  /  03", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("a5c9d5"))
