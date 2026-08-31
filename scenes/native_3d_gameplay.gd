extends Node
class_name Native3DGameplay
## Isolated native Player Craft, pooled Projectiles, Basic Enemy lineage,
## rewards, pooled pickups/hazards, and first-slice feedback.

signal gameplay_ready
signal enemy_rewarded(points: int, combat_position: Vector3, orb_spawned: bool)
signal xp_orb_spawned(value: int, combat_position: Vector3)

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const XPOrbManager := preload("res://systems/xp_orb_manager_3d.gd")
const NativeEffectManager := preload("res://systems/native_effect_manager_3d.gd")
const NativeEffect := preload("res://effects/native_effect_3d.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const PowerUpManager := preload("res://systems/power_up_manager_3d.gd")

@onready var hud: CanvasLayer = $HUD
@onready var player: PlayerCraft = $World3D/Actors3D/Player3D
@onready var flight_space: FlightSpace = $FlightSpace3D
@onready var aim_reticle: Sprite2D = $HUD/AimReticle
@onready var boost_status: Label = $HUD/BoostStatus
@onready var projectile_status: Label = $HUD/ProjectileStatus
@onready var projectile_manager: ProjectileManager = $GameplayManagers/ProjectileManager3D
@onready var xp_orb_manager: XPOrbManager = $GameplayManagers/XPOrbManager3D
@onready var effect_manager: NativeEffectManager = $GameplayManagers/NativeEffectManager3D
@onready var hazard_manager: NativeHazardManager = $GameplayManagers/NativeHazardManager3D
@onready var power_up_manager: PowerUpManager = $GameplayManagers/PowerUpManager3D
@onready var special_attack_coordinator: SpecialAttackCoordinator = $GameplayManagers/SpecialAttackCoordinator
@onready var transition_overlay: CanvasLayer = $TransitionOverlay

## Review scenes can leave this disabled to preserve their earlier no-reward
## contract. Native production gameplay will enable it when its spawner lands.
@export var rewards_enabled := false

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
	var idle_parent := $World3D/PoolRoot3D as Node3D
	projectile_manager.configure(flight_space, $World3D/Projectiles3D, idle_parent, player)
	xp_orb_manager.configure(flight_space, $World3D/Pickups3D, idle_parent)
	power_up_manager.configure(flight_space, $World3D/PowerUps3D, idle_parent)
	effect_manager.configure($World3D/Effects3D, idle_parent)
	hazard_manager.configure(
		flight_space, $World3D/Hazards3D, idle_parent, special_attack_coordinator, projectile_manager
	)
	projectile_manager.add_to_group(&"native_3d_projectile_manager")
	if not await projectile_manager.warm_projectile_pools():
		$TransitionOverlay/Message.text = "Projectile preparation failed. See the debugger."
		return
	if not await effect_manager.warm_effect_pool():
		$TransitionOverlay/Message.text = "Effect preparation failed. See the debugger."
		return
	if not await hazard_manager.warm_hazard_pool():
		$TransitionOverlay/Message.text = "Hazard preparation failed. See the debugger."
		return
	if not await xp_orb_manager.warm_orb_pool():
		$TransitionOverlay/Message.text = "Pickup preparation failed. See the debugger."
		return
	if not await power_up_manager.warm_power_up_pool():
		$TransitionOverlay/Message.text = "Power-up preparation failed. See the debugger."
		return
	player.fire_requested.connect(projectile_manager.fire_player_projectile)
	player.fire_requested.connect(_on_player_fired)
	player.deflection_requested.connect(projectile_manager.deflect_enemy_projectiles)
	player.boost_started.connect(_on_player_boost_started)
	player.nuke_requested.connect(_on_player_nuke_requested)
	projectile_manager.player_projectile_hit.connect(_on_player_projectile_hit)
	projectile_manager.enemy_projectile_hit.connect(_on_enemy_projectile_hit)
	projectile_manager.enemy_projectile_deflected.connect(_on_enemy_projectile_deflected)
	power_up_manager.power_up_collected.connect(_on_power_up_collected)
	hazard_manager.mine_detonated.connect(_on_mine_detonated)
	# The review controller never consumes Hangar supplies. Its reward policy is
	# explicit per scene, so projectile and Phase 4 reviews remain no-reward.
	GameManager.start_game(false)
	player.configure_flight_space(flight_space)
	transition_overlay.hide()
	if hud.has_method("update_all"):
		hud.update_all()
	gameplay_ready.emit()


func _on_player_projectile_hit(target: Area3D, _combat_position: Vector3) -> void:
	var combat_position := _combat_position
	combat_position.y = 0.0
	effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position)
	if target != null and target.has_method("take_damage"):
		target.take_damage(WeaponTuning.BASE_DAMAGE + GameManager.bonus_damage)


func _on_enemy_projectile_hit(target: Area3D, combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position)
	if target == player:
		player.receive_damage(combat_position, PlayerCraft.DamageSource.ENEMY_PROJECTILE)


func _on_enemy_projectile_deflected(_projectile: Area3D, combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.BOOST, combat_position, player.boost_direction, 0.45)


func _on_power_up_collected(_power_up_type: int, combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.PICKUP, combat_position, Vector3.UP, 1.05)


func _on_mine_detonated(combat_position: Vector3, _is_cluster: bool, _leaves_plasma: bool) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position, Vector3.UP, 1.35)


func _on_player_fired(combat_position: Vector3, direction: Vector3) -> void:
	var muzzle := player.get_socket(&"MuzzleCenter")
	var effect_position := muzzle.global_position if muzzle != null else combat_position
	effect_manager.play_effect(NativeEffect.EffectKind.MUZZLE, effect_position, direction, 0.7)


func _on_player_boost_started(combat_position: Vector3, direction: Vector3) -> void:
	var boost_socket := player.get_socket(&"Boost")
	var effect_position := boost_socket.global_position if boost_socket != null else combat_position
	effect_manager.play_effect(NativeEffect.EffectKind.BOOST, effect_position, direction)


func _on_player_nuke_requested() -> void:
	for node in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		var enemy := node as BasicEnemy
		if enemy != null:
			enemy.take_damage(9999)
	projectile_manager.clear_enemy_projectiles()
	hazard_manager.clear_hazards()


## Called synchronously by BasicEnemy3D after it has logically disabled its
## gameplay body and before it emits its public finish event.
func route_enemy_finish(
	enemy: Node,
	reason: BasicEnemy.FinishReason,
	combat_position: Vector3,
	drift_direction: Vector3
) -> void:
	combat_position.y = 0.0
	if reason == BasicEnemy.FinishReason.CONTACT:
		effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position)
		return
	if reason != BasicEnemy.FinishReason.DESTROYED:
		return
	var generation := int(enemy.generation) if "generation" in enemy else 1
	var death_socket: Marker3D = null
	if enemy.has_method("get_socket"):
		death_socket = enemy.get_socket(&"Death") as Marker3D
	var death_position: Vector3 = combat_position
	if death_socket != null:
		death_position = death_socket.global_position
	effect_manager.play_effect(
		NativeEffect.EffectKind.DEATH,
		death_position,
		drift_direction,
		0.86 + float(clampi(generation, 1, 4)) * 0.14
	)
	if not rewards_enabled or not enemy.has_method("get_reward_points"):
		return
	var points := int(enemy.get_reward_points())
	SignalBus.enemy_killed.emit(points, combat_position)
	var should_drop := false
	if enemy.has_method("should_drop_xp_orb"):
		should_drop = bool(enemy.should_drop_xp_orb())
	var orb_spawned := should_drop
	if should_drop and enemy.has_method("get_orb_value"):
		call_deferred(
			"_spawn_enemy_orb",
			combat_position,
			int(enemy.get_orb_value()),
			drift_direction
		)
	enemy_rewarded.emit(points, combat_position, orb_spawned)


func _spawn_enemy_orb(combat_position: Vector3, value: int, drift_direction: Vector3) -> void:
	var orb := xp_orb_manager.spawn_xp_orb(combat_position, value, drift_direction)
	if orb != null:
		xp_orb_spawned.emit(value, combat_position)


func reset_native_progression() -> void:
	projectile_manager.clear_projectiles()
	xp_orb_manager.clear_orbs()
	power_up_manager.clear_power_ups()
	hazard_manager.clear_hazards()
	special_attack_coordinator.reset_pressure()
	effect_manager.clear_effects()
	GameManager.start_game(false)
	player.reset_damage_state()
	player.reset_power_up_state()


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
		var effect_metrics := effect_manager.get_metrics()
		var orb_metrics := xp_orb_manager.get_metrics()
		var hazard_metrics := hazard_manager.get_metrics()
		var power_up_metrics := power_up_manager.get_metrics()
		var pool_growth := int(metrics["pool_growth_after_warmup"])
		pool_growth += int(effect_metrics["pool_growth_after_warmup"])
		pool_growth += int(orb_metrics["pool_growth_after_warmup"])
		pool_growth += int(hazard_metrics["pool_growth_after_warmup"])
		pool_growth += int(power_up_metrics["pool_growth_after_warmup"])
		projectile_status.text = "P %d/%d  •  E %d/%d  •  FX %d/%d  •  ORB %d/%d  •  PU %d/%d  •  FRAG %d/%d  •  MINE %d/%d  •  FIELD %d/%d  •  GROWTH %d (H F%d/M%d/P%d)" % [
			metrics["player"]["active"], metrics["player"]["pool_size"],
			metrics["enemy"]["active"], metrics["enemy"]["pool_size"],
			effect_metrics["active"], effect_metrics["pool_size"],
			orb_metrics["active"], orb_metrics["pool_size"],
			power_up_metrics["active"], power_up_metrics["pool_size"],
			hazard_metrics["active"], hazard_metrics["pool_size"],
			hazard_metrics["mine_active"], hazard_metrics["mine_pool_size"],
			hazard_metrics["field_active"], hazard_metrics["field_pool_size"],
			pool_growth,
			hazard_metrics["fragment_pool_growth_after_warmup"],
			hazard_metrics["mine_pool_growth_after_warmup"],
			hazard_metrics["field_pool_growth_after_warmup"]
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
