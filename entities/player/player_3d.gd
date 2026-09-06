extends Area3D
class_name Player3D
## Native Player Craft flight, damage, boost-chain, visual, hitbox, attachment,
## socket, and first-slice power-up contract.

signal fire_requested(combat_position: Vector3, direction: Vector3)
signal muzzle_feedback_requested(visual_position: Vector3, direction: Vector3)
signal deflection_requested(deflector_position: Vector3, deflector_velocity: Vector3)
signal boost_started(combat_position: Vector3, direction: Vector3)
signal damage_taken(combat_position: Vector3, source: DamageSource, remaining_lives: int)
signal invulnerability_changed(active: bool)
signal drone_escort_changed(enabled: bool)
signal shield_burst_requested(combat_position: Vector3)
signal shield_absorbed(combat_position: Vector3)
signal nuke_requested

enum DamageSource { ENEMY_CONTACT, ENEMY_PROJECTILE, HOSTILE_ORDNANCE }

const UpgradeVisuals := preload("res://entities/player/native_upgrade_visuals.gd")
const NativeUpgrades := preload("res://entities/player/native_player_upgrades.gd")

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const DamageTuning := preload("res://entities/player/player_damage_tuning.gd")
const PowerUpTypes := preload("res://entities/powerups/power_up_types.gd")

@export var speed_pixels: float = FlightTuning.SPEED
@export var acceleration: float = FlightTuning.ACCELERATION
@export var drag: float = FlightTuning.DRAG
@export var base_fire_interval: float = WeaponTuning.BASE_FIRE_INTERVAL
## Baseline-pixel boundary inset owned by the wrapper, not the imported GLB.
@export_range(0.0, 128.0, 0.001) var boundary_margin_pixels: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var shield_visual: MeshInstance3D = $Visuals/ShieldVisual
@onready var core_glow: MeshInstance3D = $Visuals/CoreGlow
@onready var engine_glow_left: MeshInstance3D = $Attachments/Sockets/EngineLeft/EngineGlow
@onready var engine_glow_right: MeshInstance3D = $Attachments/Sockets/EngineRight/EngineGlow
@onready var attachments: Node3D = $Attachments
@onready var sockets: Node3D = $Attachments/Sockets
@onready var shoot_timer: Timer = $ShootTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer

var _socket_names: Array[StringName] = []
var _flight_space: FlightSpace
var _movement_bounds := Rect2()

var velocity := Vector3.ZERO
var last_aim_direction := Vector3.FORWARD
var is_using_free_aim := false
var is_boosting := false
var boost_direction := Vector3.FORWARD
var boost_duration_timer := 0.0
var boost_cooldown_timer := 0.0
var boost_distance_remaining_pixels := 0.0
var boost_reflected_projectiles := 0
var boost_chain_window_timer := 0.0
var post_boost_slide_timer := 0.0
var drift_speed_bonus := 1.0
var is_invincible := false
var _invincibility_visual_elapsed := 0.0
var _ship_visual_elapsed := 0.0
var _shield_visual_elapsed := 0.0

# First-slice temporary power-up state. The type enum and collection signal
# remain shared with the reference Player through PowerUp/SignalBus.
var bullet_scale_level := 0
var has_shield := false
var has_rapid_fire := false
var has_spread_shot := false
var has_magnet := false
var rapid_fire_remaining := 0.0
var spread_shot_remaining := 0.0
var magnet_remaining := 0.0
var drone_escort_enabled := false
var _elite_clock := 0.0
var _shield_burst_clock := 0.0
var _orbital_hit_clock := 0.0
var _upgrade_visuals: UpgradeVisuals
var _elite_upgrades: Dictionary[String, bool] = {}


func _init() -> void:
	collision_layer = PhysicsLayers.PLAYER_CRAFT
	collision_mask = PhysicsLayers.PLAYER_CRAFT_MASK


func _ready() -> void:
	_upgrade_visuals = UpgradeVisuals.new()
	$Attachments/Modules.add_child(_upgrade_visuals)
	_cache_socket_names()
	set_combat_position(global_position)
	area_entered.connect(_on_area_entered)
	invincibility_timer.timeout.connect(_on_invincibility_ended)
	SignalBus.power_up_collected.connect(_on_power_up_collected)
	shield_visual.visible = false
	core_glow.visible = true
	_update_visual_feedback(0.0)
	# Asset review remains inert, even if an earlier run left GameManager active.
	set_physics_process(false)


func configure_flight_space(value: FlightSpace) -> void:
	if value == null or value.configuration == null:
		push_error("Player3D requires a configured FlightSpace3D before enabling controls")
		return
	_upgrade_visuals.reset()
	for id in _elite_upgrades:
		_upgrade_visuals.set_upgrade(id, true)
	$Visuals/PlayerHullGLB.visible = MetaProgression.selected_ship == "ship_swallowtail"
	$Visuals/InterceptorHull.visible = MetaProgression.selected_ship == "ship_interceptor"
	$Visuals/BulwarkHull.visible = MetaProgression.selected_ship == "ship_bulwark"
	_flight_space = value
	_reset_feedback_state()
	if not get_viewport().size_changed.is_connected(_refresh_movement_bounds):
		get_viewport().size_changed.connect(_refresh_movement_bounds)
	_refresh_movement_bounds()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	$Attachments/Sockets/EngineLeft/Exhaust.emitting = GameManager.is_game_active
	$Attachments/Sockets/EngineRight/Exhaust.emitting = GameManager.is_game_active
	_update_visual_feedback(delta)
	_update_invincibility_visual(delta)
	if not GameManager.is_game_active:
		return
	var input_direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length()
	_update_movement(input_direction, delta)
	_clamp_to_flight_bounds()
	_update_boost(delta)
	_update_aiming()
	_update_power_ups(delta)
	_update_elite_abilities(delta)
	_update_shooting()


func _update_visual_feedback(delta: float) -> void:
	_ship_visual_elapsed += delta
	var flight_power := 1.0 if GameManager.is_game_active else 0.22
	var engine_power := flight_power * (1.35 if is_boosting else 1.0)
	var pulse := 0.86 + 0.14 * sin(_ship_visual_elapsed * 11.0)
	core_glow.set_instance_shader_parameter(&"instance_color", Color(0.18, 0.8, 1.0, 1.0))
	core_glow.set_instance_shader_parameter(&"instance_alpha", flight_power)
	core_glow.set_instance_shader_parameter(&"instance_intensity", pulse * (1.0 + engine_power * 0.55))
	core_glow.set_instance_shader_parameter(&"instance_phase", 0.0)
	for glow in [engine_glow_left, engine_glow_right]:
		glow.set_instance_shader_parameter(&"instance_color", Color(0.08, 0.66, 1.0, 1.0))
		glow.set_instance_shader_parameter(&"instance_alpha", flight_power)
		glow.set_instance_shader_parameter(&"instance_intensity", engine_power * pulse)
		glow.set_instance_shader_parameter(&"instance_phase", 1.4 if glow == engine_glow_right else 0.0)
	if shield_visual.visible:
		_shield_visual_elapsed += delta
		shield_visual.set_instance_shader_parameter(
			&"instance_pulse", 0.78 + 0.22 * sin(_shield_visual_elapsed * 9.0)
		)


func _reset_feedback_state() -> void:
	_ship_visual_elapsed = 0.0
	_shield_visual_elapsed = 0.0
	core_glow.visible = true
	shield_visual.visible = has_shield
	shield_visual.set_instance_shader_parameter(&"instance_pulse", 0.0)
	_update_visual_feedback(0.0)


## Applies damage through the shared GameManager/SignalBus authority. A native
## Shield absorbs the hit and opens the reference's short immunity window;
## returns true only when this call consumed a life.
func receive_damage(combat_position: Vector3, source: DamageSource) -> bool:
	if not GameManager.is_game_active or is_invincible or GameManager.lives <= 0:
		return false
	if has_shield:
		has_shield = false
		shield_visual.visible = false
		var shield_position := combat_position
		shield_position.y = 0.0
		shield_absorbed.emit(shield_position)
		AudioManager.play_shield()
		_start_invincibility(DamageTuning.SHIELD_INVULNERABILITY)
		return false
	combat_position.y = 0.0
	var survives_hit := GameManager.lives > 1
	AudioManager.play_player_hit()
	SignalBus.player_hit.emit()
	if survives_hit:
		_start_invincibility(_get_invulnerability_duration(source))
	damage_taken.emit(combat_position, source, GameManager.lives)
	return true


## Clears wrapper-local hit state when a review or future retry resets run state.
func reset_damage_state() -> void:
	invincibility_timer.stop()
	var was_invincible := is_invincible
	is_invincible = false
	_invincibility_visual_elapsed = 0.0
	visuals.show()
	_reset_feedback_state()
	if was_invincible:
		invulnerability_changed.emit(false)


## Clears temporary native power-up state for review reset and run restart.
func reset_power_up_state() -> void:
	bullet_scale_level = 0
	has_shield = false
	has_rapid_fire = false
	has_spread_shot = false
	has_magnet = false
	rapid_fire_remaining = 0.0
	spread_shot_remaining = 0.0
	magnet_remaining = 0.0
	shield_visual.visible = false
	_shield_visual_elapsed = 0.0
	shield_visual.set_instance_shader_parameter(&"instance_pulse", 0.0)


func get_power_up_status() -> Dictionary:
	return {
		"scale": bullet_scale_level,
		"shield": has_shield,
		"rapid": has_rapid_fire,
		"spread": has_spread_shot,
		"magnet": has_magnet,
		"rapid_remaining": rapid_fire_remaining,
		"spread_remaining": spread_shot_remaining,
		"magnet_remaining": magnet_remaining,
	}


## Native counterpart to the reference Player's elite upgrade hook. The
## gameplay controller owns the top-level Drone Escort instance; Player3D
## owns only the run-facing upgrade state and change notification.
func set_drone_escort_enabled(enabled: bool) -> void:
	if drone_escort_enabled == enabled:
		return
	drone_escort_enabled = enabled
	drone_escort_changed.emit(enabled)


func is_drone_escort_enabled() -> bool:
	return drone_escort_enabled


## Counts successful reflections only during an active boost. Reflections in
## the short post-boost window remain defensive but do not build a new chain.
func register_boost_reflection() -> void:
	if is_boosting:
		boost_reflected_projectiles += 1


func can_deflect_projectiles() -> bool:
	return is_boosting or boost_chain_window_timer > 0.0


func _on_area_entered(area: Area3D) -> void:
	# Projectile hits route once through ProjectileManager3D/Native3DGameplay.
	if area.collision_layer & PhysicsLayers.HOSTILE_ORDNANCE:
		if is_boosting and area.has_method("clear_ordnance"):
			area.clear_ordnance()
			return
		receive_damage(area.global_position, DamageSource.HOSTILE_ORDNANCE)
	elif area.collision_layer & PhysicsLayers.ENEMY_CRAFT:
		receive_damage(area.global_position, DamageSource.ENEMY_CONTACT)


func _start_invincibility(duration: float) -> void:
	is_invincible = true
	_invincibility_visual_elapsed = 0.0
	invincibility_timer.start(duration)
	invulnerability_changed.emit(true)


func _on_invincibility_ended() -> void:
	is_invincible = false
	_invincibility_visual_elapsed = 0.0
	visuals.show()
	invulnerability_changed.emit(false)


func _update_invincibility_visual(delta: float) -> void:
	if not is_invincible:
		return
	_invincibility_visual_elapsed += delta
	var blink_index := floori(_invincibility_visual_elapsed / DamageTuning.BLINK_HALF_INTERVAL)
	visuals.visible = blink_index % 2 == 0


func _get_invulnerability_duration(source: DamageSource) -> float:
	match source:
		DamageSource.ENEMY_CONTACT:
			return DamageTuning.CONTACT_INVULNERABILITY
		DamageSource.ENEMY_PROJECTILE:
			return DamageTuning.PROJECTILE_INVULNERABILITY
		DamageSource.HOSTILE_ORDNANCE:
			return DamageTuning.HOSTILE_ORDNANCE_INVULNERABILITY
	return DamageTuning.PROJECTILE_INVULNERABILITY


func _update_shooting() -> void:
	if not Input.is_action_pressed("shoot") or not shoot_timer.is_stopped():
		return
	var muzzle := get_socket(&"MuzzleCenter")
	if muzzle == null:
		return
	var rate_multiplier := maxf(
		1.0 - GameManager.bonus_fire_rate_pct - GameManager.meta_fire_rate_pct - GameManager.ship_fire_rate_pct,
		WeaponTuning.MIN_FIRE_RATE_MULTIPLIER
	)
	if has_rapid_fire:
		rate_multiplier *= 0.4
	var interval := maxf(base_fire_interval * rate_multiplier, WeaponTuning.MIN_FIRE_INTERVAL)
	if has_elite_upgrade("overclock") and fmod(_elite_clock, 16.0) < 2.5:
		interval /= 3.0
	shoot_timer.start(interval)
	for fire_direction in _get_fire_directions():
		_emit_muzzle_shot(muzzle, fire_direction)
	if has_elite_upgrade("twin_cannons"):
		for socket_name in [&"MuzzleLeft", &"MuzzleRight"]:
			var side_muzzle := get_socket(socket_name)
			if side_muzzle != null:
				_emit_muzzle_shot(side_muzzle, last_aim_direction)
	if has_elite_upgrade("rear_gunner"):
		var rear_muzzle := get_socket(&"MuzzleRear")
		if rear_muzzle != null:
			_emit_muzzle_shot(rear_muzzle, -last_aim_direction)


func _emit_muzzle_shot(muzzle: Marker3D, direction: Vector3) -> void:
	var normalized_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if normalized_direction.is_zero_approx():
		normalized_direction = last_aim_direction
	var screen_direction := _flight_space.combat_motion_to_screen(normalized_direction).normalized()
	var spawn_position := muzzle.global_position + _flight_space.screen_motion_to_combat(
		screen_direction * WeaponTuning.MUZZLE_CLEARANCE
	)
	spawn_position.y = 0.0
	fire_requested.emit(spawn_position, normalized_direction)
	muzzle_feedback_requested.emit(muzzle.global_position, normalized_direction)


func _get_fire_directions() -> Array[Vector3]:
	var directions: Array[Vector3] = [last_aim_direction]
	if (not has_spread_shot and not has_elite_upgrade("spread_shot_elite")) or _flight_space == null:
		return directions
	var screen_direction := _flight_space.combat_motion_to_screen(last_aim_direction).normalized()
	var angles: Array[float] = [-deg_to_rad(15.0), deg_to_rad(15.0)]
	if has_spread_shot and has_elite_upgrade("spread_shot_elite"):
		angles.append_array([-deg_to_rad(30.0), deg_to_rad(30.0)])
	for spread_angle in angles:
		var spread_screen_direction := screen_direction.rotated(spread_angle)
		directions.append(_flight_space.input_to_combat_direction(spread_screen_direction))
	return directions


func get_projectile_scale() -> float:
	return 1.0 + float(bullet_scale_level) * 0.5


func _update_power_ups(delta: float) -> void:
	if has_rapid_fire:
		rapid_fire_remaining = maxf(rapid_fire_remaining - delta, 0.0)
		if is_zero_approx(rapid_fire_remaining):
			has_rapid_fire = false
	if has_spread_shot:
		spread_shot_remaining = maxf(spread_shot_remaining - delta, 0.0)
		if is_zero_approx(spread_shot_remaining):
			has_spread_shot = false
	if has_magnet:
		magnet_remaining = maxf(magnet_remaining - delta, 0.0)
		if is_zero_approx(magnet_remaining):
			has_magnet = false
	if has_magnet or has_elite_upgrade("magnet_field"):
		_attract_native_pickups(delta)


func _attract_native_pickups(delta: float) -> void:
	for group_name in [&"native_3d_powerups", &"xp_orbs"]:
		for pickup in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(pickup) and pickup.has_method("magnet_pull_to"):
				pickup.magnet_pull_to(global_position, delta, 525.0 if has_elite_upgrade("magnet_field") else 350.0)


func _on_power_up_collected(type: int, _combat_position: Vector3) -> void:
	AudioManager.play_powerup()
	match type:
		PowerUpTypes.Type.SCALE_UP:
			_apply_scale_up()
		PowerUpTypes.Type.RAPID_FIRE:
			_apply_rapid_fire()
		PowerUpTypes.Type.SHIELD:
			_apply_shield()
		PowerUpTypes.Type.SPREAD_SHOT:
			_apply_spread_shot()
		PowerUpTypes.Type.MAGNET:
			_apply_magnet()
		PowerUpTypes.Type.NUKE:
			_apply_nuke()


func _apply_scale_up() -> void:
	bullet_scale_level = mini(bullet_scale_level + 1, 3)


func _apply_rapid_fire() -> void:
	has_rapid_fire = true
	rapid_fire_remaining = 8.0


func _apply_shield() -> void:
	has_shield = true
	_shield_visual_elapsed = 0.0
	shield_visual.visible = true


func _apply_spread_shot() -> void:
	has_spread_shot = true
	spread_shot_remaining = 8.0


func _apply_magnet() -> void:
	has_magnet = true
	magnet_remaining = 10.0


func _apply_nuke() -> void:
	apply_nuke()


## Clears native enemy actors, active hostile payload projectiles, and pooled
## hazards through their scene-owned managers. Pending mine payload callbacks
## are invalidated before they can repopulate the cleared pools.
func apply_nuke() -> void:
	nuke_requested.emit()


func _update_movement(input_direction: Vector2, delta: float) -> void:
	if is_boosting:
		_move_boost(input_direction, delta)
		return
	var effective_speed := speed_pixels * (
		1.0 + GameManager.bonus_speed_pct + GameManager.meta_speed_pct + GameManager.ship_speed_pct
	) * drift_speed_bonus * (1.2 if has_elite_upgrade("afterburner") else 1.0)
	var current_acceleration := acceleration
	var current_drag := drag
	if post_boost_slide_timer > 0.0:
		var screen_velocity := _flight_space.combat_motion_to_screen(velocity)
		var speed_ratio := clampf(
			screen_velocity.length() / (speed_pixels * FlightTuning.DRIFT_SPEED_RATIO), 0.0, 1.0
		)
		current_drag = FlightTuning.DRIFT_DRAG_BASE * lerpf(
			1.0, FlightTuning.DRIFT_MIN_DRAG_FACTOR, speed_ratio
		)
		current_acceleration = FlightTuning.DRIFT_ACCEL_BASE * lerpf(
			1.0, FlightTuning.DRIFT_MIN_ACCEL_FACTOR, speed_ratio
		)
		post_boost_slide_timer -= delta
		if (
			input_direction.length() > FlightTuning.BRAKE_INPUT_THRESHOLD
			and screen_velocity.length() > FlightTuning.BRAKE_MIN_SPEED
			and input_direction.dot(screen_velocity.normalized()) < FlightTuning.BRAKE_OPPOSITION_DOT
		):
			current_drag = FlightTuning.BRAKE_DRAG
			current_acceleration = FlightTuning.BRAKE_ACCELERATION
			drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, FlightTuning.BRAKE_BONUS_DECAY * delta)
	if has_elite_upgrade("afterburner"):
		current_acceleration *= 1.15
	if not input_direction.is_zero_approx():
		var target_velocity := _flight_space.screen_motion_to_combat(input_direction * effective_speed)
		velocity = velocity.lerp(target_velocity, current_acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, current_drag * delta)
	set_combat_position(get_combat_position() + velocity * delta)


func _move_boost(input_direction: Vector2, delta: float) -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(boost_direction).normalized()
	if not input_direction.is_zero_approx():
		var steering_weight := clampf(FlightTuning.BOOST_STEER_RATE * delta, 0.0, 1.0)
		screen_direction = screen_direction.lerp(input_direction.normalized(), steering_weight).normalized()
		boost_direction = _flight_space.input_to_combat_direction(screen_direction)
	var boost_speed := FlightTuning.BOOST_DISTANCE / FlightTuning.BOOST_DURATION
	var step_distance := minf(boost_speed * delta, boost_distance_remaining_pixels)
	velocity = _flight_space.screen_motion_to_combat(screen_direction * boost_speed)
	set_combat_position(
		get_combat_position() + _flight_space.screen_motion_to_combat(screen_direction * step_distance)
	)
	boost_distance_remaining_pixels -= step_distance


func _update_boost(delta: float) -> void:
	if is_boosting:
		boost_duration_timer -= delta
		deflection_requested.emit(global_position, velocity)
		if Input.is_action_just_pressed("boost") and _has_boost_chain():
			_begin_boost()
			return
		drift_speed_bonus = move_toward(
			drift_speed_bonus, FlightTuning.DRIFT_BONUS_MAX, FlightTuning.DRIFT_BONUS_RATE * delta
		)
		if boost_duration_timer <= 0.0 or boost_distance_remaining_pixels <= 0.0:
			is_boosting = false
			boost_distance_remaining_pixels = 0.0
			if _has_boost_chain():
				boost_chain_window_timer = FlightTuning.BOOST_CHAIN_WINDOW
				boost_cooldown_timer = 0.0
			else:
				boost_cooldown_timer = _get_boost_cooldown()
			post_boost_slide_timer = FlightTuning.POST_BOOST_SLIDE_DURATION
	else:
		if boost_chain_window_timer > 0.0:
			boost_chain_window_timer = maxf(boost_chain_window_timer - delta, 0.0)
			deflection_requested.emit(global_position, velocity)
		drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, FlightTuning.DRIFT_DECAY_RATE * delta)
		boost_cooldown_timer = maxf(boost_cooldown_timer - delta, 0.0)
		if Input.is_action_just_pressed("boost") and boost_cooldown_timer <= 0.0:
			_begin_boost()


func _begin_boost() -> void:
	is_boosting = true
	boost_duration_timer = FlightTuning.BOOST_DURATION
	boost_reflected_projectiles = 0
	boost_chain_window_timer = 0.0
	boost_distance_remaining_pixels = FlightTuning.BOOST_DISTANCE
	var screen_velocity := _flight_space.combat_motion_to_screen(velocity)
	var screen_direction := (
		screen_velocity.normalized()
		if screen_velocity.length() > FlightTuning.BOOST_HEADING_MIN_SPEED
		else Vector2.UP
	)
	boost_direction = _flight_space.input_to_combat_direction(screen_direction)
	AudioManager.play_boost()
	boost_started.emit(get_combat_position(), boost_direction)


func _has_boost_chain() -> bool:
	return boost_reflected_projectiles >= FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD


func _get_boost_cooldown() -> float:
	if boost_reflected_projectiles <= 0:
		return FlightTuning.BOOST_COOLDOWN
	var additional_reflections := boost_reflected_projectiles - 1
	return maxf(
		FlightTuning.BOOST_REFLECT_COOLDOWN
		- float(additional_reflections) * FlightTuning.BOOST_REFLECT_COOLDOWN_STEP,
		FlightTuning.BOOST_REFLECT_COOLDOWN_MIN
	)


func _update_aiming() -> void:
	var stick_direction := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick_direction.length() > FlightTuning.AIM_STICK_DEADZONE:
		last_aim_direction = _flight_space.input_to_combat_direction(stick_direction)
		is_using_free_aim = true
	var mouse_position := get_viewport().get_mouse_position()
	var player_screen_position := _flight_space.combat_to_screen(get_combat_position())
	if mouse_position.distance_to(player_screen_position) > FlightTuning.AIM_MOUSE_MIN_DISTANCE:
		if (
			Input.get_last_mouse_velocity().length() > FlightTuning.AIM_MOUSE_MIN_SPEED
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		):
			var aim_position := _flight_space.screen_to_combat_plane(mouse_position)
			last_aim_direction = (aim_position - get_combat_position()).normalized()
			is_using_free_aim = true
	if is_using_free_aim:
		rotation = Vector3(0.0, atan2(-last_aim_direction.x, -last_aim_direction.z), 0.0)


## Preserve the reference's 60-pixel facing marker, projected by the active
## camera into the retained 2D HUD rather than parented into the 3D craft.
func get_aim_reticle_combat_position() -> Vector3:
	if _flight_space == null:
		return get_combat_position()
	var screen_direction := _flight_space.combat_motion_to_screen(last_aim_direction).normalized()
	return get_combat_position() + _flight_space.screen_motion_to_combat(
		screen_direction * FlightTuning.AIM_RETICLE_DISTANCE
	)


func _refresh_movement_bounds() -> void:
	_movement_bounds = _flight_space.get_combat_bounds(-boundary_margin_pixels)
	_clamp_to_flight_bounds()


func _clamp_to_flight_bounds() -> void:
	var combat_position := get_combat_position()
	combat_position.x = clampf(combat_position.x, _movement_bounds.position.x, _movement_bounds.end.x)
	combat_position.z = clampf(combat_position.z, _movement_bounds.position.y, _movement_bounds.end.y)
	set_combat_position(combat_position)


func set_combat_position(combat_position: Vector3) -> void:
	global_position = Vector3(combat_position.x, 0.0, combat_position.z)


func get_combat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func get_socket(socket_name: StringName) -> Marker3D:
	if not _socket_names.has(socket_name):
		return null
	return sockets.get_node_or_null(NodePath(String(socket_name))) as Marker3D


func get_socket_names() -> Array[StringName]:
	return _socket_names.duplicate()


func _cache_socket_names() -> void:
	_socket_names.clear()
	for child in sockets.get_children():
		if not (child is Marker3D):
			push_error("Player3D socket container only accepts Marker3D children: %s" % child.name)
			continue
		_socket_names.append(child.name)
	if _socket_names.is_empty():
		push_error("Player3D requires at least one Marker3D socket")


## HUD-facing effect state without exposing Timer nodes or scene internals.
func get_power_up_timing(type: int) -> Vector2:
	match type:
		PowerUpTypes.Type.RAPID_FIRE:
			return Vector2(rapid_fire_remaining, 8.0)
		PowerUpTypes.Type.SPREAD_SHOT:
			return Vector2(spread_shot_remaining, 8.0)
		PowerUpTypes.Type.MAGNET:
			return Vector2(magnet_remaining, 10.0)
	return Vector2.ZERO


func has_elite_upgrade(upgrade_id: String) -> bool:
	return _elite_upgrades.get(upgrade_id, false)


## Returns false for unsupported or duplicate selections. The reward controller
## records the global chosen ID only after this native application succeeds.
func apply_elite_upgrade(upgrade_id: String) -> bool:
	if not NativeUpgrades.SUPPORTED_IDS.has(upgrade_id) or has_elite_upgrade(upgrade_id):
		return false
	_elite_upgrades[upgrade_id] = true
	_upgrade_visuals.set_upgrade(upgrade_id, true)
	match upgrade_id:
		"drone_escort":
			set_drone_escort_enabled(true)
		"hull_plating":
			GameManager.lives += 1
			SignalBus.lives_changed.emit(GameManager.lives)
	return true


## Run reset calls this after GameManager has reset lives and chosen IDs.
## Continue/revive deliberately does not clear permanent upgrades.
func reset_elite_upgrades() -> void:
	_elite_upgrades.clear()
	_elite_clock = 0.0
	_shield_burst_clock = 0.0
	_orbital_hit_clock = 0.0
	_upgrade_visuals.reset()
	set_drone_escort_enabled(false)


func _update_elite_abilities(delta: float) -> void:
	_elite_clock += delta
	if has_elite_upgrade("shield_burst"):
		_shield_burst_clock += delta
		if _shield_burst_clock >= 10.0:
			_shield_burst_clock = 0.0
			shield_burst_requested.emit(get_combat_position())
	if not has_elite_upgrade("orbitals"):
		return
	var positions: Array[Vector3] = _upgrade_visuals.advance_orbitals(delta, _flight_space, get_combat_position())
	_orbital_hit_clock -= delta
	for point in positions:
		for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
			if projectile.is_active and not projectile.is_deflected and _flight_space.combat_motion_to_screen(projectile.global_position - point).length() < 18.0:
				projectile.despawn()
		if _orbital_hit_clock <= 0.0:
			for enemy in get_tree().get_nodes_in_group(&"native_3d_enemies"):
				if enemy.is_active and _flight_space.combat_motion_to_screen(enemy.global_position - point).length() < 30.0:
					enemy.take_damage(2 + GameManager.bonus_damage)
	if _orbital_hit_clock <= 0.0:
		_orbital_hit_clock = 0.25


func get_active_elite_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _elite_upgrades:
		ids.append(id)
	return ids


func prepare_visual_warmup() -> void:
	_upgrade_visuals.prepare_visual_warmup()
	$Visuals/InterceptorHull.show()
	$Visuals/BulwarkHull.show()
