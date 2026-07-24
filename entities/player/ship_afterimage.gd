extends Node2D
class_name ShipAfterimage
## One-canvas-item ghost of the base ship and all installed ship hardware.

var _texture: Texture2D
var _frame := 0
var _upgrades: Array[String] = []


func configure(texture: Texture2D, frame: int, upgrade_ids: Array[String]) -> void:
	_texture = texture
	_frame = frame
	_upgrades.clear()
	for id in upgrade_ids:
		if id != "drone_escort" and not _upgrades.has(id):
			_upgrades.append(id)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var frame_index := clampi(_frame, 0, 3)
	var frame_offset := Vector2(0.0, ShipUpgradeVisuals.FRAME_BOB[frame_index])
	var frame_rotation := deg_to_rad(ShipUpgradeVisuals.FRAME_ROLL[frame_index])
	draw_set_transform(frame_offset, frame_rotation)
	ShipUpgradeVisuals.draw_upgrade_layer(
		self,
		_upgrades,
		ShipUpgradeVisuals.VisualLayer.BACK,
		{"omit_transients": true}
	)
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(
		_texture,
		Rect2(-64, -64, 128, 128),
		Rect2(float(_frame * 128), 0, 128, 128)
	)
	draw_set_transform(frame_offset, frame_rotation)
	ShipUpgradeVisuals.draw_upgrade_layer(
		self,
		_upgrades,
		ShipUpgradeVisuals.VisualLayer.FRONT,
		{"omit_transients": true}
	)
	draw_set_transform(Vector2.ZERO)
