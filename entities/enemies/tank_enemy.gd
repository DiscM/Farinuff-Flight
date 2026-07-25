extends BaseEnemy
## Tank enemy — slow, high HP, fires radial bullet bursts periodically.

const ENEMY_BULLET_SCENE := preload("res://entities/bullets/enemy_bullet.tscn")
const TANK_PLATE_SCENE := preload("res://entities/enemies/tank_plate.tscn")

var shoot_timer: float = 0.0
var shoot_interval: float = 2.5   # seconds between bursts
var bullet_count: int = 8         # bullets per burst, evenly spread 360°
var overload_timer := 9.0
var overload_state := 0
var overload_step_timer := 0.0
var overload_shots := 0
var overload_angle := 0.0

## Sets stats for the tank enemy (15 HP, slow, 300 points, guaranteed 3-value orb)
## and randomizes the first shot timer so multiple tanks don't fire simultaneously.
func _ready() -> void:
	archetype_id = &"tank"
	orb_value = 3  # High-value Tank orb
	guaranteed_orb = true
	super._ready()
	# Stagger first shot so not all tanks fire at once
	shoot_timer = randf_range(0.5, shoot_interval)
	if generation >= 2:
		for i in range(3):
			var plate := TANK_PLATE_SCENE.instantiate() as TankPlate
			$VisualRoot.add_child(plate)
			plate.configure(TAU * float(i) / 3.0, 43.0 + float(generation - 2) * 3.0)

## Moves using the base straight-line movement, then decrements the shoot
## timer and fires a radial burst when it reaches zero.
func _move(delta: float) -> void:
	super._move(delta)
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_fire_radial_burst()
		if generation >= 3:
			get_tree().create_timer(0.35).timeout.connect(_fire_radial_burst.bind(PI / 8.0))
	if generation >= 4:
		_update_overload(delta)

## Fires a 360° burst of enemy bullets evenly spaced around the tank.
## Alternates speed between even and odd bullets for visual variety, and
## colors them neon purple for high contrast against the background.
func _fire_radial_burst(angle_offset: float = 0.0) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for i in range(bullet_count):
		var angle := (TAU / bullet_count) * i + angle_offset
		var dir := Vector2(sin(angle), cos(angle))
		var shot_speed := (245.0 if i % 2 == 0 else 305.0) + randf_range(-8.0, 8.0)
		var bullet = ObjectPool.acquire(ENEMY_BULLET_SCENE, scene_root)
		if bullet == null:
			continue
		bullet.pool_activate(get_origin(&"Emitter"), dir, shot_speed, Color(2.0, 0.2, 3.0, 1.0))


func _update_overload(delta: float) -> void:
	if overload_state == 0:
		overload_timer -= delta
		if overload_timer <= 0.0 and can_begin_special() and special_attack_coordinator.request_major(self):
			overload_state = 1
			overload_step_timer = 1.0
			var ring := make_ring_warning(64.0, Color(1.0, 0.02, 0.72, 0.95), 5.0)
			ring.name = "OverloadWarning"
	elif overload_state == 1:
		overload_step_timer -= delta
		if overload_step_timer <= 0.0:
			overload_state = 2
			overload_step_timer = 0.0
			overload_shots = 0
			overload_angle = randf_range(0.0, TAU)
			var warning := get_node_or_null("OverloadWarning")
			if warning != null:
				warning.queue_free()
	elif overload_state == 2:
		overload_step_timer -= delta
		if overload_step_timer <= 0.0:
			overload_step_timer = 0.1
			# Leave a stable 45° corridor opposite the first spiral shot.
			var angle := overload_angle + float(overload_shots) * 0.52
			var corridor := overload_angle + PI
			if absf(wrapf(angle - corridor, -PI, PI)) > PI / 8.0:
				_fire_overload_shot(Vector2.from_angle(angle))
			overload_shots += 1
			if overload_shots >= 16:
				overload_state = 0
				overload_timer = 9.0
				special_attack_coordinator.release_major(self)


func _fire_overload_shot(direction: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bullet = ObjectPool.acquire(ENEMY_BULLET_SCENE, scene_root)
	if bullet != null:
		bullet.pool_activate(get_origin(&"Emitter"), direction, 260.0, Color(2.8, 0.05, 1.7, 1.0))


func dev_trigger_ability() -> void:
	overload_timer = 0.0
	visible_time = 1.0
