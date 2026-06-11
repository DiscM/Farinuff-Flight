extends BaseEnemy
## Tank enemy — slow, high HP, fires radial bullet bursts periodically.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5   # seconds between bursts
var bullet_count: int = 8         # bullets per burst, evenly spread 360°

## Sets stats for the tank enemy (15 HP, slow, 300 points, guaranteed 3-value orb)
## and randomizes the first shot timer so multiple tanks don't fire simultaneously.
func _ready() -> void:
	max_health = 15
	speed = 80.0
	points = 300
	orb_value = 3  # High-value Tank orb
	guaranteed_orb = true
	super._ready()
	# Stagger first shot so not all tanks fire at once
	shoot_timer = randf_range(0.5, shoot_interval)

## Moves using the base straight-line movement, then decrements the shoot
## timer and fires a radial burst when it reaches zero.
func _move(delta: float) -> void:
	super._move(delta)
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_fire_radial_burst()

## Fires a 360° burst of enemy bullets evenly spaced around the tank.
## Alternates speed between even and odd bullets for visual variety, and
## colors them neon purple for high contrast against the background.
func _fire_radial_burst() -> void:
	for i in range(bullet_count):
		var angle := (TAU / bullet_count) * i
		var dir := Vector2(sin(angle), cos(angle))
		var shot_speed := (245.0 if i % 2 == 0 else 305.0) + randf_range(-8.0, 8.0)
		var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
		bullet.global_position = global_position
		bullet.add_to_group("enemy_bullets")
		# Override speed direction — enemy_bullet.gd moves via position.y,
		# so we drive it manually with a script override via metadata
		bullet.set_meta("direction", dir)
		bullet.set_meta("custom_speed", shot_speed)
		bullet.set_meta("bullet_color", Color(2.0, 0.2, 3.0, 1.0)) # High contrast neon purple
		get_tree().current_scene.add_child(bullet)

