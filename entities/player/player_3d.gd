extends Area3D
class_name Player3D
## Native Player Craft flight, damage, visual, hitbox, attachment, and socket contract.
## Shields, upgrades, projectile deflection, and chains arrive in later slices.

signal fire_requested(combat_position: Vector3, direction: Vector3)
signal damage_taken(combat_position: Vector3, source: DamageSource, remaining_lives: int)
signal invulnerability_changed(active: bool)

enum DamageSource { ENEMY_CONTACT, ENEMY_PROJECTILE }

const PhysicsLayers := preload("res://systems/native_3d_physics_layers.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const DamageTuning := preload("res://entities/player/player_damage_tuning.gd")

@export var speed_pixels: float = FlightTuning.SPEED
@export var acceleration: float = FlightTuning.ACCELERATION
@export var drag: float = FlightTuning.DRAG
@export var base_fire_interval: float = WeaponTuning.BASE_FIRE_INTERVAL
## Baseline-pixel boundary inset owned by the wrapper, not the imported GLB.
@export_range(0.0, 128.0, 0.001) var boundary_margin_pixels: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
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
var post_boost_slide_timer := 0.0
var drift_speed_bonus := 1.0
var is_invincible := false
var _invincibility_visual_elapsed := 0.0


func _init() -> void:
	collision_layer = PhysicsLayers.PLAYER_CRAFT
	collision_mask = PhysicsLayers.PLAYER_CRAFT_MASK


func _ready() -> void:
	_cache_socket_names()
	set_combat_position(global_position)
	area_entered.connect(_on_area_entered)
	invincibility_timer.timeout.connect(_on_invincibility_ended)
	# Asset review remains inert, even if an earlier run left GameManager active.
	set_physics_process(false)


func configure_flight_space(value: FlightSpace) -> void:
	if value == null or value.configuration == null:
		push_error("Player3D requires a configured FlightSpace3D before enabling controls")
		return
	_flight_space = value
	if not get_viewport().size_changed.is_connected(_refresh_movement_bounds):
		get_viewport().size_changed.connect(_refresh_movement_bounds)
	_refresh_movement_bounds()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
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
	_update_shooting()


## Applies one life of damage through the shared GameManager/SignalBus authority.
## Returns true only when this call consumed a life.
func receive_damage(combat_position: Vector3, source: DamageSource) -> bool:
	if not GameManager.is_game_active or is_invincible or GameManager.lives <= 0:
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
	if was_invincible:
		invulnerability_changed.emit(false)


func _on_area_entered(area: Area3D) -> void:
	# Projectile hits route once through ProjectileManager3D/Native3DGameplay.
	if area.collision_layer & PhysicsLayers.ENEMY_CRAFT:
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
	shoot_timer.start(maxf(base_fire_interval * rate_multiplier, WeaponTuning.MIN_FIRE_INTERVAL))
	var screen_direction := _flight_space.combat_motion_to_screen(last_aim_direction).normalized()
	var spawn_position := muzzle.global_position + _flight_space.screen_motion_to_combat(
		screen_direction * WeaponTuning.MUZZLE_CLEARANCE
	)
	spawn_position.y = 0.0
	fire_requested.emit(spawn_position, last_aim_direction)


func _update_movement(input_direction: Vector2, delta: float) -> void:
	if is_boosting:
		_move_boost(input_direction, delta)
		return
	var effective_speed := speed_pixels * (
		1.0 + GameManager.bonus_speed_pct + GameManager.meta_speed_pct + GameManager.ship_speed_pct
	) * drift_speed_bonus
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
		drift_speed_bonus = move_toward(
			drift_speed_bonus, FlightTuning.DRIFT_BONUS_MAX, FlightTuning.DRIFT_BONUS_RATE * delta
		)
		if boost_duration_timer <= 0.0 or boost_distance_remaining_pixels <= 0.0:
			is_boosting = false
			boost_distance_remaining_pixels = 0.0
			boost_cooldown_timer = FlightTuning.BOOST_COOLDOWN
			post_boost_slide_timer = FlightTuning.POST_BOOST_SLIDE_DURATION
	else:
		drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, FlightTuning.DRIFT_DECAY_RATE * delta)
		boost_cooldown_timer = maxf(boost_cooldown_timer - delta, 0.0)
		if Input.is_action_just_pressed("boost") and boost_cooldown_timer <= 0.0:
			_begin_boost()


func _begin_boost() -> void:
	is_boosting = true
	boost_duration_timer = FlightTuning.BOOST_DURATION
	boost_distance_remaining_pixels = FlightTuning.BOOST_DISTANCE
	var screen_velocity := _flight_space.combat_motion_to_screen(velocity)
	var screen_direction := (
		screen_velocity.normalized()
		if screen_velocity.length() > FlightTuning.BOOST_HEADING_MIN_SPEED
		else Vector2.UP
	)
	boost_direction = _flight_space.input_to_combat_direction(screen_direction)
	AudioManager.play_boost()


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
