extends Area2D
## XP Orb — dropped by enemies on death. Collected by player contact.
## Drifts slowly with a floating bob effect. Attracted by magnet.
## Pooled via ObjectPool: activate with pool_activate() after acquire, and
## return it with despawn() instead of queue_free().

@export var orb_value: int = 1
@export var drift_speed: float = 40.0
## Direction the orb floats in. Set by the dying enemy so drops drift the
## same way the enemy was travelling.
var drift_direction: Vector2 = Vector2.DOWN

var bob_time: float = 0.0
var _entered_screen: bool = false
var _is_despawning: bool = false
var _lifetime_timer: Timer
var _pop_tween: Tween

## One-time setup: connects collision, attaches a screen-exit notifier, and
## creates the safety-net lifetime timer. Everything that must refresh on
## reuse lives in pool_activate().
func _ready() -> void:
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)
	# Safety net for orbs that never cross the screen (e.g. spawned at an
	# edge drifting outward) — the notifier alone would never free them.
	_lifetime_timer = Timer.new()
	_lifetime_timer.wait_time = 20.0
	_lifetime_timer.one_shot = true
	add_child(_lifetime_timer)
	_lifetime_timer.timeout.connect(despawn)

## Reuses the orb from the pool with fresh spawn values.
func pool_activate(spawn_position: Vector2, value: int, direction: Vector2 = Vector2.DOWN) -> void:
	_is_despawning = false
	global_position = spawn_position
	orb_value = value
	drift_direction = direction
	bob_time = 0.0
	_entered_screen = false
	collision_layer = 16
	collision_mask = 1
	monitoring = true
	monitorable = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	add_to_group("xp_orbs")
	_update_color()
	_lifetime_timer.start()

	# Spawn pop animation
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	scale = Vector2.ZERO
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Returns the orb to the pool after disabling its collision and physics.
func despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true
	visible = false
	call_deferred("_deactivate_for_pool")

## Disables and releases the orb after the current physics query finishes.
func _deactivate_for_pool() -> void:
	remove_from_group("xp_orbs")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	_lifetime_timer.stop()
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	ObjectPool.release(self)

## Updates the orb's sprite color based on its value tier:
## 1 = light blue, 2 = purple, 3+ = red.
func _update_color() -> void:
	var base_col: Color
	var edge_col: Color

	if orb_value == 1: # Light Blue
		base_col = Color(0.3, 0.95, 1.0, 1.0)
		edge_col = Color(0.1, 0.5, 0.8, 0.6)
	elif orb_value == 2: # Purple
		base_col = Color(0.7, 0.3, 1.0, 1.0)
		edge_col = Color(0.4, 0.1, 0.8, 0.6)
	else: # Red (3+)
		base_col = Color(1.0, 0.2, 0.3, 1.0)
		edge_col = Color(0.8, 0.1, 0.1, 0.6)

	if $Sprite2D.has_method("generate_texture"):
		$Sprite2D.generate_texture(base_col, edge_col)

## Drifts the orb along drift_direction (the spawning enemy's heading) and
## applies a gentle sine-wave bob perpendicular to the drift for a floating
## visual effect.
func _physics_process(delta: float) -> void:
	position += drift_direction * drift_speed * delta
	# Floating bob effect (delta-scaled so amplitude is frame-rate independent;
	# 24.0/s reproduces the original per-frame 0.4 nudge at 60 fps)
	bob_time += delta
	position += drift_direction.orthogonal() * sin(bob_time * 3.0) * 24.0 * delta

## Handles collision with the player — triggers collection.
func _on_area_entered(area: Area2D) -> void:
	if _is_despawning:
		return
	# Collected by direct player contact
	if area.is_in_group("player"):
		_collect()

## Emits the xp_orb_collected signal with this orb's value, spawns a
## particle collection effect, and returns the orb to the pool.
func _collect() -> void:
	AudioManager.play_xp_orb()
	SignalBus.xp_orb_collected.emit(orb_value)
	_spawn_collect_effect()
	despawn()

## Latches once the orb has been on screen. Orbs can drift in any direction
## now, so cleanup is based on having been visible at least once rather than
## on a fixed fall direction.
func _on_screen_entered() -> void:
	_entered_screen = true

## Despawns the orb when it leaves the screen in any direction after having
## been visible (prevents premature cleanup when spawned just off-screen).
func _on_screen_exited() -> void:
	if _entered_screen:
		despawn()

## Spawns a brief CPU particle burst at the orb's position using a color
## matching its value tier, providing satisfying collection feedback.
func _spawn_collect_effect() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0

	if orb_value == 1:
		particles.color = Color(0.3, 0.9, 1.0)
	elif orb_value == 2:
		particles.color = Color(0.7, 0.3, 1.0)
	else:
		particles.color = Color(1.0, 0.2, 0.3)

	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)
