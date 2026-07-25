extends Node2D
## Explosion effect - pooled pixel burst with particle accents.

static var _gradient: Gradient
static var _flash_texture: Texture2D

const LARGE_EXPLOSION_TEXTURE := preload("res://assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Explosions/epic_explosion_001/epic_explosion_001_large_orange/spritesheet.png")
const SMALL_EXPLOSION_TEXTURE := preload("res://assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Explosions/stylized_explosion_001/stylized_explosion_001_small_yellow/spritesheet.png")
const IMPACT_TEXTURE := preload("res://assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Impacts/symmetrical_impact_004/symmetrical_impact_004_small_yellow/spritesheet.png")
const LARGE_FRAME_COUNT: int = 13
const SMALL_FRAME_COUNT: int = 9
const IMPACT_FRAME_COUNT: int = 8
const FRAME_TIME: float = 1.0 / 24.0

enum EffectKind { IMPACT, EXPLOSION }

var _sprite_sheet: Sprite2D
var _particles: CPUParticles2D
var _flash: Sprite2D
var _flash_tween: Tween
var _play_token: int = 0
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _frame_count: int = 1

## Sets up the reusable particle/flash children once, then leaves the node
## hidden and idle until play_at() is called.
func _ready() -> void:
	_ensure_nodes()
	_set_idle_state()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_sprite_sheet):
		return
	_frame_timer += delta
	while _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_frame_index += 1
		if _frame_index >= _frame_count:
			_frame_index = _frame_count - 1
			return
		_sprite_sheet.frame = _frame_index

## Starts the effect at the given position. A small variant keeps the same
## pooled node but trims the burst so it works for bullet impacts too.
func play_at(effect_position: Vector2, small: bool = false) -> void:
	_play_effect(effect_position, small, EffectKind.EXPLOSION)

## Starts a short hit-spark animation for non-explosive bullet impacts.
func play_impact_at(effect_position: Vector2) -> void:
	_play_effect(effect_position, true, EffectKind.IMPACT)

func _play_effect(effect_position: Vector2, small: bool, kind: EffectKind) -> void:
	_ensure_nodes()
	_play_token += 1
	global_position = effect_position
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_configure_effect(small, kind)
	if kind == EffectKind.IMPACT:
		AudioManager.play_hit_marker()
	else:
		AudioManager.play_explosion(small)
	_particles.restart()
	_particles.emitting = true
	_sprite_sheet.visible = true
	_flash.visible = true
	var release_delay := 0.38 if kind == EffectKind.IMPACT else 0.5 if small else 0.72
	var token := _play_token
	get_tree().create_timer(release_delay).timeout.connect(_on_release_timeout.bind(token))

## Builds the child nodes on first use and reuses them for every future play.
func _ensure_nodes() -> void:
	if _sprite_sheet == null:
		_sprite_sheet = Sprite2D.new()
		_sprite_sheet.name = "SpriteSheet"
		_sprite_sheet.centered = true
		add_child(_sprite_sheet)
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
func _configure_effect(small: bool, kind: EffectKind) -> void:
	var is_impact := kind == EffectKind.IMPACT
	var particle_amount := 8 if is_impact else 12 if small else 20
	var particle_lifetime := 0.22 if is_impact else 0.35 if small else 0.5
	var particle_min_velocity := 25.0 if is_impact else 45.0 if small else 60.0
	var particle_max_velocity := 95.0 if is_impact else 140.0 if small else 200.0
	var particle_min_scale := 0.8 if is_impact else 1.5 if small else 3.0
	var particle_max_scale := 2.0 if is_impact else 3.5 if small else 6.0
	var particle_gravity := Vector2(0, 12) if is_impact else Vector2(0, 25) if small else Vector2(0, 40)
	var flash_scale := Vector2(1.35, 1.35) if is_impact else Vector2(2.0, 2.0) if small else Vector2(3.0, 3.0)
	var flash_duration := 0.14 if is_impact else 0.2 if small else 0.3
	var flash_color := Color(1.0, 0.9, 0.55, 0.55) if is_impact else Color(1.0, 0.85, 0.5, 0.78) if small else Color(1.0, 0.9, 0.5, 0.8)

	if is_impact:
		_configure_sprite_sheet(IMPACT_TEXTURE, IMPACT_FRAME_COUNT, 1.0)
	elif small:
		_configure_sprite_sheet(SMALL_EXPLOSION_TEXTURE, SMALL_FRAME_COUNT, 1.15)
	else:
		_configure_sprite_sheet(LARGE_EXPLOSION_TEXTURE, LARGE_FRAME_COUNT, 0.78)

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

func _configure_sprite_sheet(texture: Texture2D, frame_count: int, sprite_scale: float) -> void:
	_sprite_sheet.texture = texture
	_sprite_sheet.hframes = frame_count
	_sprite_sheet.vframes = 1
	_sprite_sheet.frame = 0
	_sprite_sheet.scale = Vector2.ONE * sprite_scale
	_sprite_sheet.modulate = Color.WHITE
	_frame_count = frame_count
	_frame_index = 0
	_frame_timer = 0.0

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
	scale = Vector2.ONE
	modulate = Color.WHITE
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	if is_instance_valid(_sprite_sheet):
		_sprite_sheet.visible = false
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
