extends BaseEnemy
## Fast enemy — quick & agile, slight sine wave movement.

var time_alive: float = 0.0
var wave_amplitude: float = 80.0
var wave_frequency: float = 3.0
var start_x: float = 0.0

func _ready() -> void:
	max_health = 1
	speed = 280.0
	points = 150
	super._ready()
	start_x = position.x

func _move(delta: float) -> void:
	time_alive += delta
	position.y += speed * GameManager.enemy_speed_multiplier * delta
	position.x = start_x + sin(time_alive * wave_frequency) * wave_amplitude
