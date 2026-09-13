extends BasicEnemy3D
class_name SniperEnemy3D
## Native Sniper lineage with locked warnings, predictive fire, and pooled rails.

signal aimed_shot_fired(speed_pixels: float)

const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")

const ENTRY_DISTANCE_PIXELS := 115.0
const HOLD_AMPLITUDE_PIXELS := 54.0
const HOLD_FREQUENCY := 1.8
const HOLD_DURATION_SECONDS := 6.0
const WITHDRAW_SPEED_PIXELS := 210.0
const FIRST_SHOT_MIN_SECONDS := 0.6
const FIRST_SHOT_MAX_SECONDS := 1.2
const SHOT_INTERVAL_SECONDS := 1.55
const SHOT_SPEED_MIN_PIXELS := 430.0
const SHOT_SPEED_MAX_PIXELS := 500.0

const SNIPER_STATS := [
	preload("res://entities/enemies/sniper_enemy_generation_1.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_2.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_3.tres"),
	preload("res://entities/enemies/sniper_enemy_generation_4.tres"),
]

@export var aim_material_gen2: Material
@export var aim_material_later: Material

@onready var aim_warning: MeshInstance3D = $Attachments/AimWarning
var _bracket_warnings: Array[MeshInstance3D] = []
var _bracket_shot := false
var _aim_timer := 0.0
var _locked_direction := Vector3.ZERO
var _ordinary_shots := 0
var _rail_used := false
var _visible_time := 0.0

var _screen_travel_direction := Vector2.ZERO
var _screen_perpendicular := Vector2.ZERO
var _entry_distance := 0.0
var _hold_position := Vector3.ZERO
var _hold_timer := 0.0
var _shoot_timer := 0.0
var _holding := false
var _has_withdrawn := false


func _get_generation_stats() -> GenerationStats:
	return SNIPER_STATS[generation - 1]


func _is_basic_lineage() -> bool:
	return false


func _configure_movement() -> void:
	if _bracket_warnings.is_empty():
		for index in 2:
			var warning := MeshInstance3D.new()
			warning.mesh = aim_warning.mesh
			aim_warning.get_parent().add_child(warning)
			_bracket_warnings.append(warning)
	_bracket_shot = false
	_aim_timer = 0.0
	_ordinary_shots = 0
	_rail_used = false
	_visible_time = 0.0
	_hide_aim_warning()
	aim_warning.material_override = aim_material_gen2 if generation == 2 else aim_material_later
	var envelopes := [Vector2(32, 32), Vector2(35, 34), Vector2(38, 36), Vector2(40, 38)]
	var envelope: Vector2 = envelopes[generation - 1]
	collision_shape.scale = Vector3(envelope.x / 32.0, 1.0, envelope.y / 32.0)
	_screen_travel_direction = _flight_space.combat_motion_to_screen(_heading).normalized()
	_screen_perpendicular = Vector2(-_screen_travel_direction.y, _screen_travel_direction.x)
	_entry_distance = 0.0
	_hold_position = global_position
	_hold_timer = 0.0
	_shoot_timer = randf_range(FIRST_SHOT_MIN_SECONDS, FIRST_SHOT_MAX_SECONDS)
	_holding = false
	_has_withdrawn = false
	velocity = _flight_space.screen_motion_to_combat(_screen_travel_direction * _speed_pixels)
	velocity.y = 0.0


func _advance_movement(delta: float) -> void:
	if _inside_view():
		_visible_time += delta
	if not _holding:
		var movement_speed := WITHDRAW_SPEED_PIXELS if _has_withdrawn else _speed_pixels
		var screen_motion := _screen_travel_direction * movement_speed * delta
		global_position += _flight_space.screen_motion_to_combat(screen_motion)
		global_position.y = 0.0
		_entry_distance += movement_speed * delta
		if not _has_withdrawn and _entry_distance >= ENTRY_DISTANCE_PIXELS:
			_holding = true
			_hold_position = global_position
			_hold_timer = 0.0
		return

	_hold_timer += delta
	var screen_offset := _screen_perpendicular * sin(_hold_timer * HOLD_FREQUENCY) * HOLD_AMPLITUDE_PIXELS
	global_position = _hold_position + _flight_space.screen_motion_to_combat(screen_offset)
	global_position.y = 0.0
	_update_aim_and_fire(delta)
	if _hold_timer >= (9.0 if generation >= 4 else HOLD_DURATION_SECONDS):
		_holding = false
		_has_withdrawn = true
		_aim_timer = 0.0
		_hide_aim_warning()
		rotation.y = atan2(-_heading.x, -_heading.z)
		collision_shape.global_rotation = Vector3.ZERO


func _update_aim_and_fire(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	var muzzle := sockets.get_node_or_null("MuzzleCenter") as Marker3D
	if player == null or muzzle == null:
		return
	var target_position := player.global_position
	target_position.y = 0.0
	var aim_direction := target_position - muzzle.global_position
	aim_direction.y = 0.0
	if aim_direction.is_zero_approx():
		return
	var normalized_direction := aim_direction.normalized()
	rotation.y = atan2(-normalized_direction.x, -normalized_direction.z)
	# Keep the gameplay primitive world-aligned while the visual/model aims.
	collision_shape.global_rotation = Vector3.ZERO
	if _aim_timer > 0.0:
		_update_warning(muzzle)
		_aim_timer -= delta
		if _aim_timer <= 0.0:
			_fire_locked_shot(muzzle)
		return
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	_shoot_timer = SHOT_INTERVAL_SECONDS
	_begin_aimed_shot(player, muzzle)


func _begin_aimed_shot(player: Node3D, muzzle: Marker3D) -> void:
	var can_special := _visible_time >= 0.35 and _inside_view()
	_bracket_shot = generation >= 2 and _ordinary_shots % 3 == 2 and can_special
	if generation >= 4 and _ordinary_shots >= 3 and not _rail_used and can_special:
		var hazards := get_tree().get_first_node_in_group(&"native_3d_hazard_manager") as NativeHazardManager
		if hazards != null and hazards.spawn_rail_beam(muzzle.global_position, player.global_position - muzzle.global_position, self) != null:
			_rail_used = true
			return
	var target := player.global_position
	if generation >= 2 and _ordinary_shots % 3 != 0:
		var distance := _flight_space.combat_motion_to_screen(target - global_position).length()
		var player_velocity: Vector3 = player.get("velocity")
		target += player_velocity * minf(distance / 550.0 + 0.25, 0.8)
	_locked_direction = target - muzzle.global_position
	_locked_direction.y = 0.0
	_locked_direction = _locked_direction.normalized()
	if generation >= 2 and can_special:
		_aim_timer = 0.5
		aim_warning.show()
		_update_warning(muzzle)
	else:
		_fire_locked_shot(muzzle)


func _hide_aim_warning() -> void:
	aim_warning.hide()
	for warning in _bracket_warnings:
		warning.hide()

func _update_warning(muzzle: Marker3D) -> void:
	var screen_direction := _flight_space.combat_motion_to_screen(_locked_direction).normalized()
	_position_warning(aim_warning, muzzle, screen_direction)
	for index in _bracket_warnings.size():
		var warning := _bracket_warnings[index]
		warning.visible = _bracket_shot
		warning.material_override = aim_warning.material_override
		_position_warning(warning, muzzle, screen_direction.rotated(-0.16 if index == 0 else 0.16))

func _position_warning(warning: MeshInstance3D, muzzle: Marker3D, screen_direction: Vector2) -> void:
	var along := _flight_space.screen_motion_to_combat(screen_direction)
	var across := _flight_space.screen_motion_to_combat(Vector2(-screen_direction.y, screen_direction.x))
	warning.global_transform = Transform3D(Basis(across * (2.0 if generation == 2 else 3.0), Vector3.UP, along * 900.0), Vector3(muzzle.global_position.x, 0.04, muzzle.global_position.z) + along * 450.0)


func _fire_locked_shot(muzzle: Marker3D) -> void:
	_hide_aim_warning()
	var manager := get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager
	if manager == null or not manager.is_ready or _locked_direction.is_zero_approx():
		return
	var speed := randf_range(SHOT_SPEED_MIN_PIXELS, SHOT_SPEED_MAX_PIXELS) if generation == 1 else 550.0
	manager.fire_enemy_projectile(muzzle.global_position, _locked_direction, speed)
	if _bracket_shot:
		# A bracket covers lateral escape without changing the telegraphed center.
		var screen_aim := _flight_space.combat_motion_to_screen(_locked_direction).normalized()
		for side in [-1.0, 1.0]:
			manager.fire_enemy_projectile(muzzle.global_position, _flight_space.input_to_combat_direction(screen_aim.rotated(side * 0.16)), speed * 0.8)
	_ordinary_shots += 1
	aimed_shot_fired.emit(speed)


func _inside_view() -> bool:
	return _flight_space.get_combat_bounds().has_point(Vector2(global_position.x, global_position.z))


func _finish(reason: FinishReason) -> void:
	_aim_timer = 0.0
	_hide_aim_warning()
	super._finish(reason)


func get_attack_status() -> Dictionary:
	return {"generation": generation, "ordinary_shots": _ordinary_shots,
		"aim_timer": _aim_timer, "locked_direction": _locked_direction,
		"rail_used": _rail_used, "holding": _holding}
