extends Area2D
class_name PowerUp
## Power-up — drifts downward. Collected by shooting it or by direct player contact.
## Pooled via ObjectPool: activate with pool_activate() after acquire, and
## return it with despawn() instead of queue_free().

enum Type { SCALE_UP, RAPID_FIRE, SHIELD, SPREAD_SHOT, MAGNET, NUKE }

@export var type: Type = Type.SCALE_UP
@export var drift_speed: float = 80.0

var bob_time: float = 0.0
var _is_despawning: bool = false

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

## One-time setup: connects collision and attaches a screen-exit notifier.
## Everything that must refresh on reuse lives in pool_activate().
func _ready() -> void:
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

## Reuses the power-up from the pool with fresh spawn values.
func pool_activate(spawn_position: Vector2, new_type: int) -> void:
	_is_despawning = false
	global_position = spawn_position
	type = new_type as Type
	bob_time = 0.0
	collision_layer = 16
	collision_mask = 5
	monitoring = true
	monitorable = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group("powerups")
	_setup_visuals()

## Returns the power-up to the pool after disabling its collision and physics.
func despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true
	visible = false
	call_deferred("_deactivate_for_pool")

## Disables and releases the power-up after the current physics query finishes.
func _deactivate_for_pool() -> void:
	remove_from_group("powerups")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	ObjectPool.release(self)

## Drifts the power-up downward and applies a gentle horizontal bob.
func _physics_process(delta: float) -> void:
	position.y += drift_speed * delta
	# Floating bob effect (delta-scaled so amplitude is frame-rate independent;
	# 30.0/s reproduces the original per-frame 0.5 nudge at 60 fps)
	bob_time += delta
	position.x += sin(bob_time * 2.5) * 30.0 * delta

## Handles collision: collected by a player bullet hit (destroys the bullet)
## or by direct player contact.
func _on_area_entered(area: Area2D) -> void:
	if _is_despawning:
		return
	# Collected by bullet hit
	if area.collision_layer & 4:  # player_bullets layer
		if area.has_method("despawn"):
			area.despawn()
		else:
			area.queue_free()
		_collect()
	# Collected by direct player contact
	elif area.is_in_group("player"):
		_collect()

## Emits the power_up_collected signal with this power-up's type and position,
## spawns a collection particle effect, and returns the node to the pool.
func _collect() -> void:
	SignalBus.power_up_collected.emit(type, global_position)
	_spawn_collect_effect()
	despawn()

## Despawns the power-up when it exits the bottom of the screen.
func _on_screen_exited() -> void:
	if global_position.y > 0:
		despawn()

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
