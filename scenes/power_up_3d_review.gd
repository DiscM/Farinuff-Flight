extends Node
class_name PowerUp3DReview
## Manual native PowerUp review around the actual pooled wrapper, manager,
## global collection signal, and Player3D effect application.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const PowerUpTypes := preload("res://entities/powerups/power_up_types.gd")
const PowerUpManager := preload("res://systems/power_up_manager_3d.gd")

@onready var gameplay: NativeGame = $Gameplay
@onready var power_up_manager: PowerUpManager = $Gameplay/GameplayManagers/PowerUpManager3D
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var effect_status: Label = $ReviewHUD/Panel/EffectStatus

var _review_ready := false
var _spawned := 0
var _collected := 0
var _last_type := -1


func _ready() -> void:
	var controls := $ReviewHUD/Panel/Controls
	for index in range(6):
		var button := controls.get_node("Type%d" % index) as Button
		button.pressed.connect(spawn_type.bind(index))
	controls.get_node("Contact").pressed.connect(collect_type)
	controls.get_node("Clear").pressed.connect(clear_power_ups)
	controls.get_node("Restore").pressed.connect(restore_run)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	power_up_manager.power_up_collected.connect(_on_power_up_collected)
	_update_status()


func _process(_delta: float) -> void:
	if _review_ready:
		_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			spawn_type(event.keycode - KEY_1)
		KEY_C:
			collect_type()
		KEY_X:
			clear_power_ups()
		KEY_R:
			restore_run()
		_:
			return
	get_viewport().set_input_as_handled()


func spawn_type(power_up_type: int) -> void:
	if not _review_ready or get_tree().paused:
		return
	var screen_offset := Vector2(-96.0 if power_up_type % 2 == 0 else 96.0, -72.0)
	var combat_offset := gameplay.flight_space.screen_motion_to_combat(screen_offset)
	var direction := gameplay.flight_space.input_to_combat_direction(Vector2.DOWN)
	_spawn_power_up(gameplay.player.global_position + combat_offset, power_up_type, direction)


func collect_type() -> void:
	if not _review_ready or get_tree().paused:
		return
	var next_type := _last_type if _last_type >= 0 else PowerUpTypes.Type.SCALE_UP
	_spawn_power_up(gameplay.player.global_position, next_type, Vector3.BACK)


func _spawn_power_up(combat_position: Vector3, power_up_type: int, direction: Vector3) -> void:
	var power_up := power_up_manager.spawn_power_up(combat_position, power_up_type, direction)
	if power_up != null:
		_spawned += 1
		power_up.name = "PowerUp3D_%d" % _spawned
	_update_status()


func clear_power_ups() -> void:
	if not _review_ready:
		return
	power_up_manager.clear_power_ups()
	_update_status()


func restore_run() -> void:
	if not _review_ready:
		return
	gameplay.reset_native_progression()
	_collected = 0
	_last_type = -1
	_update_status()


func _on_power_up_collected(power_up_type: int, _combat_position: Vector3) -> void:
	_collected += 1
	_last_type = power_up_type
	_update_status()


func _update_status() -> void:
	var metrics := power_up_manager.get_metrics()
	var last_label := "—" if _last_type < 0 else _type_label(_last_type)
	status.text = "ACTIVE %d/%d • SPAWNED %d • COLLECTED %d • LAST %s • GROWTH %d • LIVES %d/%d" % [
		metrics["active"], metrics["pool_size"], _spawned, _collected, last_label,
		metrics["pool_growth_after_warmup"], GameManager.lives, GameManager.starting_lives,
	]
	var state := gameplay.player.get_power_up_status()
	effect_status.text = "SCALE %d • SHIELD %s • RAPID %.1fs • SPREAD %.1fs • MAGNET %.1fs • PROJECTILE ×%.1f" % [
		state["scale"], "ON" if state["shield"] else "OFF",
		state["rapid_remaining"], state["spread_remaining"], state["magnet_remaining"],
		gameplay.player.get_projectile_scale(),
	]


func _type_label(power_up_type: int) -> String:
	return ["S+", "RAPID", "SHIELD", "SPREAD", "MAGNET", "NUKE"][clampi(power_up_type, 0, 5)]
