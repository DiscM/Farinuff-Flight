extends FastEnemy3D
var field_objective := true
var _courier_label: Label3D
func _configure_movement() -> void:
	_speed_pixels = 85.0
	velocity = _flight_space.screen_motion_to_combat(_flight_space.combat_motion_to_screen(_heading).normalized() * _speed_pixels)
	phase_warning.hide()
	if _courier_label == null:
		_courier_label = Label3D.new()
		_courier_label.text = "◇ COURIER"
		_courier_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_courier_label.position.y = 1.2
		_courier_label.pixel_size = 0.015
		_courier_label.font_size = 30
		_courier_label.modulate = Color(1.0, 0.85, 0.25)
		add_child(_courier_label)
func _advance_movement(delta: float) -> void:
	global_position += velocity * delta
func should_drop_xp_orb() -> bool:
	return false
