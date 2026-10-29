extends CharacterBody2D

signal jumped
signal landed

const SPEED := 300.0
const JUMP := -610.0
const GRAVITY := 1550.0
var coyote := 0.0
var jump_buffer := 0.0
var facing := 1.0
var clock := 0.0
var enabled := true
var invulnerable := 0.0

func _physics_process(delta: float) -> void:
	clock += delta
	invulnerable = maxf(0, invulnerable - delta)
	if not enabled:
		queue_redraw()
		return
	var grounded := is_on_floor()
	coyote = 0.12 if grounded else maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.14
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * SPEED, (2400.0 if grounded else 1600.0) * delta)
	if direction != 0:
		facing = direction
	if jump_buffer > 0 and coyote > 0:
		velocity.y = JUMP
		jump_buffer = 0
		coyote = 0
		jumped.emit()
	if Input.is_action_just_released("jump") and velocity.y < -220:
		velocity.y *= 0.55
	velocity.y = minf(velocity.y + GRAVITY * delta, 900)
	move_and_slide()
	position.x = maxf(20, position.x)
	if is_on_floor() and not grounded:
		landed.emit()
	queue_redraw()

func reset_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	coyote = 0
	jump_buffer = 0
	invulnerable = 0.9

func _draw() -> void:
	if invulnerable > 0 and int(clock * 18) % 2 == 0:
		return
	var bob := sin(clock * 15) * 1.6 if is_on_floor() and absf(velocity.x) > 20 else 0.0
	if is_on_floor():
		draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, 19, Color(0.05, 0.15, 0.18, 0.22))
		draw_set_transform(Vector2.ZERO)
	var scarf := PackedVector2Array([Vector2(-facing * 8, -24 + bob), Vector2(-facing * 34, -27 + sin(clock * 16) * 5), Vector2(-facing * 28, -17), Vector2(-facing * 8, -18 + bob)])
	draw_colored_polygon(scarf, Color("f58c69"))
	var body := StyleBoxFlat.new()
	body.bg_color = Color("ecf7e6")
	body.corner_radius_top_left = 12
	body.corner_radius_top_right = 12
	body.corner_radius_bottom_left = 8
	body.corner_radius_bottom_right = 8
	draw_style_box(body, Rect2(-13, -38 + bob, 26, 34))
	draw_circle(Vector2(0, -32 + bob), 14, Color("f4fbec"))
	draw_rect(Rect2(-11, -29 + bob, 22, 12), Color("25454c"))
	draw_circle(Vector2(facing * 4 - 4, -23 + bob), 2, Color("a9ecd4"))
	draw_circle(Vector2(facing * 4 + 4, -23 + bob), 2, Color("a9ecd4"))
	draw_line(Vector2(-8, -4), Vector2(-8 - sin(clock * 15) * absf(velocity.x) / 65, -1), Color("25454c"), 6)
	draw_line(Vector2(8, -4), Vector2(8 + sin(clock * 15) * absf(velocity.x) / 65, -1), Color("25454c"), 6)
