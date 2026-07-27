extends Node2D
## Display-only, fully upgraded menu ship with local-space thrust and flight tweens.

signal launch_finished

const INTRO_DURATION := 1.25
const EXIT_DURATION := 0.72
const BASE_ROTATION := deg_to_rad(20.0)

@onready var sprite: Sprite2D = $Sprite2D

var _animation_time := 0.0
var _hover_time := 0.0
var _thrust_phase := 0.0
var _rest_position := Vector2.ZERO
var _display_scale := 2.5
var _intro_active := false
var _exit_active := false
var _thrust_strength := 0.72
var _motion_tween: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	_animation_time += delta
	_thrust_phase += delta * (15.0 if _exit_active else 9.0)
	sprite.frame = int(_animation_time * 8.0) % 4

	if not _intro_active and not _exit_active:
		_hover_time += delta
		position = _rest_position + Vector2(
			sin(_hover_time * 0.72) * 4.0,
			sin(_hover_time * 1.16) * 5.0
		)
		rotation = BASE_ROTATION + sin(_hover_time * 0.63) * 0.012
	queue_redraw()


func set_layout(viewport_size: Vector2, animate_intro: bool) -> void:
	var layout_scale := clampf(minf(viewport_size.x / 1238.0, viewport_size.y / 720.0), 0.72, 1.35)
	_display_scale = 2.45 * layout_scale
	_rest_position = Vector2(viewport_size.x * 0.80, viewport_size.y * 0.57)

	if _exit_active:
		return
	if _intro_active and is_instance_valid(_motion_tween):
		_motion_tween.kill()
		_intro_active = false

	scale = Vector2.ONE * _display_scale
	rotation = BASE_ROTATION
	if animate_intro:
		play_intro(viewport_size)
	else:
		position = _rest_position


func play_intro(viewport_size: Vector2) -> void:
	_intro_active = true
	_thrust_strength = 1.2
	position = Vector2(viewport_size.x * 0.42, viewport_size.y + 170.0 * _display_scale)
	scale = Vector2.ONE * (_display_scale * 0.78)
	modulate = Color(1.0, 1.0, 1.0, 0.0)

	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUART)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "position", _rest_position, INTRO_DURATION)
	_motion_tween.tween_property(self, "scale", Vector2.ONE * _display_scale, INTRO_DURATION)
	_motion_tween.tween_property(self, "modulate:a", 1.0, 0.32)
	_motion_tween.chain().tween_callback(_finish_intro)


func fly_out(viewport_size: Vector2) -> void:
	if _exit_active:
		return
	_exit_active = true
	_intro_active = false
	_thrust_strength = 1.65
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()

	var exit_position := Vector2(viewport_size.x + 240.0, -220.0)
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUART)
	_motion_tween.set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(self, "position", exit_position, EXIT_DURATION)
	_motion_tween.tween_property(self, "scale", Vector2.ONE * (_display_scale * 1.08), EXIT_DURATION)
	_motion_tween.chain().tween_callback(func(): launch_finished.emit())


func _finish_intro() -> void:
	_intro_active = false
	_thrust_strength = 0.72
	_hover_time = 0.0


func _draw() -> void:
	var flicker := 0.88 + sin(_thrust_phase) * 0.10
	var length := _thrust_strength * flicker
	for nozzle_x in [-15.0, 15.0]:
		var nozzle := Vector2(nozzle_x, 30.0)
		var outer_end := nozzle + Vector2(0.0, 42.0 + 44.0 * length)
		var inner_end := nozzle + Vector2(0.0, 25.0 + 24.0 * length)
		var outer := PackedVector2Array([
			nozzle + Vector2(-4.5, 0.0),
			nozzle + Vector2(4.5, 0.0),
			outer_end + Vector2(2.0, 0.0),
			outer_end + Vector2(0.0, 10.0),
			outer_end + Vector2(-2.0, 0.0),
		])
		var inner := PackedVector2Array([
			nozzle + Vector2(-2.2, 0.0),
			nozzle + Vector2(2.2, 0.0),
			inner_end + Vector2(1.0, 0.0),
			inner_end + Vector2(0.0, 5.0),
			inner_end + Vector2(-1.0, 0.0),
		])
		draw_colored_polygon(outer, Color(0.10, 0.78, 1.0, 0.40))
		draw_colored_polygon(inner, Color(0.82, 0.98, 1.0, 0.92))

		for pixel_index in range(5):
			var distance := 45.0 + pixel_index * 8.0 + fmod(_thrust_phase * 2.0, 7.0)
			var pixel_alpha := maxf(0.08, 0.28 - pixel_index * 0.04)
			draw_rect(
				Rect2(Vector2(nozzle_x - 1.0, distance * length), Vector2(2.0, 3.0)),
				Color(0.18, 0.92, 1.0, pixel_alpha)
			)
