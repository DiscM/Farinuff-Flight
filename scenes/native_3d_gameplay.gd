extends Node
class_name Native3DGameplay
## Isolated native Player Craft flight-controls slice.
## Weapons, enemies, damage, and encounter coordinators arrive in later slices.

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")

@onready var hud: CanvasLayer = $HUD
@onready var player: PlayerCraft = $World3D/Actors3D/Player3D
@onready var flight_space: FlightSpace = $FlightSpace3D
@onready var aim_reticle: Sprite2D = $HUD/AimReticle
@onready var boost_status: Label = $HUD/BoostStatus

var _previous_hdr_2d: bool = false
var _pause_overlay: CanvasLayer


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _ready() -> void:
	add_to_group(&"native_3d_gameplay")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# This review has no pickups or retry rewards; do not spend Hangar supplies.
	GameManager.start_game(false)
	player.configure_flight_space(flight_space)
	if hud.has_method("update_all"):
		hud.update_all()


func _process(_delta: float) -> void:
	aim_reticle.visible = player.is_using_free_aim and GameManager.is_game_active
	if aim_reticle.visible:
		aim_reticle.position = flight_space.combat_to_screen(player.get_aim_reticle_combat_position())
	if player.is_boosting:
		boost_status.text = "BOOSTING"
	elif player.boost_cooldown_timer > 0.0:
		boost_status.text = "BOOST RECHARGING"
	else:
		boost_status.text = "BOOST READY"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if not GameManager.is_game_active or is_instance_valid(_pause_overlay):
		return
	get_viewport().set_input_as_handled()
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 20
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)
	var menu := PAUSE_MENU_SCENE.instantiate()
	menu.resumed.connect(_close_pause_menu)
	_pause_overlay.add_child(menu)
	aim_reticle.hide()
	get_tree().paused = true


func _close_pause_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null


func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().use_hdr_2d = _previous_hdr_2d
	if get_tree() != null:
		get_tree().paused = false
	GameManager.is_game_active = false
