extends Area2D
## Player bullet — flies in a direction, damages enemies on contact.
## Supports piercing (pass through) and explosive (area damage) upgrades.

@export var speed: float = 800.0
var direction: Vector2 = Vector2.UP
var piercing: bool = false
var explosive: bool = false
var zigzag: bool = false
var zigzag_stacks: int = 1
var _zigzag_time: float = 0.0

## Sets up a screen-exit notifier for auto-cleanup and connects the
## collision handler to damage enemies on contact.
func _ready() -> void:
	# Auto-delete when leaving the screen
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	# Damage enemies on contact
	area_entered.connect(_on_area_entered)

## Moves the bullet along its direction each physics frame. If zigzag is
## enabled, also applies a perpendicular sine-wave oscillation whose
## frequency and amplitude scale with zigzag_stacks. Speed is reduced
## 10% per stack (capped at 5 stacks = –50%).
func _physics_process(delta: float) -> void:
	# Bullet speed reduced 10% per zigzag stack (max 5 stacks = -50%)
	var speed_mult := 1.0 - mini(zigzag_stacks, 5) * 0.1
	position += direction * speed * speed_mult * delta
	if zigzag:
		var freq := 18.0 + zigzag_stacks * 3.0   # faster wobble per stack
		var amp  := 120.0 * zigzag_stacks        # wider sweep per stack
		_zigzag_time += delta * freq
		var perp := Vector2(-direction.y, direction.x)
		position += perp * sin(_zigzag_time) * amp * delta

## Handles collision with enemies and tempest sections. Deals 1 + bonus
## damage, triggers an explosion if the explosive flag is set, and
## frees the bullet unless it has piercing (which lets it pass through).
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		var dmg := 1 + GameManager.bonus_damage
		area.take_damage(dmg)

		if explosive:
			_explode()

		if not piercing:
			call_deferred("queue_free")

## Deals area damage to all enemies within an 80px blast radius and spawns
## a particle burst visual effect at the bullet's position. Used when the
## explosive upgrade is active.
func _explode() -> void:
	# Deal area damage to all enemies within blast radius
	var blast_radius_sq := 80.0 * 80.0
	var damage := 1 + GameManager.bonus_damage
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_squared_to(enemy.global_position) < blast_radius_sq:
			enemy.take_damage(damage)
	for section in get_tree().get_nodes_in_group("tempest_sections"):
		if is_instance_valid(section) and global_position.distance_squared_to(section.global_position) < blast_radius_sq:
			section.take_damage(damage)

	# Visual: explosion ring
	var ring := CPUParticles2D.new()
	ring.global_position = global_position
	ring.emitting = true
	ring.one_shot = true
	ring.amount = 16
	ring.lifetime = 0.35
	ring.explosiveness = 1.0
	ring.direction = Vector2.ZERO
	ring.spread = 180.0
	ring.initial_velocity_min = 100.0
	ring.initial_velocity_max = 200.0
	ring.gravity = Vector2.ZERO
	ring.scale_amount_min = 2.0
	ring.scale_amount_max = 5.0
	ring.color = Color(1.0, 0.6, 0.15, 0.9)
	var scene_root := get_tree().current_scene
	scene_root.call_deferred("add_child", ring)
	get_tree().create_timer(0.5).timeout.connect(ring.queue_free)
