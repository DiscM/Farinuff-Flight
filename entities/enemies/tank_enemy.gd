extends BaseEnemy
## Tank enemy — slow, high HP, fires radial bullet bursts periodically.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5   # seconds between bursts
var bullet_count: int = 8         # bullets per burst, evenly spread 360°

func _ready() -> void:
	max_health = 15
	speed = 80.0
	points = 300
	orb_value = 3  # High-value Tank orb
	guaranteed_orb = true
	super._ready()
	# Stagger first shot so not all tanks fire at once
	shoot_timer = randf_range(0.5, shoot_interval)

func _move(delta: float) -> void:
	super._move(delta)
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_fire_radial_burst()

func _fire_radial_burst() -> void:
	for i in range(bullet_count):
		var angle := (TAU / bullet_count) * i
		var dir := Vector2(sin(angle), cos(angle))
		var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position
		bullet.add_to_group("enemy_bullets")
		# Override speed direction — enemy_bullet.gd moves via position.y,
		# so we drive it manually with a script override via metadata
		bullet.set_meta("direction", dir)
		bullet.set_meta("custom_speed", 280.0)
		bullet.set_meta("bullet_color", Color(2.0, 0.2, 3.0, 1.0)) # High contrast neon purple
		get_tree().current_scene.add_child(bullet)

