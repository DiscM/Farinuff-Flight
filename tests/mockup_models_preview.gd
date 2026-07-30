extends Node3D
## Lightweight showroom motion for the generated GLB mockup fleet.


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--mockup-capture"):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		var output_path := ProjectSettings.globalize_path(
			"res://assets/models/mockups/previews/godot_fleet_showroom.png"
		)
		var error := capture.save_png(output_path)
		if error != OK:
			push_error("Could not save mockup showroom capture: %s" % error_string(error))
			get_tree().quit(1)
			return
		print("CODEX_MOCKUP_CAPTURE_PASS: %s" % output_path)
		get_tree().quit()
		return
	if not OS.get_cmdline_user_args().has("--mockup-smoke"):
		return
	var expected_sockets := {
		"Player": 7,
		"Basic": 3,
		"Fast": 3,
		"Bomber": 5,
		"Tank": 5,
		"Sniper": 4,
	}
	for model_root in $Fleet.get_children():
		var mesh_count := _count_type(model_root, MeshInstance3D)
		var socket_count := _count_sockets(model_root)
		var expected: int = expected_sockets.get(model_root.name, -1)
		if mesh_count < 1 or socket_count != expected:
			push_error(
				"Mockup validation failed for %s: %d meshes, %d/%d sockets"
				% [model_root.name, mesh_count, socket_count, expected]
			)
			get_tree().quit(1)
			return
	print("CODEX_MOCKUP_MODELS_PASS: 6 GLB scenes imported with meshes and sockets")
	get_tree().quit()


func _process(delta: float) -> void:
	for child in $Fleet.get_children():
		if child is Node3D:
			child.rotation.y += delta * 0.22
			child.position.y = sin(Time.get_ticks_msec() * 0.0015 + child.get_index()) * 0.08


func _count_type(root: Node, node_type: Variant) -> int:
	var count := 1 if is_instance_of(root, node_type) else 0
	for child in root.get_children():
		count += _count_type(child, node_type)
	return count


func _count_sockets(root: Node) -> int:
	var count := 1 if root.name.begins_with("Socket_") else 0
	for child in root.get_children():
		count += _count_sockets(child)
	return count
