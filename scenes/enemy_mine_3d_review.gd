extends Node
class_name EnemyMine3DReview
## Manual review around the native pooled mine, its radial payload, and the
## optional plasma field. Controls are deterministic fixtures, not a spawner.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const Mine := preload("res://entities/enemies/enemy_mine_3d.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const PlayerCraft := preload("res://entities/player/player_3d.gd")

@onready var gameplay: NativeGame = $Gameplay
@onready var hazard_manager: NativeHazardManager = $Gameplay/GameplayManagers/NativeHazardManager3D
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var spawn_mine_button: Button = $ReviewHUD/Panel/Controls/Mine
@onready var spawn_cluster_button: Button = $ReviewHUD/Panel/Controls/Cluster
@onready var spawn_plasma_button: Button = $ReviewHUD/Panel/Controls/ClusterPlasma
@onready var fragment_button: Button = $ReviewHUD/Panel/Controls/Fragment
@onready var contact_button: Button = $ReviewHUD/Panel/Controls/Contact
@onready var detonate_button: Button = $ReviewHUD/Panel/Controls/Detonate
@onready var clear_button: Button = $ReviewHUD/Panel/Controls/Clear
@onready var nuke_button: Button = $ReviewHUD/Panel/Controls/Nuke
@onready var restore_button: Button = $ReviewHUD/Panel/Controls/Restore
@onready var coordinator_status: Label = $ReviewHUD/Panel/Coordinator

var _review_ready := false
var _spawned := 0
var _detonated := 0
var _cluster_detonated := 0
var _plasma_detonations := 0
var _fragment_spawns := 0
var _nukes := 0
var _damage_hits := 0
var _last_mine: Mine


func _ready() -> void:
	spawn_mine_button.pressed.connect(spawn_mine)
	spawn_cluster_button.pressed.connect(spawn_cluster)
	spawn_plasma_button.pressed.connect(spawn_cluster_plasma)
	fragment_button.pressed.connect(spawn_fragment)
	contact_button.pressed.connect(spawn_contact)
	detonate_button.pressed.connect(detonate_latest)
	clear_button.pressed.connect(clear_hazards)
	nuke_button.pressed.connect(nuke_hazards)
	restore_button.pressed.connect(restore_run)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	hazard_manager.mine_detonated.connect(_on_mine_detonated)
	gameplay.player.damage_taken.connect(_on_player_damage_taken)
	_update_status()


func _process(_delta: float) -> void:
	if _review_ready:
		_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			spawn_mine()
		KEY_2:
			spawn_cluster()
		KEY_3:
			spawn_cluster_plasma()
		KEY_F:
			spawn_fragment()
		KEY_C:
			spawn_contact()
		KEY_D:
			detonate_latest()
		KEY_X:
			clear_hazards()
		KEY_N:
			nuke_hazards()
		KEY_R:
			restore_run()
		_:
			return
	get_viewport().set_input_as_handled()


func spawn_mine() -> void:
	_spawn_near_player(false, false, Vector2(148.0, -48.0))


func spawn_cluster() -> void:
	_spawn_near_player(true, false, Vector2(148.0, 48.0))


func spawn_cluster_plasma() -> void:
	_spawn_near_player(true, true, Vector2(-148.0, -48.0))


func spawn_contact() -> void:
	_spawn_near_player(false, false, Vector2.ZERO)


func spawn_fragment() -> void:
	if not _review_ready or get_tree().paused or not GameManager.is_game_active:
		return
	var spawn_position := gameplay.player.global_position + gameplay.flight_space.screen_motion_to_combat(Vector2(-148.0, 48.0))
	var fragment := hazard_manager.spawn_seeker_fragment(spawn_position, Vector3.BACK)
	if fragment != null:
		_fragment_spawns += 1
	_update_status()


func _spawn_near_player(cluster: bool, leaves_plasma: bool, screen_offset: Vector2) -> void:
	if not _review_ready or get_tree().paused or not GameManager.is_game_active:
		return
	var spawn_position := gameplay.player.global_position + gameplay.flight_space.screen_motion_to_combat(screen_offset)
	_last_mine = hazard_manager.spawn_mine(spawn_position, cluster, leaves_plasma)
	if _last_mine != null:
		_spawned += 1
		_last_mine.name = "EnemyMine3D_%d" % _spawned
	_update_status()


func detonate_latest() -> void:
	if is_instance_valid(_last_mine) and _last_mine.is_active:
		_last_mine.detonate_for_review()


func clear_hazards() -> void:
	if not _review_ready:
		return
	hazard_manager.clear_hazards()
	gameplay.projectile_manager.clear_projectiles()
	_update_status()


func nuke_hazards() -> void:
	if not _review_ready or get_tree().paused or not GameManager.is_game_active:
		return
	gameplay.player.apply_nuke()
	_nukes += 1
	_update_status()


func restore_run() -> void:
	if not _review_ready:
		return
	gameplay.reset_native_progression()
	_spawned = 0
	_detonated = 0
	_cluster_detonated = 0
	_plasma_detonations = 0
	_fragment_spawns = 0
	_nukes = 0
	_damage_hits = 0
	_last_mine = null
	_update_status()


func _on_mine_detonated(_combat_position: Vector3, is_cluster: bool, leaves_plasma: bool) -> void:
	_detonated += 1
	if is_cluster:
		_cluster_detonated += 1
	if leaves_plasma:
		_plasma_detonations += 1
	_update_status()


func _on_player_damage_taken(
	_combat_position: Vector3,
	_source: PlayerCraft.DamageSource,
	_remaining_lives: int
) -> void:
	_damage_hits += 1
	_update_status()


func _update_status() -> void:
	var metrics := hazard_manager.get_metrics()
	var projectile_metrics := gameplay.projectile_manager.get_metrics()
	var enemy_projectiles: Dictionary = projectile_metrics["enemy"]
	status.text = "MINE %d/%d • FIELD %d/%d • FRAG %d/%d • FSPAWN %d • SPAWN %d • DET %d • CLUSTER %d • PLASMA %d • NUKE %d • PAYLOAD %d • DAMAGE %d • LIVES %d/%d • GROWTH F%d/M%d/P%d" % [
		metrics["mine_active"], metrics["mine_pool_size"],
		metrics["field_active"], metrics["field_pool_size"],
		metrics["fragment_active"], metrics["pool_size"],
		_fragment_spawns, _spawned, _detonated, _cluster_detonated, _plasma_detonations, _nukes,
		enemy_projectiles["shots_fired"], _damage_hits,
		GameManager.lives, GameManager.starting_lives,
		metrics["fragment_pool_growth_after_warmup"],
		metrics["mine_pool_growth_after_warmup"],
		metrics["field_pool_growth_after_warmup"],
	]
	coordinator_status.text = "CAPS  " + gameplay.special_attack_coordinator.get_debug_state()
