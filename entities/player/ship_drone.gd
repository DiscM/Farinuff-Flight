extends Area2D
class_name ShipDrone
## Combat drone granted by the drone_escort elite upgrade. Hovers beside the
## player and auto-fires at the nearest enemy. Self-contained: handles its
## own movement, fire cooldown, and contact damage — the player only spawns
## and frees it.

const DRONE_VISUAL_SCRIPT := preload("res://entities/player/drone_visual.gd")
const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

## Seconds between drone shots.
const FIRE_RATE := 0.65
## Hover position relative to the player.
const HOVER_OFFSET := Vector2(50, -20)

# Untyped so the drone can duck-type against the player script (which has no
# class_name) for is_piercing_active().
var _player = null
var _shoot_timer: float = 0.0

## Configures the drone for the given player: visual, collision, groups,
## and contact damage handler. Call once, before adding to the scene tree.
func setup(owner_player: Node2D) -> void:
	_player = owner_player
	collision_layer = 4   # player_bullets
	collision_mask = 2    # enemies
	add_to_group("player_orbitals")
	add_to_group("drone_escort")
	var visual := DRONE_VISUAL_SCRIPT.new() as DroneVisual
	visual.name = "DroneVisual"
	add_child(visual)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var circ := CircleShape2D.new()
	circ.radius = 7.0
	col.shape = circ
	add_child(col)
	area_entered.connect(_on_area_entered)
	global_position = _player.global_position + HOVER_OFFSET

## Follows the authored offset beside the player and auto-fires on a cooldown.
## Positional smoothing remains gameplay-authoritative for collision and shots;
## the former cosmetic roll animation has been removed.
func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	var target_pos: Vector2 = _player.global_position + HOVER_OFFSET
	global_position = global_position.lerp(target_pos, delta * 6.0)
	rotation = 0.0
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = FIRE_RATE
		_fire()

## Fires a single bullet at the nearest enemy, falling back to straight up
## when no enemies are present. Inherits the player's piercing modifier.
func _fire() -> void:
	var dir := _nearest_enemy_direction(global_position)
	if dir.is_zero_approx():
		dir = Vector2.UP
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bullet = ObjectPool.acquire(BULLET_SCENE, scene_root)
	if bullet == null:
		return
	bullet.pool_activate(global_position, dir, 1.0, _player.is_piercing_active())

## Contact damage: deals 1 + bonus damage to enemies and tempest sections.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		area.take_damage(1 + GameManager.bonus_damage)

## Returns the normalized direction to the nearest live enemy, or ZERO.
func _nearest_enemy_direction(origin: Vector2) -> Vector2:
	var best: Node2D = null
	var best_dist := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var d: float = origin.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best = e
	if best != null:
		return (best.global_position - origin).normalized()
	return Vector2.ZERO
