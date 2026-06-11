extends BaseEnemy
## Basic enemy — moves straight down, 1 HP.

## Sets base stats for the basic enemy type (1 HP, standard speed, 100 points)
## and delegates to the parent _ready() for shared setup.
func _ready() -> void:
	max_health = 1
	speed = 150.0
	points = 100
	super._ready()
