extends Area2D
## Power-up — drifts downward. Collected by shooting it or by direct player contact.

enum Type { SCALE_UP, RAPID_FIRE, SHIELD, SPREAD_SHOT, MAGNET, NUKE }

@export var type: Type = Type.SCALE_UP
@export var drift_speed: float = 80.0

var bob_time: float = 0.0

# Color mapping for each type
const TYPE_COLORS: Dictionary = {
	Type.SCALE_UP: Color(0.2, 0.8, 1.0),
	Type.RAPID_FIRE: Color(1.0, 0.8, 0.0),
	Type.SHIELD: Color(0.3, 0.9, 0.5),
	Type.SPREAD_SHOT: Color(1.0, 0.4, 0.8),
	Type.MAGNET: Color(0.6, 0.4, 1.0),
	Type.NUKE: Color(1.0, 0.2, 0.2),
}

const TYPE_LABELS: Dictionary = {
	Type.SCALE_UP: "S+",
	Type.RAPID_FIRE: "RF",
	Type.SHIELD: "SH",
	Type.SPREAD_SHOT: "SP",
	Type.MAGNET: "MG",
	Type.NUKE: "NK",
}

## Initializes the power-up: adds to the "powerups" group, connects collision,
## attaches a screen-exit notifier, and applies the type-specific color and label.
func _ready() -> void:
	add_to_group("powerups")
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

	# Set sprite color based on type
	_setup_visuals()

## Drifts the power-up downward and applies a gentle horizontal bob.
func _physics_process(delta: float) -> void:
	position.y += drift_speed * delta
	# Floating bob effect
	bob_time += delta
	position.x += sin(bob_time * 2.5) * 0.5

## Handles collision: collected by a player bullet hit (destroys the bullet)
## or by direct player contact.
func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	# Collected by bullet hit
	if area.collision_layer & 4:  # player_bullets layer
		area.queue_free()  # destroy the bullet
		_collect()
	# Collected by direct player contact
	elif area.is_in_group("player"):
		_collect()

## Emits the power_up_collected signal with this power-up's type and position,
## spawns a collection particle effect, and frees the node.
func _collect() -> void:
	SignalBus.power_up_collected.emit(type, global_position)
	_spawn_collect_effect()
	queue_free()

## Frees the power-up when it exits the bottom of the screen.
func _on_screen_exited() -> void:
	if global_position.y > 0:
		queue_free()

## Applies the type-specific color tint to the sprite and sets the
## corresponding abbreviation label (e.g. "RF" for Rapid Fire).
func _setup_visuals() -> void:
	# The sprite child will have its modulate set
	var spr := $Sprite2D
	if spr:
		spr.modulate = TYPE_COLORS.get(type, Color.WHITE)
	var lbl := $Label
	if lbl:
		lbl.text = TYPE_LABELS.get(type, "?")

## Spawns a brief CPU particle burst at the power-up's position using
## the type's assigned color for satisfying collection feedback.
func _spawn_collect_effect() -> void:
	# Quick particle burst
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = TYPE_COLORS.get(type, Color.WHITE)
	get_tree().current_scene.add_child(particles)
	# Auto-free after particles finish
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)
