extends Node
class_name SniperEnemy3DReview
## Manual Generation I Sniper review around the actual native controller.
## The deterministic entries and counters are review controls, not a spawner.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const SniperEnemy := preload("res://entities/enemies/sniper_enemy_3d.gd")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const ENEMY_SCENE := preload("res://entities/enemies/sniper_enemy_3d.tscn")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")
const MAX_ENEMIES := 8

@onready var gameplay: NativeGame = $Gameplay
@onready var spawn_timer: Timer = $SpawnTimer
@onready var auto_spawns: CheckButton = $ReviewHUD/Panel/Controls/AutoSpawns
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var guides: BasicEnemy3DReviewGuides = $ReviewHUD/Guides
@onready var _first_enemy: SniperEnemy = $Gameplay/World3D/Actors3D/FirstEnemy3D

var _review_ready := false
var _enemies: Array[BasicEnemy] = []
var _next_edge := 0
var _spawn_count := 0
var _destroyed := 0
var _contacts := 0
var _escaped := 0
var _damage_hits := 0
var _shots_fired := 0
var _last_shot_speed := 0.0


func _ready() -> void:
	$ReviewHUD/Panel/Controls/Top.pressed.connect(spawn_from_edge.bind(0))
	$ReviewHUD/Panel/Controls/Right.pressed.connect(spawn_from_edge.bind(1))
	$ReviewHUD/Panel/Controls/Bottom.pressed.connect(spawn_from_edge.bind(2))
	$ReviewHUD/Panel/Controls/Left.pressed.connect(spawn_from_edge.bind(3))
	$ReviewHUD/Panel/Controls/RestoreLives.pressed.connect(restore_lives)
	auto_spawns.toggled.connect(_set_auto_spawns)
	spawn_timer.timeout.connect(_spawn_next)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	guides.configure(gameplay.flight_space, _enemies)
	gameplay.player.damage_taken.connect(_on_player_damage_taken)
	gameplay.player.invulnerability_changed.connect(_on_invulnerability_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	_spawn_next()
	_set_auto_spawns(auto_spawns.button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			spawn_from_edge(event.keycode - KEY_1)
		KEY_V:
			auto_spawns.button_pressed = not auto_spawns.button_pressed
		KEY_H:
			guides.show_hitboxes = not guides.show_hitboxes
		KEY_G:
			guides.show_sockets = not guides.show_sockets
		KEY_R:
			restore_lives()
		_:
			return
	get_viewport().set_input_as_handled()


func spawn_from_edge(edge: int) -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused or _enemies.size() >= MAX_ENEMIES:
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
	var enemy: SniperEnemy
	if is_instance_valid(_first_enemy):
		enemy = _first_enemy
		_first_enemy = null
	else:
		enemy = ENEMY_SCENE.instantiate() as SniperEnemy
		gameplay.get_node("World3D/Actors3D").add_child(enemy)
	_spawn_count += 1
	enemy.name = "SniperEnemy3D_%d" % _spawn_count
	enemy.finished.connect(_on_enemy_finished.bind(enemy))
	enemy.aimed_shot_fired.connect(_on_aimed_shot_fired.bind(enemy))
	_enemies.append(enemy)
	if not enemy.activate(gameplay.flight_space, spawn_position, direction):
		_enemies.erase(enemy)
		enemy.queue_free()
	_update_status()


func _spawn_next() -> void:
	spawn_from_edge(_next_edge)
	_next_edge = (_next_edge + 1) % 4


func _set_auto_spawns(enabled: bool) -> void:
	if _review_ready and enabled:
		spawn_timer.start()
	else:
		spawn_timer.stop()


func restore_lives() -> void:
	for node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var projectile := node as Projectile
		if projectile != null:
			projectile.despawn()
	GameManager.start_game(false)
	gameplay.player.reset_damage_state()
	_update_status()


func _on_enemy_finished(reason: BasicEnemy.FinishReason, _combat_position: Vector3, enemy: BasicEnemy) -> void:
	_enemies.erase(enemy)
	match reason:
		BasicEnemy.FinishReason.DESTROYED:
			_destroyed += 1
		BasicEnemy.FinishReason.CONTACT:
			_contacts += 1
		BasicEnemy.FinishReason.ESCAPED:
			_escaped += 1
	_update_status()


func _on_aimed_shot_fired(speed_pixels: float, _enemy: SniperEnemy) -> void:
	_shots_fired += 1
	_last_shot_speed = speed_pixels
	_update_status()


func _on_player_damage_taken(
	_combat_position: Vector3,
	_source: PlayerCraft.DamageSource,
	_remaining_lives: int
) -> void:
	_damage_hits += 1
	_update_status()


func _on_invulnerability_changed(_active: bool) -> void:
	_update_status()


func _on_lives_changed(_new_lives: int) -> void:
	_update_status()


func _update_status() -> void:
	var immunity := "INVULNERABLE" if gameplay.player.is_invincible else "VULNERABLE"
	status.text = "ACT %d/%d • KILL %d • SHOTS %d • LAST %.0f PX/S • CONTACT %d • ESC %d • DMG %d • LIVES %d/%d • HOLD 6 S • %s" % [
		_enemies.size(), MAX_ENEMIES, _destroyed, _shots_fired, _last_shot_speed,
		_contacts, _escaped, _damage_hits, GameManager.lives,
		GameManager.starting_lives, immunity,
	]
