extends Node
class_name Native3DGameplay
## Isolated native Player Craft, pooled Projectiles, Basic Enemy hit routing,
## Player damage, and boost deflection. Rewards and encounters are deferred.

signal gameplay_ready

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")

@onready var hud: CanvasLayer = $HUD
@onready var player: PlayerCraft = $World3D/Actors3D/Player3D
@onready var flight_space: FlightSpace = $FlightSpace3D
@onready var aim_reticle: Sprite2D = $HUD/AimReticle
@onready var boost_status: Label = $HUD/BoostStatus
@onready var projectile_status: Label = $HUD/ProjectileStatus
@onready var projectile_manager: ProjectileManager = $GameplayManagers/ProjectileManager3D
@onready var transition_overlay: CanvasLayer = $TransitionOverlay

var _previous_hdr_2d: bool = false
var _pause_overlay: CanvasLayer
var _metrics_timer := 0.0


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _ready() -> void:
	add_to_group(&"native_3d_gameplay")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.is_game_active = false
	projectile_manager.configure(flight_space, $World3D/Projectiles3D, $World3D/PoolRoot3D, player)
	projectile_manager.add_to_group(&"native_3d_projectile_manager")
	if not await projectile_manager.warm_projectile_pools():
		$TransitionOverlay/Message.text = "Projectile preparation failed. See the debugger."
		return
	player.fire_requested.connect(projectile_manager.fire_player_projectile)
	player.deflection_requested.connect(projectile_manager.deflect_enemy_projectiles)
	projectile_manager.player_projectile_hit.connect(_on_player_projectile_hit)
	projectile_manager.enemy_projectile_hit.connect(_on_enemy_projectile_hit)
	# This review has no pickups or retry rewards; do not spend Hangar supplies.
	GameManager.start_game(false)
	player.configure_flight_space(flight_space)
	transition_overlay.hide()
	if hud.has_method("update_all"):
		hud.update_all()
	gameplay_ready.emit()


func _on_player_projectile_hit(target: Area3D, _combat_position: Vector3) -> void:
	if target is BasicEnemy:
		(target as BasicEnemy).take_damage(WeaponTuning.BASE_DAMAGE + GameManager.bonus_damage)


func _on_enemy_projectile_hit(target: Area3D, combat_position: Vector3) -> void:
	if target == player:
		player.receive_damage(combat_position, PlayerCraft.DamageSource.ENEMY_PROJECTILE)


func _process(delta: float) -> void:
	aim_reticle.visible = player.is_using_free_aim and GameManager.is_game_active
	if aim_reticle.visible:
		aim_reticle.position = flight_space.combat_to_screen(player.get_aim_reticle_combat_position())
	if player.boost_reflected_projectiles >= FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD:
		boost_status.text = "CHAIN READY  •  BOOST AGAIN  •  REFLECTIONS %d / %d" % [
			player.boost_reflected_projectiles, FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD,
		]
	elif player.is_boosting:
		boost_status.text = "BOOSTING  •  REFLECTIONS %d / %d" % [
			player.boost_reflected_projectiles, FlightTuning.BOOST_CHAIN_REFLECT_THRESHOLD,
		]
	elif player.boost_cooldown_timer > 0.0:
		boost_status.text = "BOOST RECHARGING"
	else:
		boost_status.text = "BOOST READY"
	_metrics_timer -= delta
	if _metrics_timer <= 0.0 and projectile_manager.is_ready:
		_metrics_timer = 0.25
		var metrics := projectile_manager.get_metrics()
		projectile_status.text = "P %d/%d  •  E %d/%d  •  ARMED %d  •  DEFLECT %d/%d  •  GROWTH %d" % [
			metrics["player"]["active"], metrics["player"]["pool_size"],
			metrics["enemy"]["active"], metrics["enemy"]["pool_size"],
			metrics["armed"], metrics["enemy"]["deflected_active"],
			metrics["enemy"]["deflections"], metrics["pool_growth_after_warmup"],
		]


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
