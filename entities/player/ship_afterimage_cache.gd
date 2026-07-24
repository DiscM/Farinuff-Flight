extends Node
class_name ShipAfterimageCache
## Bakes the base ship and installed hardware into a four-frame texture strip.
##
## The temporary SubViewport exists only while an upgrade-set rebuild is in
## flight. Boost ghosts consume the resulting texture as ordinary Sprite2Ds.

var texture: Texture2D
var _rebuild_generation := 0
var _rebuild_scheduled := false
var _pending_source: Texture2D
var _pending_upgrades: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func rebuild(source_texture: Texture2D, upgrade_ids: Array[String]) -> void:
	_rebuild_generation += 1
	texture = null
	_pending_source = source_texture
	_pending_upgrades = upgrade_ids.duplicate()
	if not _rebuild_scheduled:
		_rebuild_scheduled = true
		call_deferred("_start_pending_bake")


func invalidate() -> void:
	_rebuild_generation += 1
	texture = null
	_pending_source = null
	_pending_upgrades.clear()


func _start_pending_bake() -> void:
	_rebuild_scheduled = false
	_bake(_pending_source, _pending_upgrades.duplicate(), _rebuild_generation)


func _bake(source_texture: Texture2D, upgrade_ids: Array[String], generation: int) -> void:
	if source_texture == null:
		return

	var viewport := SubViewport.new()
	viewport.name = "TemporaryAfterimageBaker"
	viewport.size = Vector2i(512, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	for frame in range(4):
		var composite := ShipAfterimage.new()
		composite.position = Vector2(64.0 + frame * 128.0, 64.0)
		composite.configure(source_texture, frame, upgrade_ids)
		viewport.add_child(composite)

	await get_tree().process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if DisplayServer.get_name() == "headless":
		viewport.queue_free()
		return
	await RenderingServer.frame_post_draw

	if generation == _rebuild_generation and is_instance_valid(viewport):
		var baked_image := viewport.get_texture().get_image()
		if baked_image != null and not baked_image.is_empty():
			texture = ImageTexture.create_from_image(baked_image)
	viewport.queue_free()
