extends Node2D

const FLOOR := 510.0
var fighters: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var time := 0.0
var remaining := 60.0
var ended := false
var banner := ""
var shake := 0.0
var font := ThemeDB.fallback_font
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	reset()

func reset() -> void:
	fighters = [make_fighter(310.0, Color("52e0ef")), make_fighter(840.0, Color("ff626f"))]
	remaining = 60.0
	ended = false
	banner = ""
	sparks.clear()

func make_fighter(x: float, color: Color) -> Dictionary:
	return {"x": x, "y": FLOOR, "vy": 0.0, "hp": 100.0, "color": color, "face": 1.0, "attack": "", "anim": 0.0, "cool": 0.0, "stun": 0.0, "guard": false, "hit": false, "walk": 0.0, "ai": 0.0}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset()
		if not ended:
			if event.keycode == KEY_J:
				attack(0, "PUNCH")
			if event.keycode == KEY_K:
				attack(0, "KICK")
			if event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP:
				if fighters[0].y >= FLOOR and fighters[0].stun <= 0:
					fighters[0].vy = -590.0

func attack(index: int, kind: String) -> void:
	var f: Dictionary = fighters[index]
	if f.cool > 0 or f.stun > 0 or f.guard:
		return
	f.attack = kind
	f.anim = 0.33 if kind == "PUNCH" else 0.47
	f.cool = 0.40 if kind == "PUNCH" else 0.64
	f.hit = false

func _process(delta: float) -> void:
	time += delta
	shake = maxf(0, shake - delta * 35)
	for s in sparks:
		s.pos += s.vel * delta
		s.vel.y += 400 * delta
		s.life -= delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s.life > 0)
	if not ended:
		remaining = maxf(0, remaining - delta)
		for i in range(2):
			var f: Dictionary = fighters[i]
			var other: Dictionary = fighters[1-i]
			f.face = 1.0 if other.x > f.x else -1.0
			f.cool = maxf(0, f.cool - delta)
			f.stun = maxf(0, f.stun - delta)
			f.anim = maxf(0, f.anim - delta)
			var move := 0.0
			if i == 0:
				f.guard = Input.is_physical_key_pressed(KEY_L) and f.y >= FLOOR and f.anim <= 0
				move = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			else:
				f.ai -= delta
				f.guard = other.anim > 0 and absf(other.x-f.x) < 155 and sin(time*7) > -0.2 and f.anim <= 0
				if absf(other.x-f.x) > 110:
					move = f.face
				elif absf(other.x-f.x) < 65:
					move = -f.face
				if f.ai <= 0:
					f.ai = rng.randf_range(0.24, 0.65)
					if absf(other.x-f.x) < 150:
						attack(i, "PUNCH" if rng.randf() < 0.55 else "KICK")
					if other.y < FLOOR - 30 and f.y >= FLOOR and rng.randf() < 0.3:
						f.vy = -560.0
			if f.stun <= 0 and f.anim <= 0 and not f.guard:
				f.x = clampf(f.x + move * 255 * delta, 65, 1087)
				f.walk += absf(move) * delta * 12
			f.vy += 1500 * delta
			f.y = minf(FLOOR, f.y + f.vy * delta)
			if f.y >= FLOOR:
				f.vy = 0.0
			if f.anim > 0 and not f.hit:
				var reach := 108.0 if f.attack == "PUNCH" else 152.0
				if f.anim < (0.24 if f.attack == "PUNCH" else 0.34) and absf(f.x-other.x) < reach and absf(f.y-other.y) < 85:
					f.hit = true
					var blocked: bool = other.guard
					other.hp = maxf(0, other.hp - (2 if blocked else (9 if f.attack == "PUNCH" else 15)))
					other.stun = 0.12 if blocked else 0.27
					other.x = clampf(other.x + f.face * (12 if blocked else 32), 65, 1087)
					shake = 3.0 if blocked else 8.0
					for n in range(12):
						sparks.append({"pos": Vector2(other.x, other.y-83), "vel": Vector2(rng.randf_range(-230,230),rng.randf_range(-270,80)), "life": rng.randf_range(0.15,0.4), "color": Color("ffe9a0") if blocked else f.color})
		if absf(fighters[0].x-fighters[1].x) < 54:
			var mid: float = (fighters[0].x+fighters[1].x)/2
			fighters[0].x = mid - fighters[0].face*27
			fighters[1].x = mid + fighters[0].face*27
		if remaining <= 0 or fighters[0].hp <= 0 or fighters[1].hp <= 0:
			ended = true
			banner = "YOU WIN" if fighters[0].hp > fighters[1].hp else "CPU WINS"
			if fighters[0].hp == fighters[1].hp:
				banner = "DRAW"
	queue_redraw()

func label_at(pos: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func limb(points: Array, color: Color, width: float = 8.0) -> void:
	for i in range(points.size()-1):
		draw_line(points[i], points[i+1], color, width, true)
	for p in points:
		draw_circle(p, width/2, color)

func draw_fighter(f: Dictionary) -> void:
	var base := Vector2(f.x, f.y) + Vector2(rng.randf_range(-shake,shake),0)
	var c: Color = f.color
	if f.stun > 0:
		c = Color.WHITE
	var face: float = f.face
	var bob := sin(f.walk)*3 if f.y >= FLOOR else 0.0
	var hip := base + Vector2(0,-49+bob)
	var neck := base + Vector2(0,-103+bob)
	var head := neck + Vector2(face*2,-22)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(f.x,FLOOR+5), 29, Color(0,0,0,0.25))
	limb([hip, neck], c, 9)
	draw_arc(head, 17, 0, TAU, 36, c, 5, true)
	draw_line(head+Vector2(face*7,-3),head+Vector2(face*13,-3),Color.WHITE,3,true)
	var stride := sin(f.walk)*16 if f.anim <= 0 and not f.guard else 0.0
	limb([hip,base+Vector2(-15,-25),base+Vector2(-23-stride,0)],c)
	if f.anim > 0 and f.attack == "KICK":
		limb([hip,hip+Vector2(face*43,-18),hip+Vector2(face*119,-28)],c,9)
	else:
		limb([hip,base+Vector2(16,-24),base+Vector2(25+stride,0)],c)
	if f.guard:
		limb([neck,neck+Vector2(face*21,18),neck+Vector2(face*29,-17)],c)
		limb([neck,neck+Vector2(face*33,23),neck+Vector2(face*41,-8)],c)
		draw_arc(neck+Vector2(face*33,0),34,-1.7,1.7,24,Color(0.6,0.9,1,0.3),3,true)
	else:
		limb([neck,neck+Vector2(-face*23,28),neck+Vector2(-face*6,43)],c)
		if f.anim > 0 and f.attack == "PUNCH":
			limb([neck,neck+Vector2(face*43,-2),neck+Vector2(face*91,-6)],c)
			draw_circle(neck+Vector2(face*94,-6),8,Color.WHITE)
		else:
			limb([neck,neck+Vector2(face*24,20),neck+Vector2(face*35,0)],c)

func _draw() -> void:
	draw_rect(Rect2(0,0,1152,648),Color("101729"))
	for i in range(12):
		var x := float(i*110)
		draw_rect(Rect2(x,230+(i%3)*28,80,280),Color("19223a"))
		for j in range(5):
			draw_rect(Rect2(x+15,260+(i%3)*28+j*40,8,15),Color("26344b"))
	draw_circle(Vector2(900,200),52,Color("26374e"))
	label_at(Vector2(45,42),"STICK / STRIKE",24,Color("d8e5ff"))
	label_at(Vector2(890,40),"ROOFTOP ARENA",16,Color("8b9ab5"))
	draw_rect(Rect2(0,515,1152,133),Color("0b1020"))
	draw_line(Vector2(0,514),Vector2(1152,514),Color("52e0ef"),3)
	for i in range(19):
		draw_line(Vector2(576,515),Vector2(i*100-320,648),Color("1b2940"),1)
	for y in [545,590,646]:
		draw_line(Vector2(0,y),Vector2(1152,y),Color("1b2940"),1)
	for i in range(2):
		var x := 48.0 if i == 0 else 702.0
		var f: Dictionary = fighters[i]
		label_at(Vector2(x,86),"01  /  YOU" if i == 0 else "02  /  CPU",18,f.color)
		draw_rect(Rect2(x,98,400,18),Color("293148"))
		draw_rect(Rect2(x,98,400*f.hp/100,18),f.color)
		label_at(Vector2(x,140),"%03d" % int(f.hp),16,Color("9aaac4"))
	label_at(Vector2(550,106),"%02d" % ceili(remaining),38,Color.WHITE)
	label_at(Vector2(542,132),"TIME",14,Color("8b9ab5"))
	for f in fighters:
		draw_fighter(f)
	for s in sparks:
		draw_circle(s.pos,3,s.color)
	label_at(Vector2(48,585),"A D / ARROWS   MOVE     SPACE   JUMP",17,Color("b2c2db"))
	label_at(Vector2(48,617),"J   PUNCH      K   KICK      L   GUARD",17,Color("b2c2db"))
	label_at(Vector2(925,615),"R   RESTART",17,Color("52e0ef"))
	if time < 2.0 and not ended:
		label_at(Vector2(480,270),"FIGHT!",54,Color("ffe3a0"))
	if ended:
		draw_rect(Rect2(270,220,612,170),Color(0.03,0.05,0.10,0.94))
		label_at(Vector2(414,293),banner,48,Color("ffe3a0"))
		label_at(Vector2(429,346),"PRESS R TO FIGHT AGAIN",20,Color.WHITE)
