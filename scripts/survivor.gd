extends Node2D

var hero := Vector2(576,324)
var hp := 100.0
var elapsed := 0.0
var fire := 0.0
var spawn := 0.0
var level := 1
var xp := 0
var damage := 20.0
var interval := 0.65
var speed := 235.0
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var gems: Array[Vector2] = []
var choosing := false
var ended := false
var kills := 0
var font := ThemeDB.fallback_font

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		if choosing:
			if event.keycode == KEY_1:
				damage += 12
			elif event.keycode == KEY_2:
				interval = maxf(0.12, interval * 0.8)
			elif event.keycode == KEY_3:
				hp = minf(100, hp+35)
				speed += 20
			else:
				return
			choosing = false

func _process(dt: float) -> void:
	if choosing or ended:
		queue_redraw()
		return
	elapsed += dt
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	hero += move.normalized()*speed*dt
	hero = hero.clamp(Vector2(24,105),Vector2(1128,615))
	spawn -= dt
	if spawn <= 0:
		spawn = maxf(0.16,0.85-elapsed*0.004)
		var p := Vector2.ZERO
		match randi()%4:
			0: p = Vector2(-20,randf_range(110,620))
			1: p = Vector2(1172,randf_range(110,620))
			2: p = Vector2(randf_range(0,1152),80)
			3: p = Vector2(randf_range(0,1152),670)
		enemies.append({"p":p,"hp":30.0+elapsed*0.3,"speed":randf_range(42,76)+elapsed*0.25})
	fire -= dt
	if fire <= 0 and not enemies.is_empty():
		fire = interval
		var target: Vector2 = enemies[0].p
		for e in enemies:
			if hero.distance_squared_to(e.p) < hero.distance_squared_to(target):
				target = e.p
		shots.append({"p":hero,"v":hero.direction_to(target)*620,"life":2.0})
	for e in enemies:
		e.p += e.p.direction_to(hero)*e.speed*dt
		if e.p.distance_to(hero) < 25:
			hp -= 23*dt
	for b in shots:
		b.p += b.v*dt
		b.life -= dt
		for e in enemies:
			if e.hp > 0 and b.life > 0 and b.p.distance_to(e.p) < 23:
				e.hp -= damage
				b.life = 0
				if e.hp <= 0:
					gems.append(e.p)
					kills += 1
	shots = shots.filter(func(b: Dictionary) -> bool: return b.life > 0)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	for i in range(gems.size()-1,-1,-1):
		if gems[i].distance_to(hero) < 100:
			gems[i] = gems[i].move_toward(hero,380*dt)
		if gems[i].distance_to(hero) < 22:
			gems.remove_at(i)
			xp += 1
	if xp >= level*5:
		xp -= level*5
		level += 1
		choosing = true
	if hp <= 0 or elapsed >= 180:
		ended = true
	queue_redraw()

func text_at(p: Vector2, value: String, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func stick(p: Vector2,c: Color,anim: float) -> void:
	draw_circle(p+Vector2(0,19),16,Color(0,0,0,0.25))
	draw_arc(p+Vector2(0,-25),9,0,TAU,20,c,3,true)
	draw_line(p+Vector2(0,-15),p+Vector2(0,4),c,4,true)
	draw_line(p+Vector2(0,-9),p+Vector2(-12,1),c,3,true)
	draw_line(p+Vector2(0,-9),p+Vector2(12,1),c,3,true)
	draw_line(p+Vector2(0,4),p+Vector2(-8-sin(anim)*4,20),c,3,true)
	draw_line(p+Vector2(0,4),p+Vector2(8+sin(anim)*4,20),c,3,true)

func _draw() -> void:
	draw_rect(Rect2(0,0,1152,648),Color("101b24"))
	for x in range(0,1152,48):
		draw_line(Vector2(x,96),Vector2(x,648),Color("192a34"))
	for y in range(96,648,48):
		draw_line(Vector2(0,y),Vector2(1152,y),Color("192a34"))
	for g in gems:
		draw_colored_polygon(PackedVector2Array([g+Vector2(0,-7),g+Vector2(5,0),g+Vector2(0,7),g+Vector2(-5,0)]),Color("58eeb5"))
	for e in enemies:
		stick(e.p,Color("f07788"),elapsed*8)
	for b in shots:
		draw_circle(b.p,6,Color("ffe4a0"))
		draw_line(b.p,b.p-b.v.normalized()*16,Color("d5a85c"),3,true)
	stick(hero,Color("64e3f5"),elapsed*10)
	draw_arc(hero,27,0,TAU,32,Color(0.4,0.9,1,0.18),2,true)
	draw_rect(Rect2(0,0,1152,96),Color("0a111c"))
	text_at(Vector2(25,32),"STICK / SURVIVOR",24)
	text_at(Vector2(460,35),"%02d:%02d / 03:00" % [int(elapsed)/60,int(elapsed)%60],26,Color("ffe4a0"))
	text_at(Vector2(870,32),"LV %d    KILLS %d" % [level,kills],20)
	draw_rect(Rect2(25,48,270,12),Color("372732"))
	draw_rect(Rect2(25,48,270*maxf(0,hp)/100,12),Color("f07788"))
	text_at(Vector2(25,82),"WASD / ARROWS : MOVE     AUTO FIRE     R : RESTART",16,Color("a4bbc8"))
	draw_rect(Rect2(0,92,1152,4),Color("263944"))
	draw_rect(Rect2(0,92,1152*float(xp)/(level*5),4),Color("58eeb5"))
	if choosing or ended:
		draw_rect(Rect2(0,96,1152,552),Color(0.02,0.04,0.08,0.84))
		if choosing and not ended:
			text_at(Vector2(405,245),"LEVEL UP / CHOOSE",32,Color("58eeb5"))
			var options := ["1   POWER  /  +12 damage","2   RAPID  /  faster attacks","3   VITALITY  /  heal + speed"]
			for i in range(3):
				draw_rect(Rect2(350,280+i*67,460,52),Color("203440"))
				text_at(Vector2(373,314+i*67),options[i],22)
		else:
			text_at(Vector2(420,290),"YOU SURVIVED!" if hp > 0 else "RUN ENDED",42,Color("ffe4a0"))
			text_at(Vector2(410,350),"%d kills  /  Level %d  /  %ds" % [kills,level,int(elapsed)],24)
			text_at(Vector2(435,400),"PRESS R TO RESTART",22)
