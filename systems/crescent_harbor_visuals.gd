extends Node3D
## Presents the complete authored harbor as one synchronized, manually driven loop.
## Source clips/materials stay shared and unchanged; only the merged clip is private.

const MODEL_PATH := "res://assets/models/wayfarer_crescent/meshes/wayfarer_crescent.glb"
const LOOP_SECONDS := 20.0
const RUNTIME_CLIP := &"harbor_runtime"
const EXPECTED_SOURCE_CLIPS := 16

var model: Node3D
var animation_player: AnimationPlayer
var source_animation_player: AnimationPlayer
var shadow_optimization_counts := {"cable_meshes": 0, "exhaust_meshes": 0}
var _source_clip_names := PackedStringArray()
var _phase := 0.0


func load_harbor() -> Node3D:
	if is_instance_valid(model):
		return model
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Crescent Harbor model could not be loaded.")
		return null
	model = packed.instantiate() as Node3D
	if model == null:
		push_error("Crescent Harbor needs a Node3D model root.")
		return null
	model.name = "CrescentHarbor"
	add_child(model)
	_configure_shadows()
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		return _fail_load("Crescent Harbor requires one imported animation library.")
	source_animation_player = players[0] as AnimationPlayer
	# Godot inserts one-key rest tracks for every other animation channel into
	# each clip. Playing the sixteen clips independently would reset one another.
	source_animation_player.stop()
	source_animation_player.active = false
	source_animation_player.process_mode = Node.PROCESS_MODE_DISABLED
	var combined := _combine_clips()
	if combined == null:
		return _fail_load("Crescent Harbor animation channels could not be combined safely.")
	var library := AnimationLibrary.new()
	library.add_animation(RUNTIME_CLIP, combined)
	animation_player = AnimationPlayer.new()
	animation_player.name = "HarborMotion"
	model.add_child(animation_player)
	animation_player.root_node = animation_player.get_path_to(source_animation_player.get_node(source_animation_player.root_node))
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_player.add_animation_library(&"", library)
	animation_player.play(RUNTIME_CLIP)
	seek(0.0)
	return model


func advance(delta: float, reduced_motion: bool = false) -> void:
	if animation_player == null or reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	if is_inside_tree() and get_tree().paused:
		return
	_phase = fposmod(_phase + delta, LOOP_SECONDS)
	animation_player.advance(delta)


func seek(seconds: float) -> void:
	if animation_player == null or not is_finite(seconds):
		return
	_phase = fposmod(seconds, LOOP_SECONDS)
	animation_player.seek(_phase, true)


func get_source_clip_names() -> PackedStringArray:
	return _source_clip_names.duplicate()


func get_active_clip_names() -> PackedStringArray:
	return get_source_clip_names() if animation_player != null else PackedStringArray()


func get_authored_roots() -> Dictionary:
	var roots := {}
	if model == null:
		return roots
	for node in model.find_children("*", "Node3D", true, false):
		var node_name := str(node.name)
		if node_name == "Wayfarer_Core" or node_name.begins_with("Relay_") and node.get_parent() == model:
			roots[node_name] = node
		elif node_name.begins_with("PowerBundle_") and node.get_parent() == model:
			roots[node_name] = node
		elif node_name.begins_with("Ship_"):
			# Fleet roots are plain Node3D containers. Mesh/scanner children keep
			# the Ship_ prefix too, but must not be reported as additional craft.
			if node.get_class() == "Node3D" and not str(node.get_parent().name).begins_with("Ship_"):
				roots[node_name] = node
	return roots


func _configure_shadows() -> void:
	# The suspended cables sit below the occupied decks: their long-range
	# shadows fall into empty space. Keep station and spacecraft hull shadows.
	for assembly in model.get_children():
		if not str(assembly.name).begins_with("PowerBundle_"):
			continue
		for mesh: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shadow_optimization_counts.cable_meshes += 1
	# Emissive correction plumes are light, not opaque structural geometry.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).contains("correction exhaust"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shadow_optimization_counts.exhaust_meshes += 1


func _combine_clips() -> Animation:
	var selected := {}
	_source_clip_names.clear()
	var source_length := 0.0
	for clip_name in source_animation_player.get_animation_list():
		if clip_name == &"RESET":
			continue
		var clip := source_animation_player.get_animation(clip_name)
		if source_length > 0.0 and not is_equal_approx(source_length, clip.length):
			push_error("Crescent Harbor source clips must share one timeline.")
			return null
		source_length = clip.length
		_source_clip_names.append(clip_name)
		for track in clip.get_track_count():
			var count := clip.track_get_key_count(track)
			if count == 0:
				continue
			var kind := clip.track_get_type(track)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				push_error("Crescent Harbor contains an unexpected non-transform animation track.")
				return null
			var key := "%s:%d" % [clip.track_get_path(track), kind]
			if selected.has(key):
				var previous: Dictionary = selected[key]
				if count > 1 and int(previous.count) > 1:
					push_error("Crescent Harbor clips both animate the same property: " + key)
					return null
				if count <= int(previous.count):
					continue
			selected[key] = {"clip": clip, "track": track, "count": count}
	if _source_clip_names.size() != EXPECTED_SOURCE_CLIPS or source_length <= 0.0:
		push_error("Crescent Harbor is missing one or more of its sixteen authored clips.")
		return null
	var combined := Animation.new()
	combined.resource_name = "Crescent Harbor / synchronized authored motion"
	combined.length = LOOP_SECONDS
	combined.loop_mode = Animation.LOOP_LINEAR
	var time_scale := LOOP_SECONDS / source_length
	for entry: Dictionary in selected.values():
		var source: Animation = entry.clip
		source.copy_track(int(entry.track), combined)
		var track := combined.get_track_count() - 1
		# Keep all imported samples, including the closing pose. Scaling the
		# timeline avoids cutting the last 1/24 s from the glTF frame-one offset.
		for key in combined.track_get_key_count(track):
			combined.track_set_key_time(track, key, combined.track_get_key_time(track, key) * time_scale)
	return combined


func _fail_load(message: String) -> Node3D:
	push_error(message)
	remove_child(model)
	model.queue_free()
	model = null
	source_animation_player = null
	_source_clip_names.clear()
	return null
