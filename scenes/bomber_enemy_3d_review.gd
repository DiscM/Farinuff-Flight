extends Node
class_name BomberEnemy3DReview
## Manual Bomber generation review around the actual native controller. The
## deterministic entries and counters are review controls, not a spawner.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const BomberEnemy := preload("res://entities/enemies/bomber_enemy_3d.gd")
const ENEMY_SCENE := preload("res://entities/enemies/bomber_enemy_3d.tscn")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")
const MAX_ENEMIES := 8

@onready var gameplay: NativeGame = $Gameplay
@onready var spawn_timer: Timer = $SpawnTimer
@onready var auto_spawns: CheckButton = $ReviewHUD/Panel/Controls/AutoSpawns
@onready var generation_select: OptionButton = $ReviewHUD/Panel/Controls/Generation
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var mine_status: Label = $ReviewHUD/Panel/MineStatus
@onready var guides: BasicEnemy3DReviewGuides = $ReviewHUD/Guides
@onready var _first_enemy: BomberEnemy = $Gameplay/World3D/Actors3D/FirstEnemy3D

var _review_ready := false
var _enemies: Array[BasicEnemy] = []
var _next_edge := 0
var _spawn_count := 0
var _destroyed := 0
var _contacts := 0
var _escaped := 0
var _damage_hits := 0
var _bombs_dropped := 0
var _mines_dropped := 0
var _cluster_mines_dropped := 0
var _plasma_mines_dropped := 0


func _ready() -> void:
	$ReviewHUD/Panel/Controls/Top.pressed.connect(spawn_from_edge.bind(0))
	$ReviewHUD/Panel/Controls/Right.pressed.connect(spawn_from_edge.bind(1))
	$ReviewHUD/Panel/Controls/Bottom.pressed.connect(spawn_from_edge.bind(2))
	$ReviewHUD/Panel/Controls/Left.pressed.connect(spawn_from_edge.bind(3))
	$ReviewHUD/Panel/Controls/RestoreLives.pressed.connect(restore_lives)
	generation_select.item_selected.connect(_set_generation)
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
		KEY_Q:
			generation_select.select((generation_select.selected + 1) % generation_select.item_count)
			_set_generation(generation_select.selected)
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
	var enemy: BomberEnemy
	if is_instance_valid(_first_enemy):
		enemy = _first_enemy
		_first_enemy = null
	else:
		enemy = ENEMY_SCENE.instantiate() as BomberEnemy
		gameplay.get_node("World3D/Actors3D").add_child(enemy)
	_spawn_count += 1
	enemy.name = "BomberEnemy3D_%d" % _spawn_count
	enemy.configure_hazard_manager(gameplay.hazard_manager)
	var generation := generation_select.selected + 1
	enemy.finished.connect(_on_enemy_finished.bind(enemy))
	enemy.bomb_dropped.connect(_on_bomb_dropped.bind(enemy))
	enemy.mine_dropped.connect(_on_mine_dropped.bind(enemy))
	_enemies.append(enemy)
	if not enemy.activate_generation(gameplay.flight_space, spawn_position, direction, generation):
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
	gameplay.reset_native_progression()
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


func _on_bomb_dropped(_enemy: BomberEnemy) -> void:
	_bombs_dropped += 1
	_update_status()


func _on_mine_dropped(is_cluster: bool, leaves_plasma: bool, _enemy: BomberEnemy) -> void:
	_mines_dropped += 1
	if is_cluster:
		_cluster_mines_dropped += 1
	if leaves_plasma:
		_plasma_mines_dropped += 1
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


func _set_generation(index: int) -> void:
	generation_select.select(clampi(index, 0, generation_select.item_count - 1))
	_update_status()


func _update_status() -> void:
	var immunity := "INVULNERABLE" if gameplay.player.is_invincible else "VULNERABLE"
	status.text = "GEN %d • ACT %d/%d • KILL %d • CONTACT %d • ESC %d • DAMAGE %d • BOMBS %d • LIVES %d/%d • DRIFT 120 PX/S • %s" % [
		generation_select.selected + 1, _enemies.size(), MAX_ENEMIES, _destroyed, _contacts, _escaped,
		_damage_hits, _bombs_dropped, GameManager.lives, GameManager.starting_lives, immunity,
	]
	mine_status.text = "MINE ROUTE GEN %d • DROPS %d • CLUSTER %d • PLASMA %d" % [
		generation_select.selected + 1, _mines_dropped, _cluster_mines_dropped, _plasma_mines_dropped,
	]
