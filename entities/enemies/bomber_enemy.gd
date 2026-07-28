extends BaseEnemy
## Bomber enemy — drifts perpendicular to its travel direction, drops bombs periodically.

const ENEMY_MINE_SCENE := preload("res://entities/enemies/enemy_mine.tscn")

var drift_speed: float = 120.0
var drift_dir: float = 1.0
var drop_interval: float = 2.0
var drop_timer: float = 0.0
# Overwritten in _ready with the live viewport size; the default only guards
# against reads before _ready and matches the 360x720 design viewport.
var viewport_size: Vector2 = Vector2(360.0, 720.0)
var mine_timer := 5.0
var mine_count := 0

## Sets stats for the bomber (2 HP, slow speed, 200 points, guaranteed orb),
## randomizes which perpendicular direction it drifts initially, and
## staggers the first bomb drop timer.
func _ready() -> void:
	archetype_id = &"bomber"
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
	position += spawn_direction * speed * delta

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
	if generation >= 2:
		mine_timer -= delta
		if mine_timer <= 0.0 and can_begin_special():
			mine_timer = 5.0
			_try_drop_mine()

## Spawns a neon-green enemy bullet below the bomber's current position,
## traveling downward at a randomized speed.
func _drop_bomb() -> void:
	fire_enemy_bullet(get_origin(&"Bay"), spawn_direction, randf_range(300.0, 400.0), Color(2.6, 0.25, 0.7, 1.0))


func _try_drop_mine() -> void:
	var cluster := generation >= 3 and (mine_count + 1) % 3 == 0
	if not special_attack_coordinator.request_hazard(&"mine"):
		return
	if cluster and not special_attack_coordinator.request_hazard(&"cluster_mine"):
		special_attack_coordinator.release_hazard(&"mine")
		return
	var scene_root := get_tree().current_scene
	var mine = ObjectPool.acquire(ENEMY_MINE_SCENE, scene_root)
	if mine == null:
		special_attack_coordinator.release_hazard(&"mine")
		if cluster:
			special_attack_coordinator.release_hazard(&"cluster_mine")
		return
	mine_count += 1
	mine.pool_activate(get_origin(&"Bay"), cluster, generation >= 4 and cluster, special_attack_coordinator)


func dev_trigger_ability() -> void:
	mine_timer = 0.0
	visible_time = 1.0
