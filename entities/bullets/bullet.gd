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

func _ready() -> void:
	# Auto-delete when leaving the screen
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	# Damage enemies on contact
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if zigzag:
		var freq := 18.0 + zigzag_stacks * 3.0   # faster wobble per stack
		var amp  := 120.0 * zigzag_stacks        # wider sweep per stack
		_zigzag_time += delta * freq
		var perp := Vector2(-direction.y, direction.x)
		position += perp * sin(_zigzag_time) * amp * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var dmg := 1 + GameManager.bonus_damage
		area.take_damage(dmg)

		if explosive:
			_explode()

		if not piercing:
			queue_free()

func _explode() -> void:
	# Deal area damage to all enemies within blast radius
	var blast_radius := 80.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != self:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < blast_radius:
				enemy.take_damage(1 + GameManager.bonus_damage)

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
	get_tree().current_scene.add_child(ring)
	get_tree().create_timer(0.5).timeout.connect(ring.queue_free)
	SignalBus.screen_shake.emit(4.0, 0.15)
