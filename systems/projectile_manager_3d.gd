extends Node
class_name ProjectileManager3D
## Scene-owned projectile policy around the shared ObjectPool.
## Damage routing belongs to the native gameplay controller; this manager owns
## bounded-pool acquisition, Interaction Range, and Enemy Projectile deflection.

signal explosion_requested(combat_position: Vector3, primary_target: Area3D)
signal projectile_fired(kind: int, combat_position: Vector3, direction: Vector3, speed_pixels: float)
signal player_projectile_hit(target: Area3D, combat_position: Vector3)
signal enemy_projectile_hit(target: Area3D, combat_position: Vector3)
signal enemy_projectile_deflected(projectile: Area3D, combat_position: Vector3)
signal deflected_projectile_hit(target: Area3D, combat_position: Vector3)

const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const PLAYER_PROJECTILE_SCENE := preload("res://entities/projectiles/player_projectile_3d.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://entities/projectiles/enemy_projectile_3d.tscn")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const InteractionRange := preload("res://systems/projectile_interaction_range_3d.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const EnemyTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")

@export_range(1, 512, 1) var player_pool_size: int = 512
@export_range(1, 512, 1) var enemy_pool_size: int = 256
@export_range(1, 16, 1) var warm_batch_size: int = 8
@export_range(32.0, 256.0, 1.0) var interaction_range_pixels: float = FlightTuning.BOOST_DEFLECT_RADIUS
@export_range(0.0, 64.0, 1.0) var interaction_hysteresis_pixels: float = 16.0

# Bookkeeping only: ObjectPool remains the sole cache/acquire/release mechanism.
class PoolState:
	var scene: PackedScene
	var capacity := 0
	# Includes deferred returns until ObjectPool has made them available.
	var checked_out: Array[Projectile] = []
	var warmed_ids: Dictionary[int, bool] = {}
	var shots_fired := 0
	var rejected_shots := 0
	var peak_active := 0
	var pool_growth := 0
	var deflections := 0

	func _init(value: PackedScene) -> void:
		scene = value

var is_ready := false
var _warming := false
var _peak_active := 0
var _flight_space: FlightSpace
var _active_parent: Node3D
var _idle_parent: Node3D
var _player: PlayerCraft
var _combat_bounds := Rect2()
var _interaction_range := InteractionRange.new()
var _pools: Array[PoolState] = [
	PoolState.new(PLAYER_PROJECTILE_SCENE),
	PoolState.new(ENEMY_PROJECTILE_SCENE),
]


func configure(
	flight_space: FlightSpace,
	active_parent: Node3D,
	idle_parent: Node3D,
	player: PlayerCraft
) -> void:
	_flight_space = flight_space
	_active_parent = active_parent
	_idle_parent = idle_parent
	_player = player
	_pools[Projectile.Kind.PLAYER].capacity = player_pool_size
	_pools[Projectile.Kind.ENEMY].capacity = enemy_pool_size
	_interaction_range.configure(flight_space, player, interaction_range_pixels, interaction_hysteresis_pixels)
	_refresh_bounds()
	if not get_viewport().size_changed.is_connected(_refresh_bounds):
		get_viewport().size_changed.connect(_refresh_bounds)


func _physics_process(delta: float) -> void:
	if is_ready and GameManager.is_game_active:
		_interaction_range.update_target()
		_update_homing(delta)


func warm_projectile_pools() -> bool:
	if is_ready:
		return true
	if _warming or _flight_space == null or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Projectile] = []
	for pool in _pools:
		for index in range(pool.capacity):
			var projectile := ObjectPool.acquire(pool.scene, _active_parent) as Projectile
			if projectile == null:
				_warming = false
				return false
			var interaction: InteractionRange = _interaction_range if projectile.kind == Projectile.Kind.ENEMY else null
			projectile.configure_pool(_idle_parent, _flight_space, interaction)
			projectile.hit.connect(_on_projectile_hit.bind(projectile))
			projectile.returned_to_pool.connect(_on_projectile_returned.bind(pool))
			projectile.prepare_visual_warmup()
			warm_nodes.append(projectile)
			pool.warmed_ids[projectile.get_instance_id()] = true
			if (index + 1) % warm_batch_size == 0:
				await get_tree().process_frame
	# Covered/minimized windows may stop drawing. Warm both families with one
	# transition-only frame, rather than waiting indefinitely for post-draw.
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	for index in range(warm_nodes.size()):
		warm_nodes[index].despawn()
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	_warming = false
	is_ready = true
	return true


func fire_player_projectile(combat_position: Vector3, direction: Vector3) -> void:
	var size_multiplier := _player.get_projectile_scale() if _player != null else 1.0
	_fire(Projectile.Kind.PLAYER, combat_position, direction, WeaponTuning.PROJECTILE_SPEED, size_multiplier)


## Drone Escort shots use the reference drone's normal projectile size even
## when the Player Craft has a temporary projectile-scale power-up active.
func fire_drone_projectile(combat_position: Vector3, direction: Vector3) -> void:
	_fire(Projectile.Kind.PLAYER, combat_position, direction, WeaponTuning.PROJECTILE_SPEED, 1.0)


func fire_enemy_projectile(combat_position: Vector3, direction: Vector3, speed_pixels: float = EnemyTuning.DEFAULT_SPEED) -> void:
	_fire(Projectile.Kind.ENEMY, combat_position, direction, speed_pixels)


## Clears both native projectile families for review reset and scene teardown.
## Each wrapper owns its deferred physics-safe return; the manager only
## requests the return from its current checked-out set.
func clear_projectiles() -> void:
	clear_player_projectiles()
	clear_enemy_projectiles()


func clear_player_projectiles() -> void:
	_clear_pool(Projectile.Kind.PLAYER)


func clear_enemy_projectiles() -> void:
	_clear_pool(Projectile.Kind.ENEMY)


func _clear_pool(kind: Projectile.Kind) -> void:
	for projectile in _pools[kind].checked_out.duplicate():
		if is_instance_valid(projectile):
			projectile.despawn()


## Deflects every active incoming projectile inside the reference's exact
## screen-pixel radius. Player3D requests this synchronously before its chain
## input check, matching the reference boost update order.
func deflect_enemy_projectiles(
	deflector_position: Vector3,
	deflector_velocity: Vector3
) -> void:
	if not is_ready or not GameManager.is_game_active or _player == null:
		return
	var radius_squared := interaction_range_pixels * interaction_range_pixels
	var enemy_pool := _pools[Projectile.Kind.ENEMY]
	for projectile in enemy_pool.checked_out:
		if not projectile.is_active or projectile.is_deflected:
			continue
		var screen_offset := _flight_space.combat_motion_to_screen(
			projectile.global_position - deflector_position
		)
		if screen_offset.length_squared() > radius_squared:
			continue
		_try_deflect_enemy_projectile(projectile, deflector_position, deflector_velocity)


func _try_deflect_enemy_projectile(
	projectile: Projectile,
	deflector_position: Vector3,
	deflector_velocity: Vector3
) -> bool:
	if not projectile.deflect(deflector_position, deflector_velocity):
		return false
	_pools[Projectile.Kind.ENEMY].deflections += 1
	AudioManager.play_deflect()
	_player.register_boost_reflection()
	var combat_position := projectile.global_position
	combat_position.y = 0.0
	enemy_projectile_deflected.emit(projectile, combat_position)
	return true


func _fire(
	kind: Projectile.Kind,
	combat_position: Vector3,
	direction: Vector3,
	speed_pixels: float,
	size_multiplier: float = 1.0
) -> void:
	if not is_ready or not GameManager.is_game_active:
		return
	var pool := _pools[kind]
	# Saturation is bounded and observable; never instantiate to cover a node
	# that is still waiting for its deferred return.
	if pool.checked_out.size() >= pool.warmed_ids.size():
		pool.rejected_shots += 1
		return
	var projectile := ObjectPool.acquire(pool.scene, _active_parent) as Projectile
	if projectile == null:
		return
	if not pool.warmed_ids.has(projectile.get_instance_id()):
		pool.pool_growth += 1
	var screen_direction := _flight_space.combat_motion_to_screen(direction).normalized()
	if screen_direction.is_zero_approx():
		screen_direction = Vector2.UP if kind == Projectile.Kind.PLAYER else Vector2.DOWN
	var projectile_velocity := _flight_space.screen_motion_to_combat(screen_direction * speed_pixels)
	pool.checked_out.append(projectile)
	projectile.pool_activate(combat_position, projectile_velocity, _combat_bounds, size_multiplier)
	if not projectile.is_active:
		pool.checked_out.erase(projectile)
		pool.rejected_shots += 1
		return
	if kind == Projectile.Kind.PLAYER and _player != null:
		projectile.piercing = _player.has_elite_upgrade("piercing")
		projectile.explosive = _player.has_elite_upgrade("explosive_rounds")
		projectile.homing = _player.has_elite_upgrade("auto_aim")
	projectile_fired.emit(kind, combat_position, direction, speed_pixels)
	pool.shots_fired += 1
	_record_active_peaks()


func _record_active_peaks() -> void:
	# Sample bounded pools only on activation. Deferred returns are not active,
	# and separate family peaks may have occurred at different times.
	var total_active := 0
	for pool in _pools:
		var active := 0
		for projectile in pool.checked_out:
			if projectile.is_active:
				active += 1
		pool.peak_active = maxi(pool.peak_active, active)
		total_active += active
	_peak_active = maxi(_peak_active, total_active)


func _on_projectile_hit(
	target: Area3D,
	combat_position: Vector3,
	projectile: Projectile
) -> void:
	# Preserve the reference's collision-time defense for a projectile that
	# crosses the full response radius between Player scans or spawns overlapped.
	if (
		projectile.kind == Projectile.Kind.ENEMY
		and not projectile.is_deflected
		and target == _player
		and _player.can_deflect_projectiles()
		and _try_deflect_enemy_projectile(projectile, _player.global_position, _player.velocity)
	):
		return
	if projectile.kind == Projectile.Kind.PLAYER:
		player_projectile_hit.emit(target, combat_position)
		if projectile.explosive:
			explosion_requested.emit(combat_position, target)
	elif projectile.is_deflected:
		player_projectile_hit.emit(target, combat_position)
		AudioManager.play_hit_marker()
		deflected_projectile_hit.emit(target, combat_position)
	else:
		enemy_projectile_hit.emit(target, combat_position)


func _on_projectile_returned(projectile: Area3D, pool: PoolState) -> void:
	pool.checked_out.erase(projectile)


func _refresh_bounds() -> void:
	_combat_bounds = _flight_space.get_combat_bounds()
	for pool in _pools:
		for projectile in pool.checked_out:
			projectile.update_combat_bounds(_combat_bounds)


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_refresh_bounds):
		viewport.size_changed.disconnect(_refresh_bounds)


## Snapshots only on request, not a dictionary allocation per projectile/tick.
func get_metrics() -> Dictionary:
	var player_metrics := _pool_metrics(_pools[Projectile.Kind.PLAYER])
	var enemy_metrics := _pool_metrics(_pools[Projectile.Kind.ENEMY])
	var metrics := {
		"player": player_metrics,
		"enemy": enemy_metrics,
		# Godot publishes recent peak process/physics times once per second.
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
	for key in player_metrics:
		if key == "peak_active":
			continue
		metrics[key] = int(player_metrics[key]) + int(enemy_metrics[key])
	metrics["peak_active"] = _peak_active
	return metrics


func _pool_metrics(pool: PoolState) -> Dictionary:
	var active := 0
	var armed := 0
	var deflected_active := 0
	var swept := 0
	var step_usec := 0
	for projectile in pool.checked_out:
		if projectile.is_active:
			active += 1
			if projectile.is_deflected:
				deflected_active += 1
			step_usec += projectile.last_step_usec
			if projectile.last_sweep_performed:
				swept += 1
		if projectile.monitoring and not projectile.collision_shape.disabled:
			armed += 1
	return {
		"pool_size": pool.warmed_ids.size(),
		"active": active,
		"armed": armed,
		"swept": swept,
		"returning": pool.checked_out.size() - active,
		"idle": pool.warmed_ids.size() - pool.checked_out.size(),
		"peak_active": pool.peak_active,
		"deflected_active": deflected_active,
		"deflections": pool.deflections,
		"shots_fired": pool.shots_fired,
		"rejected_shots": pool.rejected_shots,
		"pool_growth_after_warmup": pool.pool_growth,
		"projectile_step_usec": step_usec,
	}


func _update_homing(delta: float) -> void:
	if _player == null or not _player.has_elite_upgrade("auto_aim"):
		return
	var enemies := get_tree().get_nodes_in_group(&"native_3d_enemies")
	for projectile in _pools[Projectile.Kind.PLAYER].checked_out:
		if not projectile.is_active or not projectile.homing:
			continue
		var nearest: Node3D
		var distance := 420.0
		var screen_velocity := _flight_space.combat_motion_to_screen(projectile.velocity)
		for enemy in enemies:
			if not enemy.is_active:
				continue
			var offset := _flight_space.combat_motion_to_screen(enemy.global_position - projectile.global_position)
			if offset.length() < distance and screen_velocity.normalized().dot(offset.normalized()) > 0.2:
				nearest = enemy
				distance = offset.length()
		if nearest != null:
			var desired := _flight_space.combat_motion_to_screen(nearest.global_position - projectile.global_position).normalized()
			var angle := clampf(screen_velocity.angle_to(desired), -delta * 2.5, delta * 2.5)
			projectile.velocity = _flight_space.screen_motion_to_combat(screen_velocity.rotated(angle))
			projectile.rotation.y = atan2(-projectile.velocity.x, -projectile.velocity.z)
