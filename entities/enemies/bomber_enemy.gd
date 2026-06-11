extends BaseEnemy
## Bomber enemy — drifts perpendicular to its travel direction, drops bombs periodically.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var drift_speed: float = 120.0
var drift_dir: float = 1.0
var drop_interval: float = 2.0
var drop_timer: float = 0.0
var viewport_size: Vector2 = Vector2(720.0, 1024.0)

## Sets stats for the bomber (2 HP, slow speed, 200 points, guaranteed orb),
## randomizes which perpendicular direction it drifts initially, and
## staggers the first bomb drop timer.
func _ready() -> void:
	max_health = 2
	speed = 60.0
	points = 200
	orb_value = 2
	guaranteed_orb = true
	super._ready()
	viewport_size = get_viewport_rect().size
	drift_dir = [-1.0, 1.0].pick_random()
	drop_timer = randf_range(0.5, drop_interval)

## Moves the bomber slowly along its travel direction while drifting
## sideways perpendicular to it. Bounces off screen edges to stay visible.
## Decrements the drop timer and calls _drop_bomb() when it reaches zero.
func _move(delta: float) -> void:
	# Slow drift along travel direction
	position += spawn_direction * speed * GameManager.enemy_speed_multiplier * delta

	# Drift perpendicular to travel direction and bounce off screen edges
	var perp := Vector2(-spawn_direction.y, spawn_direction.x)
	position += perp * drift_speed * drift_dir * delta

	# Bounce: clamp to screen bounds on both axes
	if position.x < 30:
		drift_dir = 1.0 if perp.x != 0 else drift_dir
		position.x = 30
	elif position.x > viewport_size.x - 30:
		drift_dir = -1.0 if perp.x != 0 else drift_dir
		position.x = viewport_size.x - 30

	if position.y < 30:
		drift_dir = 1.0 if perp.y != 0 else drift_dir
		position.y = 30
	elif position.y > viewport_size.y - 30:
		drift_dir = -1.0 if perp.y != 0 else drift_dir
		position.y = viewport_size.y - 30

	# Drop bombs
	drop_timer -= delta
	if drop_timer <= 0:
		drop_timer = drop_interval
		_drop_bomb()

## Spawns a neon-green enemy bullet below the bomber's current position,
## traveling downward at a randomized speed.
func _drop_bomb() -> void:
	var bomb: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bomb.global_position = global_position + Vector2(0, 16)
	bomb.add_to_group("enemy_bullets")
	bomb.set_meta("custom_speed", randf_range(300.0, 400.0))
	bomb.set_meta("bullet_color", Color(0.2, 3.0, 0.2, 1.0)) # High contrast neon green
	get_tree().current_scene.add_child(bomb)
