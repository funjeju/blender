extends SceneTree
func _initialize() -> void:
	var script = load("res://scripts/hospital_world.gd")
	for path in ["res://assets/characters_atlas.png", "res://assets/hospital_atlas.png"]:
		var tex = load(path)
		print(path, " size=", tex.get_size(), " fmt=", tex.get_image().get_format())
		for i in range(4):
			var cell = script.atlas_cell(tex, i)
			print("  cell ", i, " region=", cell.region)
	quit()
