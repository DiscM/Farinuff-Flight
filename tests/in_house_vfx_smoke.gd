extends Node
## Headless regression coverage for the original procedural combat VFX.
##
## Run with:
## godot --headless --path . res://tests/in_house_vfx_smoke.tscn

const EXPLOSION_SCENE := preload("res://effects/explosion.tscn")
const FEEDBACK_SCENE := preload("res://effects/pixel_sprite_effect.tscn")

const OWNED_VFX_FILES := [
	"res://effects/explosion.gd",
	"res://effects/pixel_sprite_effect.gd",
]
const FORBIDDEN_EXTERNAL_MARKERS := [
	"Super Pixel Effects",
]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_source_ownership()

	var explosion := EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	explosion.play_at(Vector2(90.0, 110.0), false)
	_expect(explosion.visible, "Explosion must become visible when played")
	_expect(
		explosion.get_node_or_null("ProceduralDebris") is CPUParticles2D,
		"Explosion must generate its own debris particles"
	)

	var feedback := FEEDBACK_SCENE.instantiate()
	add_child(feedback)
	feedback.play_warp_at(Vector2(180.0, 110.0), Vector2.UP)
	_expect(feedback.visible, "Boost warp must become visible when played")
	_expect(
		feedback.get_child_count() == 0,
		"Boost warp must not create a texture-backed Sprite2D"
	)

	await get_tree().process_frame
	await get_tree().process_frame

	for node in [explosion, feedback]:
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	if _failures.is_empty():
		print("PASS: in-house procedural combat VFX smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_source_ownership() -> void:
	for path in OWNED_VFX_FILES:
		_expect(FileAccess.file_exists(path), "Missing VFX source: %s" % path)
		if not FileAccess.file_exists(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		for marker in FORBIDDEN_EXTERNAL_MARKERS:
			_expect(
				source.find(marker) < 0,
				"%s still references borrowed VFX marker '%s'" % [path, marker]
			)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
