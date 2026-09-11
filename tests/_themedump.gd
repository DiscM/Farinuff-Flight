extends Node
func _ready() -> void:
	var t := Theme.new()
	t.add_color(&"CYAN", "", Color(0.17, 0.95, 1.0))
	t.add_constant(&"metadata_font_size", "Label", 14)
	t.add_font_size(&"font_size", "Label", 16)
	t.add_color(&"font_color", "Label", Color(0.9, 0.98, 1.0))
	var err := ResourceSaver.save(t, "user://_theme_probe.tres")
	print("saved probe err=", err)
	get_tree().quit(0)
