extends Area2D
## Player bullet — flies in a direction, damages enemies on contact.
## Supports piercing (pass through) and explosive (area damage) upgrades.

const EXPLOSION_SCENE := preload("res://effects/explosion.tscn")

@export var speed: float = 800.0
var direction: Vector2 = Vector2.UP
var piercing: bool = false
var explosive: bool = false
var zigzag: bool = false
var zigzag_stacks: int = 1
var _zigzag_time: float = 0.0
var _is_despawning: bool = false
@onready var sprite: Sprite2D = $Sprite2D

## Sets up a screen-exit notifier for auto-cleanup and connects the
## collision handler to damage enemies on contact.
func _ready() -> void:
	if sprite.material != null:
		sprite.material = sprite.material.duplicate(true)
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	area_entered.connect(_on_area_entered)

## Reuses the bullet from the pool with fresh position and modifier state.
func pool_activate(spawn_position: Vector2, new_direction: Vector2, scale_multiplier: float = 1.0, new_piercing: bool = false, new_explosive: bool = false, new_zigzag_stacks: int = 0) -> void:
	_is_despawning = false
	global_position = spawn_position
	direction = new_direction.normalized() if not new_direction.is_zero_approx() else Vector2.UP
	rotation = direction.angle() + PI * 0.5
	scale = Vector2.ONE * scale_multiplier
	piercing = new_piercing
	explosive = new_explosive
	zigzag_stacks = max(0, new_zigzag_stacks)
	zigzag = zigzag_stacks > 0
	_zigzag_time = 0.0
	collision_layer = 4
	# Layers 2 (enemies), 5 (powerups), 6 (hostile ordnance). Own layer
	# (player_bullets) is excluded so volleys don't pair-check each other.
	collision_mask = 50
	monitoring = true
	monitorable = true
	visible = true
	sprite.modulate = Color.WHITE
	_configure_projectile_shader(spawn_position)
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group("player_bullets")

## Updates the local shader instance so projectile upgrades are readable at a
## glance without changing collision, damage, or pooled-resource behavior.
func _configure_projectile_shader(spawn_position: Vector2) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	var core_color := Color(0.82, 1.0, 1.0)
	var glow_color := Color(0.02, 0.72, 1.0)
	if piercing:
		core_color = Color(0.94, 0.82, 1.0)
		glow_color = Color(0.38, 0.16, 1.0)
	if explosive:
		core_color = core_color.lerp(Color(1.0, 0.9, 0.55), 0.62)
		glow_color = glow_color.lerp(Color(1.0, 0.18, 0.025), 0.72)
	material.set_shader_parameter(&"core_color", core_color)
	material.set_shader_parameter(&"glow_color", glow_color)
	material.set_shader_parameter(&"piercing_amount", 1.0 if piercing else 0.0)
	material.set_shader_parameter(&"explosive_amount", 1.0 if explosive else 0.0)
	material.set_shader_parameter(&"zigzag_amount", clampf(float(zigzag_stacks) / 5.0, 0.0, 1.0))
	material.set_shader_parameter(
		&"phase_offset",
		fposmod(spawn_position.x * 0.071 + spawn_position.y * 0.037, TAU)
	)

## Returns the bullet to the pool after disabling its collision and physics.
func despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true
	visible = false
	call_deferred("_deactivate_for_pool")

## Disables and releases the bullet after the current physics query finishes.
func _deactivate_for_pool() -> void:
	remove_from_group("player_bullets")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)

## Moves the bullet along its direction each physics frame. If zigzag is
## enabled, also applies a perpendicular sine-wave oscillation whose
## frequency and amplitude scale with zigzag_stacks. Speed is reduced
## 10% per stack (capped at 5 stacks = -50%).
func _physics_process(delta: float) -> void:
	var speed_mult := 1.0 - mini(zigzag_stacks, 5) * 0.1
	position += direction * speed * speed_mult * delta
	if zigzag:
		var freq := 18.0 + zigzag_stacks * 3.0
		var amp := 120.0 * zigzag_stacks
		_zigzag_time += delta * freq
		var perp := Vector2(-direction.y, direction.x)
		position += perp * sin(_zigzag_time) * amp * delta

## Handles collision with enemies and tempest sections. Deals 1 + bonus
## damage, triggers an explosion if the explosive flag is set, and
## returns the bullet to the pool unless it has piercing.
func _on_area_entered(area: Area2D) -> void:
	if _is_despawning:
		return
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections") \
			or area.is_in_group("enemy_armor") or area.is_in_group("hostile_ordnance"):
		if not area.has_method("take_damage"):
			return
		var dmg := 1 + GameManager.bonus_damage
		area.take_damage(dmg)

		if explosive:
			_explode()
		else:
			_play_impact()

		if not piercing:
			despawn()

## Deals area damage to all enemies within an 80px blast radius and spawns
## a pooled impact burst at the bullet's position.
func _explode() -> void:
	var blast_radius_sq := 80.0 * 80.0
	var damage := 1 + GameManager.bonus_damage
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_squared_to(enemy.global_position) < blast_radius_sq:
			enemy.take_damage(damage)
	for section in get_tree().get_nodes_in_group("tempest_sections"):
		if is_instance_valid(section) and global_position.distance_squared_to(section.global_position) < blast_radius_sq:
			section.take_damage(damage)
	for plate in get_tree().get_nodes_in_group("enemy_armor"):
		if is_instance_valid(plate) and global_position.distance_squared_to(plate.global_position) < blast_radius_sq:
			plate.take_damage(damage)
	for ordnance in get_tree().get_nodes_in_group("hostile_ordnance"):
		if is_instance_valid(ordnance) and ordnance.has_method("take_damage") \
				and global_position.distance_squared_to(ordnance.global_position) < blast_radius_sq:
			ordnance.take_damage(damage)

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var explosion := ObjectPool.acquire(EXPLOSION_SCENE, scene_root)
	if explosion != null and explosion.has_method("play_at"):
		explosion.play_at(global_position, true)

## Spawns a short pixel spark for standard bullet hits.
func _play_impact() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var impact := ObjectPool.acquire(EXPLOSION_SCENE, scene_root)
	if impact != null and impact.has_method("play_impact_at"):
		impact.play_impact_at(global_position)

## Frees the bullet when it leaves the screen.
func _on_screen_exited() -> void:
	despawn()
