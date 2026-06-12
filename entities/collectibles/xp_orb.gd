extends Area2D
## XP Orb — dropped by enemies on death. Collected by player contact.
## Drifts downward slowly with a floating bob effect. Attracted by magnet.

@export var orb_value: int = 1
@export var drift_speed: float = 40.0

var bob_time: float = 0.0

## Initializes the orb: adds to the "xp_orbs" group, connects collision,
## attaches a screen-exit notifier, sets the color based on value tier,
## and plays a pop-in scale animation.
func _ready() -> void:
	add_to_group("xp_orbs")
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

	_update_color()

	# Spawn pop animation
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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

## Drifts the orb downward and applies a gentle horizontal sine-wave bob
## for a floating visual effect.
func _physics_process(delta: float) -> void:
	position.y += drift_speed * delta
	# Floating bob effect
	bob_time += delta
	position.x += sin(bob_time * 3.0) * 0.4

## Handles collision with the player — triggers collection.
func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	# Collected by direct player contact
	if area.is_in_group("player"):
		_collect()

## Emits the xp_orb_collected signal with this orb's value, spawns a
## particle collection effect, and frees the node.
func _collect() -> void:
	AudioManager.play_xp_orb()
	SignalBus.xp_orb_collected.emit(orb_value)
	_spawn_collect_effect()
	queue_free()

## Frees the orb when it exits the bottom of the screen (only if it has
## actually fallen below the viewport, not just spawned off-screen at top).
func _on_screen_exited() -> void:
	if global_position.y > 0:
		queue_free()

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
