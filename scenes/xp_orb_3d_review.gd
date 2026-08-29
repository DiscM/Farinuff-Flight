extends Node
class_name XPOrb3DReview
## Manual native XP Orb review around the actual pooled wrapper and global XP
## signal. Controls are deterministic review fixtures, not a production drop
## spawner.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const XPOrbManager := preload("res://systems/xp_orb_manager_3d.gd")

@onready var gameplay: NativeGame = $Gameplay
@onready var orb_manager: XPOrbManager = $XPOrbManager3D
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var spawn_value_1: Button = $ReviewHUD/Panel/Controls/Value1
@onready var spawn_value_2: Button = $ReviewHUD/Panel/Controls/Value2
@onready var spawn_value_3: Button = $ReviewHUD/Panel/Controls/Value3
@onready var contact_spawn: Button = $ReviewHUD/Panel/Controls/Contact
@onready var clear_orbs_button: Button = $ReviewHUD/Panel/Controls/Clear
@onready var restore_button: Button = $ReviewHUD/Panel/Controls/Restore

var _review_ready := false
var _collected := 0
var _last_value := 0
var _spawn_count := 0


func _ready() -> void:
	spawn_value_1.pressed.connect(spawn_value.bind(1))
	spawn_value_2.pressed.connect(spawn_value.bind(2))
	spawn_value_3.pressed.connect(spawn_value.bind(3))
	contact_spawn.pressed.connect(spawn_contact)
	clear_orbs_button.pressed.connect(clear_orbs)
	restore_button.pressed.connect(restore_run)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	orb_manager.configure(
		gameplay.flight_space,
		gameplay.get_node("World3D/Actors3D"),
		gameplay.get_node("World3D/PoolRoot3D")
	)
	if not await orb_manager.warm_orb_pool():
		status.text = "XP ORB POOL PREPARATION FAILED — SEE DEBUGGER"
		return
	_review_ready = true
	orb_manager.xp_orb_collected.connect(_on_orb_collected)
	spawn_edge(1)
	_update_status()


func _process(_delta: float) -> void:
	if _review_ready:
		_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			spawn_value(1)
		KEY_2:
			spawn_value(2)
		KEY_3:
			spawn_value(3)
		KEY_C:
			spawn_contact()
		KEY_X:
			clear_orbs()
		KEY_R:
			restore_run()
		_:
			return
	get_viewport().set_input_as_handled()


func spawn_value(value: int) -> void:
	if not _review_ready or get_tree().paused:
		return
	var screen_offset := Vector2(-96.0 if value % 2 == 0 else 96.0, -24.0)
	_spawn_near_player(value, screen_offset)


func spawn_contact() -> void:
	if not _review_ready or get_tree().paused:
		return
	_spawn_near_player(1, Vector2(16.0, 0.0))


func _spawn_near_player(value: int, screen_offset: Vector2) -> void:
	var offset := gameplay.flight_space.screen_motion_to_combat(screen_offset)
	var direction := gameplay.flight_space.input_to_combat_direction(Vector2.DOWN)
	_spawn_orb(gameplay.player.global_position + offset, value, direction)


func spawn_edge(value: int) -> void:
	if not _review_ready or get_tree().paused:
		return
	var bounds := gameplay.flight_space.get_combat_bounds(
		gameplay.flight_space.configuration.spawn_margin_pixels
	)
	var center := bounds.get_center()
	_spawn_orb(
		Vector3(center.x, 0.0, bounds.position.y),
		value,
		Vector3.BACK
	)


func _spawn_orb(combat_position: Vector3, value: int, direction: Vector3) -> void:
	var orb := orb_manager.spawn_xp_orb(combat_position, value, direction)
	if orb != null:
		_spawn_count += 1
		orb.name = "XPOrb3D_%d" % _spawn_count
	_update_status()


func clear_orbs() -> void:
	if not _review_ready:
		return
	orb_manager.clear_orbs()
	_update_status()


func restore_run() -> void:
	if not _review_ready:
		return
	clear_orbs()
	GameManager.start_game(false)
	_collected = 0
	_last_value = 0
	_update_status()


func _on_orb_collected(value: int, _combat_position: Vector3) -> void:
	_collected += 1
	_last_value = value
	_update_status()


func _update_status() -> void:
	var metrics := orb_manager.get_metrics()
	status.text = "ACT %d/%d • COLLECTED %d • LAST +%d • METER %d/%d • LIVES %d/%d • GROWTH %d" % [
		metrics["active"], metrics["pool_size"], _collected, _last_value,
		GameManager.orbs_collected, GameManager.orbs_per_heart,
		GameManager.lives, GameManager.starting_lives, metrics["pool_growth_after_warmup"],
	]
