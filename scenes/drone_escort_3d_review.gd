extends Node
class_name DroneEscort3DReview
## Manual review around the native Drone Escort wrapper and its shared
## projectile/contact routes. Targets are deterministic review fixtures, not a
## production enemy spawner.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const PlayerDrone := preload("res://entities/player/player_drone_3d.gd")
const ReviewGuides := preload("res://scenes/drone_escort_3d_review_guides.gd")
const ENEMY_SCENE := preload("res://entities/enemies/basic_enemy_3d.tscn")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")

@onready var gameplay: NativeGame = $Gameplay
@onready var drone_toggle: CheckButton = $ReviewHUD/Panel/Controls/DroneToggle
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var detail: Label = $ReviewHUD/Panel/Detail
@onready var guides: ReviewGuides = $ReviewHUD/Guides
@onready var _first_target: BasicEnemy = $Gameplay/World3D/Actors3D/FirstTarget3D

const MAX_TARGETS := 4

var _review_ready := false
var _targets: Array[BasicEnemy] = []
var _spawn_count := 0
var _destroyed := 0
var _contacts := 0
var _escaped := 0
var _drone_signal_shots := 0
var _drone_signal_contacts := 0


func _ready() -> void:
	$ReviewHUD/Panel/Controls/Top.pressed.connect(spawn_from_edge.bind(0))
	$ReviewHUD/Panel/Controls/Right.pressed.connect(spawn_from_edge.bind(1))
	$ReviewHUD/Panel/Controls/Bottom.pressed.connect(spawn_from_edge.bind(2))
	$ReviewHUD/Panel/Controls/Left.pressed.connect(spawn_from_edge.bind(3))
	$ReviewHUD/Panel/Controls/NearTarget.pressed.connect(spawn_near_target)
	$ReviewHUD/Panel/Controls/ContactTarget.pressed.connect(spawn_contact_target)
	$ReviewHUD/Panel/Controls/Clear.pressed.connect(clear_targets)
	$ReviewHUD/Panel/Controls/Restore.pressed.connect(restore_review)
	drone_toggle.toggled.connect(_set_drone_enabled)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	guides.configure(gameplay.flight_space)
	gameplay.drone_fired.connect(_on_drone_fired)
	gameplay.drone_contact_hit.connect(_on_drone_contact_hit)
	if drone_toggle.button_pressed:
		_set_drone_enabled(true)
	else:
		gameplay.set_drone_escort_enabled(false)
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			spawn_from_edge(event.keycode - KEY_1)
		KEY_T:
			spawn_near_target()
		KEY_C:
			spawn_contact_target()
		KEY_D:
			drone_toggle.button_pressed = not drone_toggle.button_pressed
		KEY_H:
			guides.show_hitbox = not guides.show_hitbox
			_update_status()
		KEY_S:
			guides.show_sockets = not guides.show_sockets
			_update_status()
		KEY_X:
			clear_targets()
		KEY_R:
			restore_review()
		_:
			return
	get_viewport().set_input_as_handled()


func _set_drone_enabled(enabled: bool) -> void:
	if not _review_ready:
		return
	gameplay.set_drone_escort_enabled(enabled)
	_update_status()


func _ensure_drone() -> PlayerDrone:
	if gameplay.get_drone() == null:
		gameplay.set_drone_escort_enabled(true)
		drone_toggle.set_pressed_no_signal(true)
	return gameplay.get_drone()


func spawn_from_edge(edge: int) -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused or _targets.size() >= MAX_TARGETS:
		return
	var bounds := gameplay.flight_space.get_combat_bounds(SpawnTuning.SPAWN_MARGIN)
	var center := bounds.get_center()
	var spawn_position: Vector3
	var direction: Vector3
	match posmod(edge, 4):
		0:
			spawn_position = Vector3(center.x, 0.0, bounds.position.y)
			direction = Vector3.BACK
		1:
			spawn_position = Vector3(bounds.end.x, 0.0, center.y)
			direction = Vector3.LEFT
		2:
			spawn_position = Vector3(center.x, 0.0, bounds.end.y)
			direction = Vector3.FORWARD
		3:
			spawn_position = Vector3(bounds.position.x, 0.0, center.y)
			direction = Vector3.RIGHT
	_spawn_target(spawn_position, direction)


func spawn_near_target() -> void:
	if not _review_ready or get_tree().paused or _targets.size() >= MAX_TARGETS:
		return
	var drone := _ensure_drone()
	if drone == null:
		return
	var offset := gameplay.flight_space.screen_motion_to_combat(Vector2(0.0, -120.0))
	_spawn_target(drone.get_combat_position() + offset, Vector3.BACK)


func spawn_contact_target() -> void:
	if not _review_ready or get_tree().paused or _targets.size() >= MAX_TARGETS:
		return
	var drone := _ensure_drone()
	if drone == null:
		return
	_spawn_target(drone.get_combat_position(), Vector3.BACK)


func _spawn_target(spawn_position: Vector3, direction: Vector3) -> void:
	var target: BasicEnemy
	if is_instance_valid(_first_target):
		target = _first_target
		_first_target = null
	else:
		target = ENEMY_SCENE.instantiate() as BasicEnemy
		$Gameplay/World3D/Actors3D.add_child(target)
	_spawn_count += 1
	target.name = "DroneReviewTarget_%d" % _spawn_count
	target.finished.connect(_on_target_finished.bind(target))
	_targets.append(target)
	if not target.activate_generation(gameplay.flight_space, spawn_position, direction, 1):
		_targets.erase(target)
		target.queue_free()
	_update_status()


func clear_targets() -> void:
	if not _review_ready:
		return
	for target in _targets.duplicate():
		if is_instance_valid(target) and target.is_active:
			target._finish(BasicEnemy.FinishReason.ESCAPED)
	_targets.clear()
	_update_status()


func restore_review() -> void:
	if not _review_ready:
		return
	drone_toggle.set_pressed_no_signal(false)
	gameplay.set_drone_escort_enabled(false)
	clear_targets()
	gameplay.reset_native_progression()
	_spawn_count = 0
	_destroyed = 0
	_contacts = 0
	_escaped = 0
	_drone_signal_shots = 0
	_drone_signal_contacts = 0
	_update_status()


func _on_target_finished(reason: BasicEnemy.FinishReason, _combat_position: Vector3, target: BasicEnemy) -> void:
	_targets.erase(target)
	match reason:
		BasicEnemy.FinishReason.DESTROYED:
			_destroyed += 1
		BasicEnemy.FinishReason.CONTACT:
			_contacts += 1
		BasicEnemy.FinishReason.ESCAPED:
			_escaped += 1
	_update_status()


func _on_drone_fired(_combat_position: Vector3, _direction: Vector3) -> void:
	_drone_signal_shots += 1
	_update_status()


func _on_drone_contact_hit(_target: Area3D, _combat_position: Vector3) -> void:
	_drone_signal_contacts += 1
	_update_status()


func _update_status() -> void:
	if not _review_ready:
		return
	var drone_status := gameplay.get_drone_status()
	var pool_metrics := gameplay.projectile_manager.get_metrics()
	var player_pool_growth := int(pool_metrics["player"]["pool_growth_after_warmup"])
	status.text = "DRONE %s • TARGETS %d/%d • SHOTS %d • CONTACT HITS %d • KILLS %d • ESCAPED %d • GROWTH %d • LIVES %d/%d" % [
		"ON" if drone_status["active"] else "OFF",
		_targets.size(), MAX_TARGETS, _drone_signal_shots, _drone_signal_contacts,
		_destroyed, _escaped, player_pool_growth, GameManager.lives, GameManager.starting_lives,
	]
	detail.text = "HOVER %+d,%+d PX • FIRE %.2f S • H HITBOX: %s • S SOCKETS: %s • TARGET CONTACTS %d" % [
		int(drone_status["hover_offset_pixels"].x), int(drone_status["hover_offset_pixels"].y),
		drone_status["fire_interval"], "ON" if guides.show_hitbox else "OFF",
		"ON" if guides.show_sockets else "OFF", _contacts,
	]
