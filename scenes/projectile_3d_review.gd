extends Node
class_name Projectile3DReview
## Manual incoming-projectile damage, boost-deflection, and chain review around
## the actual native scene. A deterministic Gen I target verifies return hits.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const EnemyTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const ENEMY_SCENE := preload("res://entities/enemies/basic_enemy_3d.tscn")
const GUIDE_SEGMENTS := 64
const MAX_TARGETS := 4

@onready var gameplay: NativeGame = $Gameplay
@onready var volley_timer: Timer = $VolleyTimer
@onready var auto_volleys: CheckButton = $ReviewHUD/Panel/Controls/AutoVolleys
@onready var contact_status: Label = $ReviewHUD/Panel/ContactStatus
@onready var interaction_guide: Line2D = $ReviewHUD/InteractionGuide
@onready var hysteresis_guide: Line2D = $ReviewHUD/HysteresisGuide
@onready var _first_target: BasicEnemy = $Gameplay/World3D/Actors3D/FirstReflectionTarget3D

var _review_ready := false
var _contacts := 0
var _damage_hits := 0
var _deflections := 0
var _reflected_hits := 0
var _target_kills := 0
var _target_spawn_count := 0
var _targets: Array[BasicEnemy] = []
var _show_guides := true
var _inner_offsets := PackedVector3Array()
var _outer_offsets := PackedVector3Array()
var _inner_points := PackedVector2Array()
var _outer_points := PackedVector2Array()


func _ready() -> void:
	$ReviewHUD/Panel/Controls/NormalVolley.pressed.connect(fire_normal_volley)
	$ReviewHUD/Panel/Controls/FastVolley.pressed.connect(fire_fast_volley)
	$ReviewHUD/Panel/Controls/ChainBurst.pressed.connect(fire_chain_burst)
	$ReviewHUD/Panel/Controls/RestoreLives.pressed.connect(restore_lives)
	auto_volleys.toggled.connect(_set_auto_volleys)
	volley_timer.timeout.connect(fire_normal_volley)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	gameplay.projectile_manager.enemy_projectile_hit.connect(_on_enemy_projectile_hit)
	gameplay.projectile_manager.enemy_projectile_deflected.connect(_on_enemy_projectile_deflected)
	gameplay.projectile_manager.deflected_projectile_hit.connect(_on_deflected_projectile_hit)
	gameplay.player.damage_taken.connect(_on_player_damage_taken)
	gameplay.player.invulnerability_changed.connect(_on_invulnerability_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	_first_target.hide()
	_prepare_guides()
	_set_auto_volleys(auto_volleys.button_pressed)
	_update_contact_status()


func _process(_delta: float) -> void:
	if not _review_ready:
		return
	_update_contact_status()
	if not _show_guides:
		return
	var player_position := gameplay.player.global_position
	for index in range(GUIDE_SEGMENTS + 1):
		_inner_points[index] = gameplay.flight_space.combat_to_screen(player_position + _inner_offsets[index])
		_outer_points[index] = gameplay.flight_space.combat_to_screen(player_position + _outer_offsets[index])
	interaction_guide.points = _inner_points
	hysteresis_guide.points = _outer_points


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			fire_normal_volley()
		KEY_2:
			fire_fast_volley()
		KEY_3:
			fire_chain_burst()
		KEY_V:
			auto_volleys.button_pressed = not auto_volleys.button_pressed
		KEY_H:
			_show_guides = not _show_guides
			interaction_guide.visible = _show_guides
			hysteresis_guide.visible = _show_guides
		KEY_R:
			restore_lives()
		_:
			return
	get_viewport().set_input_as_handled()


func fire_normal_volley() -> void:
	_fire_volley(EnemyTuning.DEFAULT_SPEED)


func fire_fast_volley() -> void:
	# Deliberate manual collision stress, not a change to enemy balance.
	_fire_volley(EnemyTuning.DEFAULT_SPEED * 6.0)


## Fires three tightly grouped incoming projectiles from 180 baseline pixels
## above the Player and places a real Gen I target behind them. Boost after
## pressing 3 to earn a chain and send at least one projectile into the target.
func fire_chain_burst() -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused:
		return
	_spawn_reflection_target()
	var origin := gameplay.player.global_position + gameplay.flight_space.screen_motion_to_combat(
		Vector2(0.0, -180.0)
	)
	origin = gameplay.flight_space.clamp_to_combat_plane(origin)
	for lane in range(-1, 2):
		var offset := gameplay.flight_space.screen_motion_to_combat(Vector2(float(lane) * 28.0, 0.0))
		gameplay.projectile_manager.fire_enemy_projectile(
			origin + offset, Vector3.BACK, EnemyTuning.DEFAULT_SPEED
		)


func _fire_volley(speed_pixels: float) -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused:
		return
	var bounds := gameplay.flight_space.get_combat_bounds()
	var top_inset := gameplay.flight_space.screen_motion_to_combat(Vector2(0.0, 24.0))
	var origin := Vector3(bounds.get_center().x, 0.0, bounds.position.y + top_inset.z)
	for lane in range(-3, 4):
		var offset := gameplay.flight_space.screen_motion_to_combat(Vector2(float(lane) * 100.0, 0.0))
		gameplay.projectile_manager.fire_enemy_projectile(origin + offset, Vector3.BACK, speed_pixels)


func _set_auto_volleys(enabled: bool) -> void:
	if _review_ready and enabled:
		volley_timer.start()
	else:
		volley_timer.stop()


func restore_lives() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var projectile := node as Projectile
		if projectile != null:
			projectile.despawn()
	GameManager.start_game(false)
	gameplay.player.reset_damage_state()
	_update_contact_status()


func _spawn_reflection_target() -> void:
	if _targets.size() >= MAX_TARGETS:
		return
	var enemy: BasicEnemy
	if is_instance_valid(_first_target):
		enemy = _first_target
		_first_target = null
	else:
		enemy = ENEMY_SCENE.instantiate() as BasicEnemy
		gameplay.get_node("World3D/Actors3D").add_child(enemy)
	_target_spawn_count += 1
	enemy.name = "ReflectionTarget3D_%d" % _target_spawn_count
	enemy.finished.connect(_on_target_finished.bind(enemy))
	_targets.append(enemy)
	var target_position := gameplay.player.global_position + gameplay.flight_space.screen_motion_to_combat(
		Vector2(0.0, -300.0)
	)
	target_position = gameplay.flight_space.clamp_to_combat_plane(target_position)
	enemy.show()
	if not enemy.activate(gameplay.flight_space, target_position, Vector3.BACK):
		_targets.erase(enemy)
		enemy.queue_free()


func _on_enemy_projectile_hit(_target: Area3D, _combat_position: Vector3) -> void:
	_contacts += 1
	_update_contact_status()


func _on_enemy_projectile_deflected(
	_projectile: Area3D,
	_combat_position: Vector3
) -> void:
	_deflections += 1
	_update_contact_status()


func _on_deflected_projectile_hit(_target: Area3D, _combat_position: Vector3) -> void:
	_reflected_hits += 1
	_update_contact_status()


func _on_target_finished(
	reason: BasicEnemy.FinishReason,
	_combat_position: Vector3,
	enemy: BasicEnemy
) -> void:
	_targets.erase(enemy)
	match reason:
		BasicEnemy.FinishReason.DESTROYED:
			_target_kills += 1
	_update_contact_status()


func _on_player_damage_taken(
	_combat_position: Vector3,
	_source: PlayerCraft.DamageSource,
	_remaining_lives: int
) -> void:
	_damage_hits += 1
	_update_contact_status()


func _on_invulnerability_changed(_active: bool) -> void:
	_update_contact_status()


func _on_lives_changed(_new_lives: int) -> void:
	_update_contact_status()


func _update_contact_status() -> void:
	var immunity := "INVULNERABLE" if gameplay.player.is_invincible else "VULNERABLE"
	var chain := "READY" if (
		gameplay.player.boost_reflected_projectiles >= FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD
	) else "%d/%d" % [
		gameplay.player.boost_reflected_projectiles,
		FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD,
	]
	contact_status.text = "HIT %d • DMG %d • DEFLECT %d • RETURN %d • KILL %d • LIVES %d • %s • CHAIN %s" % [
		_contacts, _damage_hits, _deflections, _reflected_hits, _target_kills,
		GameManager.lives, immunity, chain,
	]


func _prepare_guides() -> void:
	var radius := gameplay.projectile_manager.interaction_range_pixels
	var outer_radius := radius + gameplay.projectile_manager.interaction_hysteresis_pixels
	$ReviewHUD/Panel/Legend.text = "%.0f PX BASE RANGE  •  %.0f PX HYSTERESIS  •  SPEED MARGIN ADDED WHEN MOVING" % [
		radius, gameplay.projectile_manager.interaction_hysteresis_pixels,
	]
	_inner_offsets.resize(GUIDE_SEGMENTS + 1)
	_outer_offsets.resize(GUIDE_SEGMENTS + 1)
	_inner_points.resize(GUIDE_SEGMENTS + 1)
	_outer_points.resize(GUIDE_SEGMENTS + 1)
	for index in range(GUIDE_SEGMENTS + 1):
		var direction := Vector2.from_angle(TAU * float(index) / float(GUIDE_SEGMENTS))
		_inner_offsets[index] = gameplay.flight_space.screen_motion_to_combat(direction * radius)
		_outer_offsets[index] = gameplay.flight_space.screen_motion_to_combat(direction * outer_radius)
