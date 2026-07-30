extends Node2D
## Original procedural impact and explosion VFX.
##
## Every visible shape is drawn in-house at runtime. The effect deliberately
## avoids sprite sheets so pooled bursts can be recolored and scaled without
## carrying third-party texture dependencies.

static var _gradient: Gradient
const COMBAT_VFX_SHADER := preload("res://effects/shaders/vfx/combat_burst.gdshader")

enum EffectKind { IMPACT, EXPLOSION }

var _particles: CPUParticles2D
var _shader_material: ShaderMaterial
var _elapsed := 0.0
var _duration := 0.5
var _kind := EffectKind.EXPLOSION
var _small := false
var _burst_seed := 1
var _reduced_flashing := false


func _ready() -> void:
	_ensure_shader_material()
	_ensure_nodes()
	_set_idle_state()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		_set_idle_state()
		ObjectPool.release(self)


func _draw() -> void:
	if not visible:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	if _kind == EffectKind.IMPACT:
		_draw_impact(progress)
	else:
		_draw_explosion(progress)


## Starts a death/explosive-round burst at the requested world position.
func play_at(effect_position: Vector2, small: bool = false) -> void:
	_play_effect(effect_position, small, EffectKind.EXPLOSION)


## Starts the compact directional star used by ordinary projectile hits.
func play_impact_at(effect_position: Vector2) -> void:
	_play_effect(effect_position, true, EffectKind.IMPACT)


func _play_effect(effect_position: Vector2, small: bool, kind: EffectKind) -> void:
	_ensure_nodes()
	global_position = effect_position
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_kind = kind
	_small = small
	_elapsed = 0.0
	_duration = 0.24 if kind == EffectKind.IMPACT else 0.46 if small else 0.68
	_burst_seed = randi_range(1, 1_000_000)
	_reduced_flashing = bool(SaveManager.get_setting("reduced_flashing", false))
	_configure_shader_material()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)

	_configure_particles()
	_particles.restart()
	_particles.emitting = true
	queue_redraw()

	if kind == EffectKind.IMPACT:
		AudioManager.play_hit_marker()
	else:
		AudioManager.play_explosion(small)


func _ensure_nodes() -> void:
	if _particles != null:
		return
	_particles = CPUParticles2D.new()
	_particles.name = "ProceduralDebris"
	_particles.one_shot = true
	_particles.z_index = 1
	_particles.use_parent_material = true
	add_child(_particles)


func _ensure_shader_material() -> void:
	if _shader_material != null:
		return
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = COMBAT_VFX_SHADER
	material = _shader_material


func _configure_shader_material() -> void:
	_ensure_shader_material()
	var is_impact := _kind == EffectKind.IMPACT
	_shader_material.set_shader_parameter(
		"primary_color",
		Color(0.92, 0.06, 0.015) if not is_impact else Color(1.0, 0.30, 0.025)
	)
	_shader_material.set_shader_parameter(
		"secondary_color",
		Color(1.0, 0.38, 0.025) if not is_impact else Color(1.0, 0.72, 0.08)
	)
	_shader_material.set_shader_parameter("hot_color", Color(1.0, 0.96, 0.68))
	_shader_material.set_shader_parameter(
		"energy",
		0.68 if _reduced_flashing else 1.15 if _small else 1.28
	)
	_shader_material.set_shader_parameter("pixel_size", 2.0 if _small else 3.0)
	_shader_material.set_shader_parameter("dither_strength", 0.34 if is_impact else 0.46)
	_shader_material.set_shader_parameter("reduced_flashing", 1.0 if _reduced_flashing else 0.0)
	_shader_material.set_shader_parameter("phase_offset", float(_burst_seed % 1_000) * 0.01)


func _configure_particles() -> void:
	var is_impact := _kind == EffectKind.IMPACT
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 5 if is_impact else 9 if _small else 16
	_particles.lifetime = 0.16 if is_impact else 0.30 if _small else 0.46
	_particles.explosiveness = 0.98
	_particles.direction = Vector2.ZERO
	_particles.spread = 180.0
	_particles.initial_velocity_min = 34.0 if is_impact else 48.0 if _small else 72.0
	_particles.initial_velocity_max = 105.0 if is_impact else 145.0 if _small else 220.0
	_particles.gravity = Vector2(0.0, 16.0 if is_impact else 30.0)
	_particles.scale_amount_min = 1.0 if is_impact else 1.8
	_particles.scale_amount_max = 2.2 if is_impact else 4.8 if _small else 6.5
	_particles.color_ramp = _get_gradient()


func _draw_impact(progress: float) -> void:
	var expansion := _ease_out_cubic(progress)
	var fade := 1.0 - progress
	var flash_alpha := fade * (0.34 if _reduced_flashing else 0.92)
	var core_radius := lerpf(5.0, 1.0, progress)
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 0.96, 0.74, flash_alpha))

	for index in range(7):
		var angle := TAU * float(index) / 7.0 + (_noise(index) - 0.5) * 0.34
		var reach := lerpf(5.0, 20.0 + _noise(index + 17) * 11.0, expansion)
		var start := Vector2.from_angle(angle) * (2.0 + reach * 0.18)
		var end := Vector2.from_angle(angle) * reach
		var width := 2.5 if index % 2 == 0 else 1.5
		draw_line(start, end, Color(1.0, 0.72, 0.20, fade), width, true)

	var ring_radius := lerpf(3.0, 25.0, expansion)
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		0.0,
		TAU,
		28,
		Color(1.0, 0.34, 0.08, fade * 0.72),
		2.0,
		true
	)


func _draw_explosion(progress: float) -> void:
	var expansion := _ease_out_cubic(progress)
	var fade := clampf(1.0 - progress, 0.0, 1.0)
	var size_factor := 0.64 if _small else 1.0
	var shock_radius := lerpf(6.0, 72.0 * size_factor, expansion)
	var shock_width := lerpf(6.0, 1.2, progress)
	draw_arc(
		Vector2.ZERO,
		shock_radius,
		0.0,
		TAU,
		52,
		Color(1.0, 0.30, 0.06, fade * 0.74),
		shock_width,
		true
	)
	draw_arc(
		Vector2.ZERO,
		shock_radius * 0.72,
		0.0,
		TAU,
		44,
		Color(1.0, 0.78, 0.18, fade * 0.55),
		maxf(1.0, shock_width * 0.45),
		true
	)

	var bloom := sin(progress * PI)
	var flash_alpha := bloom * (0.18 if _reduced_flashing else 0.82) * fade
	draw_circle(
		Vector2.ZERO,
		lerpf(7.0, 29.0 * size_factor, bloom),
		Color(1.0, 0.94, 0.64, flash_alpha)
	)

	# Uneven overlapping fire cells keep each seeded burst energetic without
	# resembling a pre-authored sprite animation.
	for index in range(10 if _small else 15):
		var angle := TAU * _noise(index + 31)
		var radial := (8.0 + 33.0 * _noise(index + 61)) * size_factor * expansion
		var center := Vector2.from_angle(angle) * radial
		var cell_radius := (4.0 + 12.0 * _noise(index + 91)) * size_factor
		cell_radius *= lerpf(0.35, 1.0, bloom)
		var heat := _noise(index + 121)
		var color := Color(1.0, lerpf(0.22, 0.78, heat), 0.04, fade * 0.86)
		draw_circle(center, cell_radius, color)
		if heat > 0.56:
			draw_circle(center, cell_radius * 0.42, Color(1.0, 0.94, 0.56, fade * 0.9))

	# A few long fragments give the large explosion a readable silhouette.
	var streak_count := 6 if _small else 11
	for index in range(streak_count):
		var angle := TAU * _noise(index + 151)
		var reach := (32.0 + 62.0 * _noise(index + 181)) * size_factor * expansion
		var start := Vector2.from_angle(angle) * reach * 0.55
		var end := Vector2.from_angle(angle) * reach
		draw_line(start, end, Color(1.0, 0.48, 0.08, fade * 0.72), 2.0, true)


func _noise(index: int) -> float:
	var value := sin(float(_burst_seed + index * 1_103) * 12.9898) * 43_758.5453
	return value - floor(value)


func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _set_idle_state() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	queue_redraw()
	if is_instance_valid(_particles):
		_particles.emitting = false


func _get_gradient() -> Gradient:
	if _gradient == null:
		_gradient = Gradient.new()
		_gradient.colors = PackedColorArray([
			Color(1.0, 0.96, 0.58),
			Color(1.0, 0.38, 0.06),
			Color(0.25, 0.02, 0.01, 0.0),
		])
		_gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	return _gradient
