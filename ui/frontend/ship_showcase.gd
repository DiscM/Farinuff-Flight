extends Control
## Decorative flight-deck framing and a quiet idle pose for the selected hull.
## The existing preview owns the model; other upgrade previews stay static.

const FRAME_INTERVAL := 1.0 / 30.0
const CYAN := Color(0.17, 0.95, 1.0)
const VIOLET := Color(0.58, 0.42, 1.0)

var _preview: ShipUpgradePreview
var _rest_transform := Transform3D.IDENTITY
var _elapsed := 0.0
var _frame_time := 0.0
var _reduced_motion := false
var _reduced_flashing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(_update_processing)
	SaveManager.settings_changed.connect(_apply_settings)
	_apply_settings()


func set_preview(preview: ShipUpgradePreview) -> void:
	_preview = preview
	add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rest_transform = _preview.get_assembly().transform
	_update_processing()


func _apply_settings() -> void:
	_reduced_motion = bool(SaveManager.get_setting("reduced_motion", false))
	_reduced_flashing = bool(SaveManager.get_setting("reduced_flashing", false))
	if _reduced_motion:
		_elapsed = 0.0
		if is_instance_valid(_preview):
			_preview.get_assembly().transform = _rest_transform
			_preview.get_preview_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_processing()
	queue_redraw()


func _update_processing() -> void:
	set_process(not _reduced_motion and is_visible_in_tree())


func _process(delta: float) -> void:
	_elapsed += delta
	_frame_time += delta
	if _frame_time < FRAME_INTERVAL:
		return
	_frame_time = fmod(_frame_time, FRAME_INTERVAL)
	if is_instance_valid(_preview):
		var assembly := _preview.get_assembly()
		var bank := Vector3(
			sin(_elapsed * 0.47) * 0.022,
			sin(_elapsed * 0.29) * 0.065,
			sin(_elapsed * 0.38) * 0.025
		)
		assembly.transform = _rest_transform
		assembly.basis = _rest_transform.basis * Basis.from_euler(bank)
		assembly.position.y += sin(_elapsed * 0.68) * 0.045
		# Refresh only this visible showcase, capped at 30 renders per second.
		_preview.get_preview_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.425
	if radius < 32.0:
		return
	var strength := 0.6 if _reduced_flashing else 1.0
	var quiet := Color(CYAN, 0.12 * strength)
	var line := Color(CYAN, 0.3 * strength)
	var accent := Color(CYAN, 0.55 * strength)
	# Broken arcs leave the planet and the hull silhouette visible between them.
	for quadrant in range(4):
		var start := float(quadrant) * TAU / 4.0 + 0.13
		draw_arc(center, radius, start, start + 0.98, 32, line, 1.0, true)
		draw_arc(center, radius * 0.91, start + 0.25, start + 0.56, 12, quiet, 1.0, true)
	for index in range(36):
		var direction := Vector2.from_angle(float(index) * TAU / 36.0)
		var tick_length := 7.0 if index % 3 == 0 else 3.0
		draw_line(center + direction * (radius + 5.0), center + direction * (radius + 5.0 + tick_length), quiet, 1.0, true)
	var orbit := _elapsed * 0.075 - PI * 0.7
	draw_arc(center, radius, orbit, orbit + 0.25, 12, accent, 2.0, true)
	draw_arc(center, radius, orbit + PI, orbit + PI + 0.15, 8, Color(VIOLET, 0.48 * strength), 2.0, true)
	# Open corners evoke a ship display without introducing extra controls.
	var extent := radius + 21.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var point: Vector2 = center + corner * extent
		draw_line(point, point - Vector2(corner.x * 18.0, 0), line, 1.0, true)
		draw_line(point, point - Vector2(0, corner.y * 18.0), line, 1.0, true)
