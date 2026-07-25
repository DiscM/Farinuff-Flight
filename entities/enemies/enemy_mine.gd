extends Area2D
class_name EnemyMine
## Defusable hostile ordnance. Deployment survives its Bomber source.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")
const PLASMA_FIELD_SCENE := preload("res://entities/enemies/plasma_field.tscn")

var coordinator: SpecialAttackCoordinator
var is_cluster := false
var leaves_plasma := false
var _fuse := 0.0
var _active := false
var _detonating := false
var _ring: Line2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_process(false)


func pool_activate(spawn_position: Vector2, cluster: bool, plasma: bool, shared_coordinator: SpecialAttackCoordinator) -> void:
	global_position = spawn_position
	coordinator = shared_coordinator
	is_cluster = cluster
	leaves_plasma = plasma
	_fuse = 2.2
	_active = true
	_detonating = false
	visible = true
	scale = Vector2.ONE
	modulate = Color.WHITE
	collision_layer = 32
	collision_mask = 5
	monitoring = true
	monitorable = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	add_to_group("hostile_ordnance")
	add_to_group("evolved_pressure")
	_build_ring()


func _process(delta: float) -> void:
	_fuse -= delta
	var progress := clampf(1.0 - _fuse / 2.2, 0.0, 1.0)
	if _ring != null:
		_ring.scale = Vector2.ONE * lerpf(0.25, 1.65, progress)
		_ring.modulate.a = 0.35 + 0.65 * absf(sin(progress * PI * 7.0))
	if _fuse <= 0.0:
		_detonate()


func take_damage(_amount: int) -> void:
	# Defusing is intentionally reward-free and cancels every pending effect.
	despawn()


func clear_ordnance() -> void:
	despawn()


func despawn() -> void:
	if not _active:
		return
	_active = false
	_release_caps()
	visible = false
	call_deferred("_release")


func _detonate() -> void:
	if not _active or _detonating:
		return
	_detonating = true
	var scene_root := get_tree().current_scene
	if scene_root != null:
		for i in range(8):
			_spawn_bullet(scene_root, Vector2.from_angle(TAU * float(i) / 8.0), 165.0)
		if is_cluster:
			for i in range(4):
				_spawn_bullet(scene_root, Vector2.from_angle(PI * 0.25 + TAU * float(i) / 4.0), 105.0)
		if leaves_plasma and coordinator != null and coordinator.request_hazard(&"plasma_field"):
			var field := ObjectPool.acquire(PLASMA_FIELD_SCENE, scene_root)
			if field != null:
				field.pool_activate(global_position, coordinator)
			else:
				coordinator.release_hazard(&"plasma_field")
	despawn()


func _spawn_bullet(scene_root: Node, shot_direction: Vector2, shot_speed: float) -> void:
	var bullet = ObjectPool.acquire(ENEMY_BULLET_SCENE, scene_root)
	if bullet != null:
		bullet.pool_activate(global_position, shot_direction, shot_speed, Color(2.4, 0.12, 1.55, 1.0))


func _build_ring() -> void:
	if _ring == null:
		_ring = Line2D.new()
		_ring.width = 2.0
		_ring.default_color = Color(1.0, 0.18, 0.72, 0.9)
		_ring.closed = true
		add_child(_ring)
	var points := PackedVector2Array()
	for i in range(25):
		points.append(Vector2.from_angle(TAU * float(i) / 24.0) * 24.0)
	_ring.points = points
	_ring.scale = Vector2.ONE * 0.25
	_ring.visible = true


func _release_caps() -> void:
	if coordinator == null or not is_instance_valid(coordinator):
		return
	coordinator.release_hazard(&"mine")
	if is_cluster:
		coordinator.release_hazard(&"cluster_mine")


func _release() -> void:
	remove_from_group("hostile_ordnance")
	remove_from_group("evolved_pressure")
	if _ring != null:
		_ring.visible = false
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if bool(area.get("is_boosting")):
			despawn()
		else:
			if area.has_method("receive_hostile_hit"):
				area.receive_hostile_hit(2.0)
			_detonate()
