extends Node2D
## Original procedural one-shot VFX for boost and upgrade feedback.
##
## The legacy scene name is retained to keep pooling keys stable, but no
## sprites or external textures are used.

enum EffectKind { WARP, SPARKLE }

const COMBAT_VFX_SHADER := preload("res://effects/shaders/vfx/combat_burst.gdshader")

var _kind := EffectKind.WARP
var _elapsed := 0.0
var _duration := 0.4
var _effect_seed := 1
var _reduced_flashing := false
var _shader_material: ShaderMaterial


func _ready() -> void:
	_ensure_shader_material()
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
	if _kind == EffectKind.WARP:
		_draw_warp(progress)
	else:
		_draw_sparkle(progress)


func play_at(effect_position: Vector2, kind: EffectKind, effect_rotation: float = 0.0) -> void:
	global_position = effect_position
	rotation = effect_rotation
	scale = Vector2.ONE
	modulate = Color.WHITE
	_kind = kind
	_elapsed = 0.0
	_duration = 0.46 if kind == EffectKind.WARP else 0.52
	_effect_seed = randi_range(1, 1_000_000)
	_reduced_flashing = bool(SaveManager.get_setting("reduced_flashing", false))
	_configure_shader_material()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	queue_redraw()


func play_warp_at(effect_position: Vector2, direction: Vector2) -> void:
	var angle := direction.angle() + PI / 2.0 if not direction.is_zero_approx() else 0.0
	play_at(effect_position, EffectKind.WARP, angle)


func play_sparkle_at(effect_position: Vector2) -> void:
	play_at(effect_position, EffectKind.SPARKLE)


func _ensure_shader_material() -> void:
	if _shader_material != null:
		return
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = COMBAT_VFX_SHADER
	material = _shader_material


func _configure_shader_material() -> void:
	_ensure_shader_material()
	var is_warp := _kind == EffectKind.WARP
	_shader_material.set_shader_parameter(
		"primary_color",
		Color(0.02, 0.82, 1.0) if is_warp else Color(0.10, 0.94, 0.88)
	)
	_shader_material.set_shader_parameter(
		"secondary_color",
		Color(0.66, 0.12, 1.0) if is_warp else Color(1.0, 0.16, 0.62)
	)
	_shader_material.set_shader_parameter("hot_color", Color(0.90, 0.99, 1.0))
	_shader_material.set_shader_parameter("energy", 0.64 if _reduced_flashing else 1.18)
	_shader_material.set_shader_parameter("pixel_size", 2.0)
	_shader_material.set_shader_parameter("dither_strength", 0.40 if is_warp else 0.52)
	_shader_material.set_shader_parameter("reduced_flashing", 1.0 if _reduced_flashing else 0.0)
	_shader_material.set_shader_parameter("phase_offset", float(_effect_seed % 1_000) * 0.01)


func _draw_warp(progress: float) -> void:
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	var fade := 1.0 - progress
	var flash_limit := 0.32 if _reduced_flashing else 1.0

	# Three broken launch rings collapse into the departure vector.
	for ring_index in range(3):
		var delayed := clampf(progress * 1.35 - float(ring_index) * 0.12, 0.0, 1.0)
		var radius := lerpf(7.0 + ring_index * 5.0, 42.0 + ring_index * 10.0, delayed)
		var ring_alpha := (1.0 - delayed) * 0.74
		draw_arc(
			Vector2(0.0, 4.0 + delayed * 13.0),
			radius,
			-PI * 0.84,
			-PI * 0.16,
			20,
			Color(0.18, 0.92, 1.0, ring_alpha),
			3.0 - float(ring_index) * 0.45,
			true
		)
		draw_arc(
			Vector2(0.0, 4.0 + delayed * 13.0),
			radius,
			PI * 0.16,
			PI * 0.84,
			20,
			Color(0.58, 0.26, 1.0, ring_alpha * 0.8),
			2.0,
			true
		)

	# Tapered speed lines point opposite travel, making the dash direction
	# readable even when the ship is momentarily obscured.
	for index in range(9):
		var x := lerpf(-24.0, 24.0, float(index) / 8.0)
		x += (_noise(index) - 0.5) * 5.0
		var length := 26.0 + _noise(index + 19) * 44.0
		var start := Vector2(x * (1.0 - expansion * 0.35), 8.0 + expansion * 18.0)
		var end := start + Vector2(x * 0.18, length * expansion)
		var line_color := Color(0.20, 0.86, 1.0, fade * (0.45 + _noise(index + 39) * 0.5))
		draw_line(start, end, line_color, 1.2 + _noise(index + 59) * 1.8, true)

	var core_alpha := sin(progress * PI) * flash_limit
	var core := PackedVector2Array([
		Vector2(0.0, -18.0 - expansion * 8.0),
		Vector2(9.0 * fade, 5.0),
		Vector2(0.0, 18.0 + expansion * 20.0),
		Vector2(-9.0 * fade, 5.0),
	])
	draw_colored_polygon(core, Color(0.74, 0.98, 1.0, core_alpha * 0.78))


func _draw_sparkle(progress: float) -> void:
	var expansion := sin(progress * PI * 0.72)
	var fade := 1.0 - progress
	var flash_limit := 0.34 if _reduced_flashing else 1.0
	var palette := [
		Color(0.20, 0.94, 1.0),
		Color(0.70, 0.34, 1.0),
		Color(1.0, 0.28, 0.70),
	]

	for index in range(12):
		var angle := TAU * float(index) / 12.0 + (_noise(index) - 0.5) * 0.18
		var inner := lerpf(2.0, 13.0, expansion)
		var outer := lerpf(7.0, 37.0 + _noise(index + 17) * 14.0, expansion)
		var color: Color = palette[index % palette.size()]
		color.a = fade * 0.84
		draw_line(
			Vector2.from_angle(angle) * inner,
			Vector2.from_angle(angle) * outer,
			color,
			2.5 if index % 3 == 0 else 1.3,
			true
		)

	for orbit_index in range(3):
		var orbit_radius := lerpf(4.0, 17.0 + orbit_index * 8.0, expansion)
		var orbit_color: Color = palette[orbit_index]
		orbit_color.a = fade * 0.48
		draw_arc(
			Vector2.ZERO,
			orbit_radius,
			progress * TAU + orbit_index,
			progress * TAU + orbit_index + PI * 1.28,
			24,
			orbit_color,
			1.8,
			true
		)

	draw_circle(
		Vector2.ZERO,
		lerpf(2.0, 8.0, expansion),
		Color(0.88, 1.0, 1.0, fade * flash_limit)
	)


func _noise(index: int) -> float:
	var value := sin(float(_effect_seed + index * 977) * 12.9898) * 43_758.5453
	return value - floor(value)


func _set_idle_state() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	queue_redraw()
