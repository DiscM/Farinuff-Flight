extends Control
class_name ShipUpgradePreview
## Compact popup preview of the current ship plus one highlighted candidate.

const SHIP_TEXTURE := preload("res://assets/sprites/generated/player_idle_strip.png")

var _current_upgrades: Array[String] = []
var _candidate_id := ""


func configure(current_upgrades: Array[String], candidate_id: String) -> void:
	_current_upgrades.clear()
	for id in current_upgrades:
		if not _current_upgrades.has(id):
			_current_upgrades.append(id)
	_candidate_id = candidate_id
	custom_minimum_size = Vector2(0, 66)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var upgrades := _current_upgrades.duplicate()
	if not upgrades.has(_candidate_id):
		upgrades.append(_candidate_id)

	var preview_scale := 0.48
	var center := Vector2(size.x * 0.5, size.y * 0.54)
	draw_set_transform(center, 0.0, Vector2.ONE * preview_scale)
	ShipUpgradeVisuals.draw_upgrade_layer(
		self,
		upgrades,
		ShipUpgradeVisuals.VisualLayer.BACK,
		{},
		_candidate_id,
		true
	)
	draw_texture_rect_region(
		SHIP_TEXTURE,
		Rect2(-64, -64, 128, 128),
		Rect2(0, 0, 128, 128),
		Color(0.62, 0.66, 0.75, 0.72)
	)
	ShipUpgradeVisuals.draw_upgrade_layer(
		self,
		upgrades,
		ShipUpgradeVisuals.VisualLayer.FRONT,
		{},
		_candidate_id,
		true
	)
	if upgrades.has("drone_escort"):
		var drone_alpha := 1.0 if _candidate_id == "drone_escort" else 0.30
		ShipUpgradeVisuals.draw_drone_preview(
			self,
			drone_alpha,
			_candidate_id == "drone_escort"
		)
	draw_set_transform(Vector2.ZERO)
