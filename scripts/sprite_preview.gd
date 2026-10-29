extends Node2D
## Isolated SpriteFrames preview; never edits the active game's art.

@export var initial_pack := "res://assets/sprites/reference_medic/sprites.tres"

var frames: SpriteFrames
var actor: AnimatedSprite2D
var state_picker: OptionButton
var path_input: LineEdit
var detail: Label
var status_label: Label
var background_mode := 0
var playing := true

func _ready() -> void:
	DisplayServer.window_set_title("Endless Ward - Sprite Lab")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := VBoxContainer.new()
	ui.position = Vector2(70, 42)
	ui.size = Vector2(1780, 190)
	ui.add_theme_constant_override("separation", 13)
	canvas.add_child(ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Arial"])
	var title := Label.new()
	title.text = "SPRITE LAB  /  스프라이트 작업실"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 35)
	ui.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	ui.add_child(row)
	path_input = LineEdit.new()
	path_input.text = initial_pack
	path_input.custom_minimum_size = Vector2(1030, 50)
	path_input.add_theme_font_size_override("font_size", 21)
	row.add_child(path_input)
	var load_button := Button.new()
	load_button.text = "팩 불러오기"
	load_button.add_theme_font_override("font", font)
	load_button.pressed.connect(func() -> void: load_pack(path_input.text))
	row.add_child(load_button)
	state_picker = OptionButton.new()
	state_picker.custom_minimum_size = Vector2(280, 50)
	state_picker.item_selected.connect(select_state)
	row.add_child(state_picker)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 24)
	ui.add_child(options)
	var pause_button := Button.new()
	pause_button.text = "재생 / 정지  [SPACE]"
	pause_button.add_theme_font_override("font", font)
	pause_button.pressed.connect(toggle_play)
	options.add_child(pause_button)
	var scale_label := Label.new()
	scale_label.text = "확대"
	scale_label.add_theme_font_override("font", font)
	options.add_child(scale_label)
	var zoom := HSlider.new()
	zoom.custom_minimum_size = Vector2(350, 35)
	zoom.min_value = 0.5
	zoom.max_value = 3.0
	zoom.step = 0.1
	zoom.value = 2.0
	zoom.value_changed.connect(func(value: float) -> void: actor.scale = Vector2.ONE * value)
	options.add_child(zoom)
	var bg := OptionButton.new()
	bg.add_theme_font_override("font", font)
	for name_text in ["투명도 체커", "밝은 배경", "어두운 배경"]:
		bg.add_item(name_text)
	bg.item_selected.connect(func(index: int) -> void:
		background_mode = index
		queue_redraw())
	options.add_child(bg)
	detail = Label.new()
	detail.position = Vector2(70, 960)
	detail.add_theme_font_override("font", font)
	detail.add_theme_font_size_override("font_size", 23)
	canvas.add_child(detail)
	status_label = Label.new()
	status_label.position = Vector2(70, 1007)
	status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.modulate = Color("91d0bc")
	canvas.add_child(status_label)
	actor = AnimatedSprite2D.new()
	actor.position = Vector2(960, 585)
	actor.scale = Vector2.ONE * 2
	add_child(actor)
	load_pack(path_input.text)
	queue_redraw()

func load_pack(path: String) -> void:
	if not path.begins_with("res://assets/sprites/") or not path.ends_with("/sprites.tres") or ".." in path:
		status_label.text = "assets/sprites/<팩 이름>/sprites.tres 경로를 지정하세요."
		return
	if not ResourceLoader.exists(path):
		status_label.text = "팩이 없습니다. 먼저 sprite-tool.cmd demo 또는 publish를 실행하세요."
		return
	var resource = load(path)
	if not resource is SpriteFrames:
		status_label.text = "SpriteFrames 리소스가 아닙니다."
		return
	frames = resource.duplicate(true)
	actor.sprite_frames = frames
	state_picker.clear()
	for animation in frames.get_animation_names():
		state_picker.add_item(animation)
	select_state(0)
	var qa_path := path.get_base_dir().path_join("qa-review.json")
	var qa: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(qa_path)) if FileAccess.file_exists(qa_path) else {}
	if qa.get("mode", "") == "static-reference":
		status_label.text = "정적 참조 데모: 방향별 1장. 걷기·공격 애니메이션을 생성하거나 검증한 결과가 아닙니다."
	else:
		status_label.text = "모션 검수 상태: %s  /  방향·발 접지·루프 연결·총구 방향을 재생하며 확인하세요." % qa.get("status", "unknown")
	print("SPRITE_PREVIEW_READY | animations=", frames.get_animation_names())

func select_state(index: int) -> void:
	if frames == null or index < 0 or index >= state_picker.item_count:
		return
	var name_text := state_picker.get_item_text(index)
	actor.play(name_text)
	if not playing:
		actor.pause()
	detail.text = "%s   |   %d frames   |   %.1f FPS   |   loop: %s   |   ← → 상태 변경" % [name_text, frames.get_frame_count(name_text), frames.get_animation_speed(name_text), frames.get_animation_loop(name_text)]

func toggle_play() -> void:
	playing = not playing
	if playing:
		actor.play()
	else:
		actor.pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			toggle_play()
		elif event.physical_keycode in [KEY_LEFT, KEY_RIGHT] and state_picker.item_count > 0:
			var delta := 1 if event.physical_keycode == KEY_RIGHT else -1
			var index := posmod(state_picker.selected + delta, state_picker.item_count)
			state_picker.select(index)
			select_state(index)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("101e25"))
	var board := Rect2(450, 247, 1020, 660)
	draw_rect(board.grow(2), Color("52776c"))
	if background_mode == 0:
		for y in range(22):
			for x in range(34):
				draw_rect(Rect2(board.position + Vector2(x, y) * 30, Vector2(30, 30)), Color("a9b5b4") if (x + y) % 2 == 0 else Color("cbd3ce"))
	else:
		draw_rect(board, Color("eff3e9") if background_mode == 1 else Color("14222a"))
	draw_line(Vector2(450, 809), Vector2(1470, 809), Color(0.27, 0.75, 0.61, 0.8), 2)
