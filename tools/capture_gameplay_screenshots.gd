extends SceneTree
## Captures real in-game screenshots for the pixel-style batches.
## Run windowed (NOT headless — the dummy renderer cannot produce pixels):
##   Godot --path . --script res://tools/capture_gameplay_screenshots.gd
## Loads the game scene directly (it starts a run on _ready), holds the fire
## button for action, and saves two frames into mockups_v6/.

const OUT_DIR := "res://mockups_v6"

var _frames := 0
var _scene: Node
var _shots := {
	200: "implemented_wave_early.png",
	720: "implemented_wave_mid.png",
	1440: "implemented_wave_late.png",
}


func _initialize() -> void:
	_scene = load("res://scenes/game.tscn").instantiate()
	root.add_child(_scene)
	# The spawners add enemies to current_scene; --script runs must set it.
	current_scene = _scene
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	# Hold fire from the second second onward so the bolts are on screen.
	if _frames == 60:
		Input.action_press("shoot")
		# Optional: enable elite upgrades passed as user args, e.g.
		#   --script res://tools/capture_gameplay_screenshots.gd -- twin_cannons
		var player := current_scene.get_node_or_null("Player")
		if player != null and player.has_method("set_elite_upgrade_enabled"):
			for upgrade_id in OS.get_cmdline_user_args():
				player.set_elite_upgrade_enabled(upgrade_id, true, false)
	if _shots.has(_frames):
		_capture(_shots[_frames])
	if _frames >= 1450:
		quit()


func _capture(filename: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, filename]
	var error := image.save_png(path)
	print("capture ", path, " -> ", "ok" if error == OK else error)
