extends BaseEnemy
## Basic enemy — moves straight down, 1 HP.

func _ready() -> void:
	max_health = 1
	speed = 150.0
	points = 100
	super._ready()
