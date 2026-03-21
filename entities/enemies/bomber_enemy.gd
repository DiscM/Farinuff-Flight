extends BaseEnemy
## Bomber enemy — moves horizontally, drops bombs periodically.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var horizontal_speed: float = 120.0
var horizontal_dir: float = 1.0
var drop_interval: float = 2.0
var drop_timer: float = 0.0
var viewport_width: float = 720.0

func _ready() -> void:
	max_health = 2
	speed = 60.0
	points = 200
	super._ready()
	viewport_width = get_viewport_rect().size.x
	horizontal_dir = [-1.0, 1.0].pick_random()
	drop_timer = randf_range(0.5, drop_interval)

func _move(delta: float) -> void:
	# Slow downward drift + horizontal movement
	position.y += speed * GameManager.enemy_speed_multiplier * delta
	position.x += horizontal_speed * horizontal_dir * delta

	# Bounce off edges
	if position.x < 30:
		horizontal_dir = 1.0
	elif position.x > viewport_width - 30:
		horizontal_dir = -1.0

	# Drop bombs
	drop_timer -= delta
	if drop_timer <= 0:
		drop_timer = drop_interval
		_drop_bomb()

func _drop_bomb() -> void:
	var bomb: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bomb.global_position = global_position + Vector2(0, 16)
	bomb.add_to_group("enemy_bullets")
	bomb.set_meta("bullet_color", Color(0.2, 3.0, 0.2, 1.0)) # High contrast neon green
	get_tree().current_scene.add_child(bomb)
