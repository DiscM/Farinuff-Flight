extends Node2D
## Explosion effect - pooled particle burst with a short flash.

static var _gradient: Gradient
static var _flash_texture: Texture2D

var _particles: CPUParticles2D
var _flash: Sprite2D
var _flash_tween: Tween
var _play_token: int = 0

## Sets up the reusable particle/flash children once, then leaves the node
## hidden and idle until play_at() is called.
func _ready() -> void:
	_ensure_nodes()
	_set_idle_state()

## Starts the effect at the given position. A small variant keeps the same
## pooled node but trims the burst so it works for bullet impacts too.
func play_at(effect_position: Vector2, small: bool = false) -> void:
	_ensure_nodes()
	_play_token += 1
	global_position = effect_position
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_configure_effect(small)
	_particles.restart()
	_particles.emitting = true
	_flash.visible = true
	var release_delay := 0.45 if small else 0.7
	var token := _play_token
	get_tree().create_timer(release_delay).timeout.connect(_on_release_timeout.bind(token))

## Builds the child nodes on first use and reuses them for every future play.
func _ensure_nodes() -> void:
	if _particles == null:
		_particles = CPUParticles2D.new()
		_particles.name = "Particles"
		_particles.one_shot = true
		add_child(_particles)
	if _flash == null:
		_flash = Sprite2D.new()
		_flash.name = "Flash"
		_flash.texture = _get_flash_texture()
		add_child(_flash)

## Configures the particle and flash properties for either the small impact
## burst or the larger death burst.
func _configure_effect(small: bool) -> void:
	var particle_amount := 12 if small else 20
	var particle_lifetime := 0.35 if small else 0.5
	var particle_min_velocity := 45.0 if small else 60.0
	var particle_max_velocity := 140.0 if small else 200.0
	var particle_min_scale := 1.5 if small else 3.0
	var particle_max_scale := 3.5 if small else 6.0
	var particle_gravity := Vector2(0, 25) if small else Vector2(0, 40)
	var flash_scale := Vector2(2.0, 2.0) if small else Vector2(3.0, 3.0)
	var flash_duration := 0.2 if small else 0.3
	var flash_color := Color(1.0, 0.85, 0.5, 0.78) if small else Color(1.0, 0.9, 0.5, 0.8)

	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = particle_amount
	_particles.lifetime = particle_lifetime
	_particles.explosiveness = 0.95 if small else 0.98
	_particles.direction = Vector2.ZERO
	_particles.spread = 180.0
	_particles.initial_velocity_min = particle_min_velocity
	_particles.initial_velocity_max = particle_max_velocity
	_particles.gravity = particle_gravity
	_particles.scale_amount_min = particle_min_scale
	_particles.scale_amount_max = particle_max_scale
	_particles.color_ramp = _get_gradient()
	_particles.color = Color(1.0, 0.6, 0.1) if not small else Color(1.0, 0.7, 0.2)

	_flash.texture = _get_flash_texture()
	_flash.modulate = flash_color
	_flash.scale = flash_scale
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "scale", Vector2(0.1, 0.1), flash_duration)
	_flash_tween.parallel().tween_property(_flash, "modulate:a", 0.0, flash_duration)

## Returns the effect to the pool if the current play sequence is still the
## latest one, preventing stale timers from reclaiming a reused node.
func _on_release_timeout(token: int) -> void:
	if token != _play_token:
		return
	_set_idle_state()
	ObjectPool.release(self)

## Hides the effect and stops the active particle burst so the node can be
## safely stored in the pool.
func _set_idle_state() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_particles):
		_particles.emitting = false
	if is_instance_valid(_flash):
		_flash.visible = false
		_flash.modulate.a = 0.0

## Creates a shared gradient for the explosion particles.
func _get_gradient() -> Gradient:
	if _gradient == null:
		_gradient = Gradient.new()
		_gradient.colors = PackedColorArray([
			Color(1.0, 0.9, 0.3),
			Color(1.0, 0.4, 0.1),
			Color(0.4, 0.1, 0.05, 0.0)
		])
		_gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	return _gradient

## Creates a shared flash texture so the pooled effect does not rebuild it on
## every play.
func _get_flash_texture() -> Texture2D:
	if _flash_texture == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.9, 0.5, 0.8))
		_flash_texture = ImageTexture.create_from_image(img)
	return _flash_texture
