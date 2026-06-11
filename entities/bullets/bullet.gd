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

## Sets up a screen-exit notifier for auto-cleanup and connects the
## collision handler to damage enemies on contact.
func _ready() -> void:
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	area_entered.connect(_on_area_entered)

## Reuses the bullet from the pool with fresh position and modifier state.
func pool_activate(spawn_position: Vector2, new_direction: Vector2, scale_multiplier: float = 1.0, new_piercing: bool = false, new_explosive: bool = false, new_zigzag_stacks: int = 0) -> void:
	_is_despawning = false
	global_position = spawn_position
	direction = new_direction.normalized() if not new_direction.is_zero_approx() else Vector2.UP
	scale = Vector2.ONE * scale_multiplier
	piercing = new_piercing
	explosive = new_explosive
	zigzag_stacks = max(0, new_zigzag_stacks)
	zigzag = zigzag_stacks > 0
	_zigzag_time = 0.0
	collision_layer = 4
	collision_mask = 22
	monitoring = true
	monitorable = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)

## Returns the bullet to the pool after disabling its collision and physics.
func despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true
	_deactivate_for_pool()
	ObjectPool.release_deferred(self)

## Disables the bullet so the pooled node can be safely stored off-screen.
func _deactivate_for_pool() -> void:
	visible = false
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED

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
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		var dmg := 1 + GameManager.bonus_damage
		area.take_damage(dmg)

		if explosive:
			_explode()

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

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var explosion := ObjectPool.acquire(EXPLOSION_SCENE, scene_root)
	if explosion != null and explosion.has_method("play_at"):
		explosion.play_at(global_position, true)

## Frees the bullet when it leaves the screen.
func _on_screen_exited() -> void:
	despawn()
