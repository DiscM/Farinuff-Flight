extends Node2D
class_name DroneVisual
## Small procedural escort craft matching the player's flat polygon style.


func _draw() -> void:
	ShipUpgradeVisuals.draw_drone(self)
