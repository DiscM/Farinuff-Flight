extends Node
class_name TankArmor3DReview
## Manual review around native Tank armor plates. The review controls are
## deterministic fixtures; they do not add production spawning or rewards.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const TankEnemy := preload("res://entities/enemies/tank_enemy_3d.gd")
const Plate3D := preload("res://entities/enemies/tank_plate_3d.gd")
const BasicEnemy := preload("res://entities/enemies/basic_enemy_3d.gd")
const SpawnTuning := preload("res://entities/enemies/enemy_spawn_tuning.gd")
const ReviewGuides := preload("res://scenes/tank_armor_3d_review_guides.gd")
const ENEMY_SCENE := preload("res://entities/enemies/tank_enemy_3d.tscn")
const MAX_TANKS := 2

@onready var gameplay: NativeGame = $Gameplay
@onready var generation_select: OptionButton = $ReviewHUD/Panel/Controls/Generation
@onready var status: Label = $ReviewHUD/Panel/Status
@onready var detail: Label = $ReviewHUD/Panel/Detail
@onready var guides: ReviewGuides = $ReviewHUD/Guides
@onready var _first_tank: TankEnemy = $Gameplay/World3D/Actors3D/FirstTank3D

var _review_ready := false
var _tanks: Array[TankEnemy] = []
var _spawn_count := 0
var _destroyed := 0
var _escaped := 0
var _plate_hits := 0
var _plates_destroyed := 0
var _hull_hits := 0


func _ready() -> void:
	$ReviewHUD/Panel/Controls/Top.pressed.connect(spawn_from_edge.bind(0))
	$ReviewHUD/Panel/Controls/Right.pressed.connect(spawn_from_edge.bind(1))
	$ReviewHUD/Panel/Controls/Bottom.pressed.connect(spawn_from_edge.bind(2))
	$ReviewHUD/Panel/Controls/Left.pressed.connect(spawn_from_edge.bind(3))
	$ReviewHUD/Panel/Controls/PlateTest.pressed.connect(spawn_plate_test)
	$ReviewHUD/Panel/Controls/Clear.pressed.connect(clear_tanks)
	$ReviewHUD/Panel/Controls/Restore.pressed.connect(restore_review)
	generation_select.item_selected.connect(_set_generation)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	guides.configure(gameplay.flight_space, _tanks)
	gameplay.projectile_manager.player_projectile_hit.connect(_on_player_projectile_hit)
	if is_instance_valid(_first_tank):
		_first_tank.hide()
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			spawn_from_edge(event.keycode - KEY_1)
		KEY_O:
			generation_select.select((generation_select.selected + 1) % generation_select.item_count)
			_set_generation(generation_select.selected)
		KEY_P:
			spawn_plate_test()
		KEY_H:
			guides.show_hitboxes = not guides.show_hitboxes
			_update_status()
		KEY_S:
			guides.show_sockets = not guides.show_sockets
			_update_status()
		KEY_X:
			clear_tanks()
		KEY_R:
			restore_review()
		_:
			return
	get_viewport().set_input_as_handled()


func _set_generation(index: int) -> void:
	generation_select.select(clampi(index, 0, generation_select.item_count - 1))
	_update_status()


func spawn_from_edge(edge: int) -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused or _tanks.size() >= MAX_TANKS:
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
	_spawn_tank(spawn_position, direction)


func spawn_plate_test() -> void:
	if not _review_ready or get_tree().paused or _tanks.size() >= MAX_TANKS:
		return
	var offset := gameplay.flight_space.screen_motion_to_combat(Vector2(0.0, -180.0))
	# Keep the isolated target moving away from the player so the plate test
	# remains available for inspection instead of consuming a life on contact.
	_spawn_tank(gameplay.player.get_combat_position() + offset, Vector3.FORWARD)


func _spawn_tank(spawn_position: Vector3, direction: Vector3) -> void:
	var tank: TankEnemy
	if is_instance_valid(_first_tank):
		tank = _first_tank
		_first_tank = null
	else:
		tank = ENEMY_SCENE.instantiate() as TankEnemy
		$Gameplay/World3D/Actors3D.add_child(tank)
	_spawn_count += 1
	tank.name = "TankArmorReview_%d" % _spawn_count
	tank.finished.connect(_on_tank_finished.bind(tank))
	tank.armor_plate_destroyed.connect(_on_armor_plate_destroyed)
	_tanks.append(tank)
	var generation := generation_select.selected + 2
	if not tank.activate_generation(gameplay.flight_space, spawn_position, direction, generation):
		_tanks.erase(tank)
		tank.queue_free()
	_update_status()


func clear_tanks() -> void:
	if not _review_ready:
		return
	for tank in _tanks.duplicate():
		if is_instance_valid(tank) and tank.is_active:
			tank._finish(BasicEnemy.FinishReason.ESCAPED)
	_tanks.clear()
	_update_status()


func restore_review() -> void:
	if not _review_ready:
		return
	clear_tanks()
	gameplay.reset_native_progression()
	_spawn_count = 0
	_destroyed = 0
	_escaped = 0
	_plate_hits = 0
	_plates_destroyed = 0
	_hull_hits = 0
	_update_status()


func _on_tank_finished(reason: BasicEnemy.FinishReason, _combat_position: Vector3, tank: TankEnemy) -> void:
	_tanks.erase(tank)
	match reason:
		BasicEnemy.FinishReason.DESTROYED:
			_destroyed += 1
		BasicEnemy.FinishReason.ESCAPED:
			_escaped += 1
	_update_status()


func _on_armor_plate_destroyed(_combat_position: Vector3, _remaining_plates: int) -> void:
	_plates_destroyed += 1
	_update_status()


func _on_player_projectile_hit(target: Area3D, _combat_position: Vector3) -> void:
	if target is Plate3D:
		_plate_hits += 1
	elif target is TankEnemy:
		_hull_hits += 1
	_update_status()


func _update_status() -> void:
	if not _review_ready:
		return
	var active_plates := 0
	var plate_capacity := 0
	for tank in _tanks:
		if is_instance_valid(tank):
			active_plates += tank.get_active_armor_plate_count()
			if tank.generation >= 2:
				plate_capacity += tank.get_armor_plates().size()
	var pool_metrics := gameplay.projectile_manager.get_metrics()
	var growth := int(pool_metrics["player"]["pool_growth_after_warmup"])
	status.text = "GEN %d • TANKS %d/%d • PLATES %d/%d • PLATE HITS %d • BROKEN %d • HULL HITS %d • KILL %d • ESC %d • GROWTH %d" % [
		generation_select.selected + 2, _tanks.size(), MAX_TANKS, active_plates,
		plate_capacity,
		_plate_hits, _plates_destroyed, _hull_hits, _destroyed, _escaped, growth,
	]
	detail.text = "3 one-hit orbiting plates • RADIUS %d/%d/%d PX • ORBIT 40°/S • O GENERATION • P PLATE TEST • H HITBOX • S SOCKETS • X CLEAR • R RESTORE • LIVES %d/%d" % [
		TankEnemy.ARMOR_ORBIT_RADIUS_PIXELS,
		TankEnemy.ARMOR_ORBIT_RADIUS_PIXELS + TankEnemy.ARMOR_RADIUS_STEP_PIXELS,
		TankEnemy.ARMOR_ORBIT_RADIUS_PIXELS + TankEnemy.ARMOR_RADIUS_STEP_PIXELS * 2.0,
		GameManager.lives, GameManager.starting_lives,
	]
