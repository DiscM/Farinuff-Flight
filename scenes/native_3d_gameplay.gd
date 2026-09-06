extends Node
class_name Native3DGameplay
## Isolated native Player Craft, pooled Projectiles, Basic Enemy lineage,
## rewards, pooled pickups/hazards, and native feedback.

signal gameplay_ready
signal enemy_rewarded(points: int, combat_position: Vector3, orb_spawned: bool)
signal xp_orb_spawned(value: int, combat_position: Vector3)
signal drone_fired(combat_position: Vector3, direction: Vector3)
signal drone_contact_hit(target: Area3D, combat_position: Vector3)

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const FlightSpace := preload("res://systems/flight_space_3d.gd")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const Projectile := preload("res://entities/projectiles/projectile_3d.gd")
const ProjectileManager := preload("res://systems/projectile_manager_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const XPOrbManager := preload("res://systems/xp_orb_manager_3d.gd")
const NativeEffectManager := preload("res://systems/native_effect_manager_3d.gd")
const NativeEffect := preload("res://effects/native_effect_3d.gd")
const NativeHazardManager := preload("res://systems/native_hazard_manager_3d.gd")
const PowerUpManager := preload("res://systems/power_up_manager_3d.gd")
const PlayerDrone := preload("res://entities/player/player_drone_3d.gd")
const DRONE_SCENE := preload("res://entities/player/player_drone_3d.tscn")

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
@onready var actors_root: Node3D = $World3D/Actors3D

## Review scenes can leave this disabled to preserve their earlier no-reward
## contract. Native production gameplay will enable it when its spawner lands.
@export var rewards_enabled := false
@export var consume_field_supplies := false

var _previous_hdr_2d: bool = false
var _pause_overlay: CanvasLayer
var _metrics_timer := 0.0
var _drone: PlayerDrone
var _feedback_actors: Dictionary[int, Node] = {}


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _ready() -> void:
	add_to_group(&"native_3d_gameplay")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.is_game_active = false
	player.prepare_visual_warmup()
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
	if not await _warm_drone_visual():
		$TransitionOverlay/Message.text = "Drone preparation failed. See the debugger."
		return
	await _prepare_run_actors()
	player.fire_requested.connect(projectile_manager.fire_player_projectile)
	player.muzzle_feedback_requested.connect(_on_player_fired)
	player.deflection_requested.connect(projectile_manager.deflect_enemy_projectiles)
	player.boost_started.connect(_on_player_boost_started)
	player.damage_taken.connect(_on_player_damage_taken)
	player.shield_absorbed.connect(_on_shield_absorbed)
	player.nuke_requested.connect(_on_player_nuke_requested)
	player.drone_escort_changed.connect(_on_drone_escort_changed)
	player.shield_burst_requested.connect(_on_shield_burst)
	projectile_manager.explosion_requested.connect(_on_explosive_impact)
	projectile_manager.projectile_fired.connect(_on_projectile_fired)
	projectile_manager.player_projectile_hit.connect(_on_player_projectile_hit)
	projectile_manager.enemy_projectile_hit.connect(_on_enemy_projectile_hit)
	projectile_manager.enemy_projectile_deflected.connect(_on_enemy_projectile_deflected)
	power_up_manager.power_up_collected.connect(_on_power_up_collected)
	hazard_manager.mine_detonated.connect(_on_mine_detonated)
	# The review controller never consumes Hangar supplies. Its reward policy is
	# explicit per scene, so projectile and Phase 4 reviews remain no-reward.
	GameManager.start_game(consume_field_supplies)
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
	if target == player:
		player.receive_damage(combat_position, PlayerCraft.DamageSource.ENEMY_PROJECTILE)
	else:
		effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position)


func _on_enemy_projectile_deflected(_projectile: Area3D, combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.BOOST, combat_position, player.boost_direction, 0.45)


func _on_power_up_collected(_power_up_type: int, combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.PICKUP, combat_position, Vector3.UP, 1.05)


func _on_mine_detonated(combat_position: Vector3, _is_cluster: bool, _leaves_plasma: bool) -> void:
	var intensity := 1.7 if _is_cluster else 1.25
	effect_manager.play_effect(NativeEffect.EffectKind.EXPLOSION, combat_position, Vector3.UP, intensity)


func _on_player_fired(combat_position: Vector3, direction: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.MUZZLE, combat_position, direction, 0.7, true)


func _on_player_boost_started(combat_position: Vector3, direction: Vector3) -> void:
	var boost_socket := player.get_socket(&"Boost")
	var effect_position := boost_socket.global_position if boost_socket != null else combat_position
	effect_manager.play_effect(NativeEffect.EffectKind.BOOST, effect_position, direction, 1.0, true)


func _on_player_damage_taken(combat_position: Vector3, _source: PlayerCraft.DamageSource, _remaining_lives: int) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position, Vector3.UP, 1.35)


func _on_shield_absorbed(combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.SHIELD, combat_position, Vector3.UP, 1.15)


func _on_projectile_fired(kind: int, combat_position: Vector3, direction: Vector3, _speed_pixels: float) -> void:
	var intensity := 0.5 if kind == Projectile.Kind.PLAYER else 0.38
	effect_manager.play_effect(
		NativeEffect.EffectKind.PROJECTILE,
		combat_position,
		direction,
		intensity,
		true
	)


## Attaches the shared telegraph/release feedback to any native actor that
## exposes the stable charge signal contract. The actor keeps ownership of its
## timers and attack cancellation; this controller only renders the event.
func register_enemy_feedback(enemy: Node) -> void:
	if enemy == null or not is_inside_tree() or enemy.is_queued_for_deletion():
		return
	var enemy_id := enemy.get_instance_id()
	if _feedback_actors.has(enemy_id) and is_instance_valid(_feedback_actors[enemy_id]):
		return
	var charge_started := Callable(self, "_on_enemy_charge_started")
	if enemy.has_signal(&"charge_started") and not enemy.is_connected(&"charge_started", charge_started):
		enemy.connect(&"charge_started", charge_started)
	var charge_released := Callable(self, "_on_enemy_charge_released")
	if enemy.has_signal(&"charge_released") and not enemy.is_connected(&"charge_released", charge_released):
		enemy.connect(&"charge_released", charge_released)
	enemy.tree_exiting.connect(_on_feedback_actor_exiting.bind(enemy), CONNECT_ONE_SHOT)
	_feedback_actors[enemy_id] = enemy


func unregister_enemy_feedback(enemy: Node) -> void:
	if enemy == null:
		return
	var charge_started := Callable(self, "_on_enemy_charge_started")
	if enemy.has_signal(&"charge_started") and enemy.is_connected(&"charge_started", charge_started):
		enemy.disconnect(&"charge_started", charge_started)
	var charge_released := Callable(self, "_on_enemy_charge_released")
	if enemy.has_signal(&"charge_released") and enemy.is_connected(&"charge_released", charge_released):
		enemy.disconnect(&"charge_released", charge_released)
	_feedback_actors.erase(enemy.get_instance_id())


func _on_feedback_actor_exiting(enemy: Node) -> void:
	unregister_enemy_feedback(enemy)


func _on_enemy_charge_started(combat_position: Vector3, direction: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.TELEGRAPH, combat_position, direction, 1.0)


func _on_enemy_charge_released(combat_position: Vector3, direction: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.MUZZLE, combat_position, direction, 0.9, true)


func set_drone_escort_enabled(enabled: bool) -> void:
	player.set_drone_escort_enabled(enabled)


func get_drone() -> PlayerDrone:
	return _drone


func get_drone_status() -> Dictionary:
	if is_instance_valid(_drone):
		return _drone.get_status()
	return {
		"active": false,
		"shots_fired": 0,
		"contact_hits": 0,
		"fire_interval": PlayerDrone.FIRE_INTERVAL,
		"hover_offset_pixels": PlayerDrone.HOVER_OFFSET_PIXELS,
	}


func _on_drone_escort_changed(enabled: bool) -> void:
	if not enabled:
		if is_instance_valid(_drone):
			_drone.deactivate()
			_drone.queue_free()
		_drone = null
		return
	if is_instance_valid(_drone):
		return
	var drone := DRONE_SCENE.instantiate() as PlayerDrone
	if drone == null:
		push_error("Native3DGameplay could not instantiate PlayerDrone3D")
		return
	actors_root.add_child(drone)
	drone.fire_requested.connect(projectile_manager.fire_drone_projectile)
	drone.fire_requested.connect(_on_drone_fired)
	drone.contact_damage_requested.connect(_on_drone_contact_requested)
	if not drone.configure(player, flight_space):
		drone.queue_free()
		return
	_drone = drone


func _on_drone_fired(combat_position: Vector3, direction: Vector3) -> void:
	var effect_position := combat_position
	if is_instance_valid(_drone):
		var muzzle := _drone.get_socket(&"MuzzleCenter")
		if muzzle != null:
			effect_position = muzzle.global_position
	effect_manager.play_effect(NativeEffect.EffectKind.MUZZLE, effect_position, direction, 0.45, true)
	drone_fired.emit(combat_position, direction)


func _on_drone_contact_requested(target: Area3D, combat_position: Vector3) -> void:
	if target == null or not target.has_method(&"take_damage"):
		return
	effect_manager.play_effect(NativeEffect.EffectKind.IMPACT, combat_position, Vector3.UP, 0.55)
	target.take_damage(WeaponTuning.BASE_DAMAGE + GameManager.bonus_damage)
	drone_contact_hit.emit(target, combat_position)


func _warm_drone_visual() -> bool:
	var idle_parent := $World3D/PoolRoot3D as Node3D
	var preview := DRONE_SCENE.instantiate() as PlayerDrone
	if preview == null:
		return false
	idle_parent.add_child(preview)
	preview.prepare_visual_warmup()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	preview.queue_free()
	await get_tree().process_frame
	return true


func _on_player_nuke_requested() -> void:
	for node in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		var enemy := node as BasicEnemy
		if enemy != null and not enemy.is_in_group(&"native_3d_bosses"):
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
		0.86 + float(clampi(generation, 1, 4)) * 0.14,
		true
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
	player.reset_elite_upgrades()
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
	for enemy in _feedback_actors.values().duplicate():
		if is_instance_valid(enemy):
			unregister_enemy_feedback(enemy)
	_feedback_actors.clear()
	if get_viewport() != null:
		get_viewport().use_hdr_2d = _previous_hdr_2d
	if get_tree() != null:
		get_tree().paused = false
	GameManager.is_game_active = false


func _prepare_run_actors() -> void:
	await get_tree().process_frame


func _on_explosive_impact(combat_position: Vector3, primary_target: Area3D) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.EXPLOSION, combat_position, Vector3.UP, 0.9)
	_damage_in_radius(combat_position, 65.0, 2 + GameManager.bonus_damage, primary_target)


func _on_shield_burst(combat_position: Vector3) -> void:
	effect_manager.play_effect(NativeEffect.EffectKind.SHIELD, combat_position, Vector3.UP, 4.0)
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		if projectile.is_active and not projectile.is_deflected and flight_space.combat_motion_to_screen(projectile.global_position - combat_position).length() <= 240.0:
			projectile.despawn()
	_damage_in_radius(combat_position, 240.0, 8 + GameManager.bonus_damage)


func _damage_in_radius(center: Vector3, radius: float, damage: int, excluded: Node = null) -> void:
	for enemy in get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if enemy != excluded and enemy.is_active and flight_space.combat_motion_to_screen(enemy.global_position - center).length() <= radius:
			enemy.take_damage(damage)
