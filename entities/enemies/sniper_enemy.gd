extends BaseEnemy
## Ranged enemy that establishes a firing lane before retreating off screen.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")

var entry_distance: float = 0.0
var hold_position: Vector2 = Vector2.ZERO
var hold_timer: float = 0.0
var shoot_timer: float = 0.0
var holding: bool = false
var has_withdrawn: bool = false

## Sets stats for the sniper enemy (3 HP, moderate speed, 260 points,
## guaranteed 2-value orb) and randomizes the first shot delay.
func _ready() -> void:
	max_health = 3
	speed = 145.0
	points = 260
	orb_value = 2
	guaranteed_orb = true
	super._ready()
	shoot_timer = randf_range(0.6, 1.2)

## Three-phase movement: enters the screen along spawn_direction until it
## reaches 115px depth, then holds position while oscillating perpendicular
## and firing aimed shots at the player every 1.55s. After 6 seconds of
## holding, withdraws at high speed along its original travel direction.
func _move(delta: float) -> void:
	if not holding:
		var movement_speed := 210.0 if has_withdrawn else speed
		var movement := spawn_direction * movement_speed * GameManager.enemy_speed_multiplier * delta
		position += movement
		entry_distance += movement.length()
		if not has_withdrawn and entry_distance >= 115.0:
			holding = true
			hold_position = position
		return
	else:
		hold_timer += delta
		var perpendicular := Vector2(-spawn_direction.y, spawn_direction.x)
		position = hold_position + perpendicular * sin(hold_timer * 1.8) * 54.0
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			shoot_timer = 1.55
			_fire_aimed_shot()
		if hold_timer >= 6.0:
			holding = false
			has_withdrawn = true

## Fires a single high-speed bullet aimed directly at the player's
## current position. The bullet is colored neon cyan for visibility.
func _fire_aimed_shot() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	var direction := (player.global_position - global_position).normalized()
	var bullet: Area2D = ENEMY_BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.add_to_group("enemy_bullets")
	bullet.set_meta("direction", direction)
	bullet.set_meta("custom_speed", randf_range(430.0, 500.0))
	bullet.set_meta("bullet_color", Color(0.2, 1.8, 2.8, 1.0))
	get_tree().current_scene.add_child(bullet)
