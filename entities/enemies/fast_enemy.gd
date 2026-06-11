extends BaseEnemy
## Fast enemy — quick & agile, slight sine wave movement.

var time_alive: float = 0.0
var wave_amplitude: float = 80.0
var wave_frequency: float = 3.0
var start_pos: Vector2 = Vector2.ZERO

## Sets stats for the fast enemy (1 HP, high speed, 150 points) and
## records the spawn position for sine wave offset calculations.
func _ready() -> void:
	max_health = 1
	speed = 280.0
	points = 150
	super._ready()
	start_pos = position

## Moves the enemy along its spawn direction at high speed while oscillating
## perpendicular to that direction in a sine wave pattern, creating a weaving
## flight path that makes it harder to hit.
func _move(delta: float) -> void:
	time_alive += delta
	# Advance along travel direction
	position += spawn_direction * speed * GameManager.enemy_speed_multiplier * delta
	# Oscillate perpendicular to travel direction (sine wave stays centred on the entry path)
	var perp := Vector2(-spawn_direction.y, spawn_direction.x)
	var along := spawn_direction.dot(position - start_pos)
	var base_pos := start_pos + spawn_direction * along
	position = base_pos + perp * sin(time_alive * wave_frequency) * wave_amplitude
