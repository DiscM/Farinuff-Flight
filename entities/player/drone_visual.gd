extends Node2D
class_name DroneVisual
## Small procedural escort craft matching the player's flat polygon style.

var _installation_progress := 1.0
var _installation_pulse := 0.0


func _draw() -> void:
	ShipUpgradeVisuals.draw_drone(
		self,
		Vector2.ZERO,
		1.0,
		_installation_progress,
		1.0 if _installation_progress < 1.0 else _installation_pulse
	)


func set_installation(progress: float, pulse: float = 0.0) -> void:
	_installation_progress = clampf(progress, 0.0, 1.0)
	_installation_pulse = clampf(pulse, 0.0, 1.0)
	queue_redraw()


func finish_installation() -> void:
	_installation_progress = 1.0
	_installation_pulse = 0.0
	queue_redraw()
