extends Node2D

var game: Node2D
var overlay: Control
var title: Label
var subtitle: Label
var primary: Button

func _ready() -> void:
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.position = Vector2(1066, 27)
	pause_button.size = Vector2(48, 42)
	_style_button(pause_button)
	pause_button.pressed.connect(func():
		if not game.won: game.set_paused(not game.paused))
	add_child(pause_button)
	overlay = Control.new()
	overlay.visible = false
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.105, 0.14, 0.83)
	shade.size = Vector2(1152, 648)
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(326, 158)
	panel.size = Vector2(500, 330)
	var style: StyleBoxFlat = game._box(Color("21444e"), 20)
	style.border_color = Color("5b7c7a")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	title = Label.new()
	title.position = Vector2(345, 198)
	title.size = Vector2(462, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("f3e6bb"))
	overlay.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(345, 275)
	subtitle.size = Vector2(462, 70)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("bdd6cb"))
	overlay.add_child(subtitle)
	primary = Button.new()
	primary.position = Vector2(436, 379)
	primary.size = Vector2(280, 56)
	_style_button(primary)
	primary.pressed.connect(func():
		if game.won: game.restart()
		else: game.set_paused(false))
	overlay.add_child(primary)

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", game._box(Color("3a6266"), 10))
	button.add_theme_stylebox_override("hover", game._box(Color("4e7b76"), 10))
	button.add_theme_stylebox_override("pressed", game._box(Color("203e49"), 10))
	var focus: StyleBoxFlat = game._box(Color(0, 0, 0, 0), 10)
	focus.border_color = Color("f2d390")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)

func update_overlay() -> void:
	overlay.visible = game.won or game.paused
	if overlay.visible:
		title.text = "THE LIGHT IS YOURS" if game.won else "TAKE A BREATH"
		subtitle.text = ("%d / 10 light shards   /   %s   /   %d falls\n%s" % [game.collected.size(), _time(game.elapsed), game.deaths, "A perfect constellation." if game.collected.size() == 10 else "Every journey leaves a little light."]) if game.won else "The islands will wait for you.\nESC or ENTER to continue  /  R to start over"
		primary.text = "PLAY AGAIN   [ ENTER ]" if game.won else "CONTINUE   [ ENTER ]"
		primary.grab_focus()
	else:
		primary.release_focus()

func _draw() -> void:
	draw_style_box(game._box(Color(0.06, 0.17, 0.21, 0.88), 15), Rect2(28, 24, 282, 76))
	_text(Vector2(48, 54), "SKYBOUND", 26, Color("f1e8c9"))
	_text(Vector2(49, 79), "F I R S T   L I G H T", 11, Color("a7c6b9"))
	draw_style_box(game._box(Color(0.06, 0.17, 0.21, 0.85), 12), Rect2(798, 27, 251, 42))
	game_gem(Vector2(820, 48))
	_text(Vector2(839, 55), "%02d / 10" % game.collected.size(), 19, Color("f4dca0"))
	_text(Vector2(944, 54), _time(game.elapsed), 18, Color("d2e3d5"))
	_text(Vector2(800, 91), "REST POINT  /  " + ("LIT" if game.checkpoint_active else "UNLIT"), 11, Color("bad1bb"))
	draw_style_box(game._box(Color(0.07, 0.18, 0.21, 0.7), 3), Rect2(399, 43, 313, 5))
	draw_style_box(game._box(Color("bad69c"), 3), Rect2(399, 43, maxf(4, 313 * clampf(game.player.position.x / 3300, 0, 1)), 5))
	_text(Vector2(399, 71), "THE QUIET ASCENT" if not game.checkpoint_active else "ABOVE THE CLOUDS", 11, Color("c2d9c7"))
	draw_style_box(game._box(Color(0.06, 0.17, 0.21, 0.9), 12), Rect2(28, 585, 1096, 39))
	_text(Vector2(48, 611), "A / D  or  ARROWS   Move", 14, Color("d4e4d4"))
	_text(Vector2(325, 611), "SPACE / W / UP   Jump  (hold for height)", 14, Color("d4e4d4"))
	_text(Vector2(730, 611), "R   Restart", 14, Color("b4ccbf"))
	_text(Vector2(925, 611), "ESC   Pause", 14, Color("b4ccbf"))
	if game.notice_time > 0 and not game.won and not game.paused:
		var value: String = game.notice
		var width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_style_box(game._box(Color(0.08, 0.22, 0.25, minf(game.notice_time, 0.85)), 16), Rect2(576 - width / 2 - 22, 120, width + 44, 40))
		_text(Vector2(576 - width / 2, 146), value, 17, Color("f0e5c4"))

func _text(p: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds / 60.0), int(seconds) % 60]

func game_gem(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10), p + Vector2(7, 0), p + Vector2(0, 10), p + Vector2(-7, 0)]), Color("f4dca0"))
