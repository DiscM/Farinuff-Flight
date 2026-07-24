extends Node2D
class_name ShipUpgradeVisuals
## Shared procedural renderer for every elite ship-upgrade visual.
##
## Two instances sandwich the base ship sprite. The same static drawing
## helpers are reused by popup previews and boost afterimages.

enum VisualLayer {
	BACK,
	FRONT,
}

const FRAME_SIZE := Vector2(128.0, 128.0)
const VISUAL_ENVELOPE := Rect2(-52.0, -48.0, 104.0, 96.0)
const OUTLINE := Color(0.15, 0.20, 0.29)
const TITANIUM := Color(0.72, 0.76, 0.82)
const DARK_METAL := Color(0.26, 0.30, 0.38)

const UPGRADE_COLORS := {
	"twin_cannons": Color(1.0, 0.8, 0.2),
	"auto_aim": Color(0.3, 1.0, 0.5),
	"drone_escort": Color(0.4, 0.85, 1.0),
	"hull_plating": Color(0.8, 0.55, 1.0),
	"afterburner": Color(1.0, 0.45, 0.15),
	"spread_shot_elite": Color(1.0, 0.55, 0.9),
	"shield_burst": Color(0.3, 0.8, 1.0),
	"magnet_field": Color(1.0, 0.75, 0.1),
	"overclock": Color(0.9, 1.0, 0.2),
	"rear_gunner": Color(1.0, 0.35, 0.35),
}

const DRAW_ORDER: Array[String] = [
	"hull_plating",
	"afterburner",
	"magnet_field",
	"shield_burst",
	"twin_cannons",
	"spread_shot_elite",
	"overclock",
	"auto_aim",
	"rear_gunner",
]

# Bounds are expressed in the base sprite's 128×128 source coordinate system,
# centered on the ship. Drone Escort is intentionally external.
const UPGRADE_BOUNDS := {
	"twin_cannons": Rect2(-20.0, -27.0, 40.0, 18.0),
	"auto_aim": Rect2(-9.0, -44.0, 18.0, 18.0),
	"hull_plating": Rect2(-41.0, -17.0, 82.0, 48.0),
	"afterburner": Rect2(-21.0, 18.0, 42.0, 30.0),
	"spread_shot_elite": Rect2(-51.0, -2.0, 102.0, 20.0),
	"shield_burst": Rect2(-35.0, -10.0, 70.0, 28.0),
	"magnet_field": Rect2(-45.0, 9.0, 90.0, 20.0),
	"overclock": Rect2(-12.0, -2.0, 24.0, 31.0),
	"rear_gunner": Rect2(-7.0, 20.0, 14.0, 28.0),
}

const MUZZLE_ANCHORS := {
	"center": Vector2(0.0, -35.0),
	"twin_left": Vector2(-14.0, -27.0),
	"twin_right": Vector2(14.0, -27.0),
	"spread_left": Vector2(-48.0, 1.0),
	"spread_right": Vector2(48.0, 1.0),
	"rear": Vector2(0.0, 45.0),
}

# The base strip bakes a four-frame bob and ±4° roll into the artwork.
const FRAME_BOB: Array[float] = [0.0, 2.13, 0.0, -2.13]
const FRAME_ROLL: Array[float] = [0.0, 4.0, 0.0, -4.0]

@export var visual_layer: VisualLayer = VisualLayer.FRONT

var _source_sprite: Sprite2D
var _active_upgrades: Array[String] = []
var _last_frame := -1
var _muzzle_timers: Dictionary = {}
var _runtime_state := {
	"afterburner_boost": false,
	"overclock_active": false,
	"overclock_phase": 0.0,
	"shield_charge": 0.0,
	"magnet_active": false,
	"auto_aim_angle": 0.0,
	"auto_aim_locked": false,
}
var _installation_id := ""
var _installation_progress := 1.0
var _installation_pulse := 0.0
var _auto_aim_acquisition_pulse := 0.0
var _debug_flags := {
	"envelope": false,
	"anchors": false,
	"muzzles": false,
	"collision": false,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10
	_source_sprite = get_node_or_null("../Sprite2D") as Sprite2D
	z_index = -1 if visual_layer == VisualLayer.BACK else 1
	_sync_to_source_frame(true)


func _process(delta: float) -> void:
	_sync_to_source_frame()
	if is_instance_valid(_source_sprite):
		modulate = _source_sprite.modulate
		visible = _source_sprite.visible

	if _auto_aim_acquisition_pulse > 0.0:
		_auto_aim_acquisition_pulse = maxf(_auto_aim_acquisition_pulse - delta, 0.0)
		queue_redraw()

	var flash_changed := false
	for id in _muzzle_timers.keys():
		var remaining: float = maxf(float(_muzzle_timers[id]) - delta, 0.0)
		if remaining <= 0.0:
			_muzzle_timers.erase(id)
			flash_changed = true
		else:
			_muzzle_timers[id] = remaining
	if flash_changed:
		queue_redraw()


func _sync_to_source_frame(force: bool = false) -> void:
	if not is_instance_valid(_source_sprite):
		return
	var current_frame := clampi(_source_sprite.frame, 0, 3)
	if not force and current_frame == _last_frame:
		return
	_last_frame = current_frame
	scale = _source_sprite.scale
	position = Vector2(0.0, FRAME_BOB[current_frame] * _source_sprite.scale.y)
	rotation = deg_to_rad(FRAME_ROLL[current_frame])


func set_active_upgrades(upgrade_ids: Array[String]) -> void:
	_active_upgrades.clear()
	for id in upgrade_ids:
		if not _active_upgrades.has(id):
			_active_upgrades.append(id)
	queue_redraw()


func set_runtime_state(state: Dictionary) -> void:
	var changed := false
	for key in _runtime_state.keys():
		if not state.has(key):
			continue
		var next_value: Variant = state[key]
		if key == "shield_charge":
			next_value = snappedf(float(next_value), 0.125)
		elif key == "auto_aim_angle":
			next_value = snappedf(float(next_value), 0.05)
		elif key == "overclock_phase":
			next_value = snappedf(float(next_value), 0.25)
		if _runtime_state[key] != next_value:
			if key == "auto_aim_locked" and bool(next_value) and not bool(_runtime_state[key]):
				_auto_aim_acquisition_pulse = 0.22
			_runtime_state[key] = next_value
			changed = true
	if changed:
		queue_redraw()


func trigger_muzzle(module_id: String) -> void:
	_muzzle_timers[module_id] = 0.09
	queue_redraw()


func set_installation(upgrade_id: String, progress: float, pulse: float = 0.0) -> void:
	_installation_id = upgrade_id
	_installation_progress = clampf(progress, 0.0, 1.0)
	_installation_pulse = clampf(pulse, 0.0, 1.0)
	queue_redraw()


func finish_installation() -> void:
	_installation_id = ""
	_installation_progress = 1.0
	_installation_pulse = 0.0
	queue_redraw()


func set_debug_flag(flag: String, enabled: bool) -> void:
	if not _debug_flags.has(flag):
		return
	_debug_flags[flag] = enabled
	queue_redraw()


func _draw() -> void:
	var state := _runtime_state.duplicate()
	state["muzzle_timers"] = _muzzle_timers
	state["installation_id"] = _installation_id
	state["installation_progress"] = _installation_progress
	state["installation_pulse"] = _installation_pulse
	state["auto_aim_acquisition_pulse"] = _auto_aim_acquisition_pulse
	draw_upgrade_layer(self, _active_upgrades, visual_layer, state)
	if visual_layer == VisualLayer.FRONT:
		_draw_debug(self, _debug_flags)


static func get_color(upgrade_id: String) -> Color:
	return UPGRADE_COLORS.get(upgrade_id, Color.WHITE)


static func get_muzzle_anchor(anchor_id: String) -> Vector2:
	return MUZZLE_ANCHORS.get(anchor_id, Vector2.ZERO)


func get_player_local_muzzle(anchor_id: String) -> Vector2:
	return transform * get_muzzle_anchor(anchor_id)


static func get_combined_bounds(upgrade_ids: Array[String]) -> Rect2:
	var found := false
	var combined := Rect2()
	for id in upgrade_ids:
		if not UPGRADE_BOUNDS.has(id):
			continue
		var bounds: Rect2 = UPGRADE_BOUNDS[id]
		if not found:
			combined = bounds
			found = true
		else:
			combined = combined.merge(bounds)
	return combined


static func bounds_fit_envelope(upgrade_ids: Array[String]) -> bool:
	var bounds := get_combined_bounds(upgrade_ids)
	if bounds.size == Vector2.ZERO:
		return true
	return VISUAL_ENVELOPE.encloses(bounds)


static func draw_drone(
	canvas: CanvasItem,
	offset: Vector2 = Vector2.ZERO,
	alpha: float = 1.0,
	fill_factor: float = 1.0,
	outline_pulse: float = 0.0
) -> void:
	var color := get_color("drone_escort")
	var outline := OUTLINE
	if outline_pulse > 0.0:
		outline = color.lightened(clampf(outline_pulse, 0.0, 1.0) * 0.35)
	var body: Array[Vector2] = _offset_points([
		Vector2(0, -8), Vector2(4, -1), Vector2(3, 6),
		Vector2(0, 8), Vector2(-3, 6), Vector2(-4, -1),
	], offset)
	var left_wing: Array[Vector2] = _offset_points([
		Vector2(-4, 0), Vector2(-8, 3), Vector2(-4, 5), Vector2(-1, 2),
	], offset)
	var right_wing: Array[Vector2] = _offset_points([
		Vector2(4, 0), Vector2(8, 3), Vector2(4, 5), Vector2(1, 2),
	], offset)
	_poly(canvas, left_wing, Color(0.42, 0.48, 0.58), outline, alpha, fill_factor)
	_poly(canvas, right_wing, Color(0.42, 0.48, 0.58), outline, alpha, fill_factor)
	_poly(canvas, body, Color(0.78, 0.84, 0.90), outline, alpha, fill_factor)
	_circle(canvas, offset + Vector2(0, 1), 2.0, color, alpha * 0.8 * fill_factor)
	_line(
		canvas,
		[offset + Vector2(0, 5), offset + Vector2(0, 9)],
		color,
		1.5,
		alpha * 0.75 * fill_factor
	)


static func draw_drone_preview(canvas: CanvasItem, alpha: float = 1.0, highlighted: bool = false) -> void:
	draw_drone(
		canvas,
		Vector2(47.0, -14.0),
		alpha,
		1.0,
		1.0 if highlighted else 0.0
	)


static func draw_upgrade_layer(
	canvas: CanvasItem,
	upgrade_ids: Array[String],
	layer: VisualLayer,
	state: Dictionary = {},
	highlight_id: String = "",
	dim_existing: bool = false
) -> void:
	for id in DRAW_ORDER:
		if not upgrade_ids.has(id):
			continue
		var alpha := 1.0
		if dim_existing and id != highlight_id:
			alpha = 0.30
		elif highlight_id != "" and id == highlight_id:
			alpha = 1.0

		var fill_factor := 1.0
		var outline_override := Color.TRANSPARENT
		if str(state.get("installation_id", "")) == id:
			fill_factor = float(state.get("installation_progress", 1.0))
			outline_override = get_color(id).lightened(float(state.get("installation_pulse", 0.0)) * 0.4)

		match id:
			"hull_plating":
				if layer == VisualLayer.FRONT:
					_draw_hull_plating(canvas, alpha, fill_factor, outline_override)
			"afterburner":
				if layer == VisualLayer.BACK:
					_draw_afterburner(
						canvas,
						alpha,
						fill_factor,
						outline_override,
						bool(state.get("afterburner_boost", false)),
						not bool(state.get("omit_transients", false))
					)
			"magnet_field":
				if layer == VisualLayer.FRONT:
					_draw_magnet(canvas, alpha, fill_factor, outline_override, bool(state.get("magnet_active", false)))
			"shield_burst":
				if layer == VisualLayer.FRONT:
					_draw_shield_projectors(canvas, alpha, fill_factor, outline_override, float(state.get("shield_charge", 0.0)))
			"twin_cannons":
				if layer == VisualLayer.FRONT:
					_draw_twin_cannons(canvas, alpha, fill_factor, outline_override, _flash_active(state, id))
			"spread_shot_elite":
				if layer == VisualLayer.FRONT:
					_draw_spread_emitters(canvas, alpha, fill_factor, outline_override, _flash_active(state, id))
			"overclock":
				if layer == VisualLayer.FRONT:
					_draw_overclock(
						canvas,
						alpha,
						fill_factor,
						outline_override,
						bool(state.get("overclock_active", false)),
						float(state.get("overclock_phase", 0.0))
					)
			"auto_aim":
				if layer == VisualLayer.FRONT:
					_draw_auto_aim(
						canvas,
						alpha,
						fill_factor,
						outline_override,
						float(state.get("auto_aim_angle", 0.0)),
						bool(state.get("auto_aim_locked", false)),
						float(state.get("auto_aim_acquisition_pulse", 0.0))
					)
			"rear_gunner":
				if layer == VisualLayer.FRONT:
					_draw_rear_gunner(canvas, alpha, fill_factor, outline_override, _flash_active(state, id))


static func _flash_active(state: Dictionary, id: String) -> bool:
	var timers: Dictionary = state.get("muzzle_timers", {})
	return float(timers.get(id, 0.0)) > 0.0


static func _draw_hull_plating(canvas: CanvasItem, alpha: float, fill: float, outline: Color) -> void:
	var seam := UPGRADE_COLORS["hull_plating"]
	for side in [-1.0, 1.0]:
		_poly(canvas, _mirror([
			Vector2(9, -15), Vector2(15, -8), Vector2(14, 17),
			Vector2(9, 27), Vector2(8, 17), Vector2(10, -2),
		], side), DARK_METAL, outline, alpha, fill)
		_line(canvas, _mirror([
			Vector2(11, -10), Vector2(13, -5), Vector2(12, 15), Vector2(9, 22),
		], side), seam, 1.1, alpha * 0.65)
		_poly(canvas, _mirror([
			Vector2(17, -5), Vector2(40, 3), Vector2(34, 8), Vector2(17, 2),
		], side), Color(0.37, 0.41, 0.49), outline, alpha, fill)


static func _draw_afterburner(
	canvas: CanvasItem,
	alpha: float,
	fill: float,
	outline: Color,
	boosted: bool,
	include_exhaust: bool
) -> void:
	var accent := UPGRADE_COLORS["afterburner"]
	var flame_length := 15.0 if boosted else 8.0
	for side: float in [-1.0, 1.0]:
		var x: float = 15.0 * side
		_poly(canvas, [
			Vector2(x - 4.0, 18), Vector2(x + 4.0, 18),
			Vector2(x + 5.0, 31), Vector2(x - 5.0, 31),
		], DARK_METAL, outline, alpha, fill)
		if include_exhaust:
			_poly(canvas, [
				Vector2(x - 3.0, 29), Vector2(x + 3.0, 29), Vector2(x, 29 + flame_length),
			], accent, accent.lightened(0.25), alpha * (0.85 if boosted else 0.55), fill)
			_circle(canvas, Vector2(x, 29), 2.1, Color.WHITE, alpha * 0.65 * fill)


static func _draw_twin_cannons(canvas: CanvasItem, alpha: float, fill: float, outline: Color, firing: bool) -> void:
	var accent := UPGRADE_COLORS["twin_cannons"]
	for side: float in [-1.0, 1.0]:
		var x: float = 14.0 * side
		_poly(canvas, [
			Vector2(x - 4.0, -22), Vector2(x + 4.0, -22),
			Vector2(x + 3.0, -10), Vector2(x - 3.0, -10),
		], TITANIUM, outline, alpha, fill)
		_poly(canvas, [
			Vector2(x - 2.0, -27), Vector2(x + 2.0, -27),
			Vector2(x + 2.0, -20), Vector2(x - 2.0, -20),
		], DARK_METAL, outline, alpha, fill)
		_line(canvas, [Vector2(x - 2.0, -18), Vector2(x + 2.0, -18)], accent, 1.4, alpha * 0.75)
		if firing:
			_poly(canvas, [
				Vector2(x - 3.0, -27), Vector2(x + 3.0, -27), Vector2(x, -34),
			], accent.lightened(0.35), accent, alpha, 1.0)


static func _draw_auto_aim(
	canvas: CanvasItem,
	alpha: float,
	fill: float,
	outline: Color,
	target_angle: float,
	locked: bool,
	acquisition_pulse: float
) -> void:
	var accent := UPGRADE_COLORS["auto_aim"]
	_poly(canvas, [
		Vector2(-5, -34), Vector2(0, -38), Vector2(5, -34),
		Vector2(4, -28), Vector2(0, -26), Vector2(-4, -28),
	], accent.darkened(0.12), outline, alpha, fill)
	_line(canvas, [Vector2(-4, -36), Vector2(-8, -44)], TITANIUM, 1.4, alpha)
	_line(canvas, [Vector2(4, -36), Vector2(8, -44)], TITANIUM, 1.4, alpha)
	var indicator := Vector2(0, -5).rotated(target_angle)
	_line(canvas, [Vector2(0, -32), Vector2(0, -32) + indicator], accent.lightened(0.3), 1.6, alpha)
	if locked:
		_circle(canvas, Vector2(0, -32), 3.2, accent, alpha * 0.25 * fill)
	if acquisition_pulse > 0.0:
		var pulse_progress := 1.0 - acquisition_pulse / 0.22
		var pulse_radius := lerpf(4.0, 8.0, pulse_progress)
		var pulse_color := accent
		pulse_color.a = alpha * (1.0 - pulse_progress) * 0.7
		canvas.draw_arc(Vector2(0, -32), pulse_radius, 0.0, TAU, 16, pulse_color, 1.2, true)


static func _draw_spread_emitters(canvas: CanvasItem, alpha: float, fill: float, outline: Color, firing: bool) -> void:
	var accent := UPGRADE_COLORS["spread_shot_elite"]
	for side in [-1.0, 1.0]:
		_poly(canvas, _mirror([
			Vector2(43, 0), Vector2(49, -2), Vector2(51, 11), Vector2(47, 17), Vector2(44, 9),
		], side), DARK_METAL, outline, alpha, fill)
		_line(canvas, _mirror([Vector2(47, 1), Vector2(49, 11)], side), accent, 2.0, alpha * 0.8)
		if firing:
			_poly(canvas, _mirror([
				Vector2(47, -1), Vector2(51, 0), Vector2(51, -8),
			], side), accent.lightened(0.3), accent, alpha, 1.0)


static func _draw_shield_projectors(
	canvas: CanvasItem,
	alpha: float,
	fill: float,
	outline: Color,
	charge: float
) -> void:
	var accent := UPGRADE_COLORS["shield_burst"]
	var charge_alpha := alpha * lerpf(0.45, 0.95, maxf((charge - 0.75) / 0.25, 0.0))
	for side in [-1.0, 1.0]:
		_poly(canvas, _mirror([
			Vector2(25, -9), Vector2(31, -6), Vector2(35, 3),
			Vector2(33, 14), Vector2(29, 18), Vector2(30, 7), Vector2(27, -1),
		], side), Color(0.25, 0.38, 0.48), outline, alpha, fill)
		_line(canvas, _mirror([
			Vector2(29, -5), Vector2(33, 3), Vector2(31, 13),
		], side), accent, 2.0, charge_alpha)


static func _draw_magnet(canvas: CanvasItem, alpha: float, fill: float, outline: Color, active: bool) -> void:
	var accent := UPGRADE_COLORS["magnet_field"]
	for side in [-1.0, 1.0]:
		for y in [12.0, 16.0, 20.0]:
			_line(canvas, _mirror([Vector2(30, y), Vector2(39, y + 2)], side), accent, 1.5, alpha * 0.7)
		_line(canvas, _mirror([
			Vector2(39, 13), Vector2(44, 15), Vector2(44, 23), Vector2(41, 25),
		], side), accent, 1.7, alpha)
	if active:
		_circle(canvas, Vector2(-35, 8), 1.6, accent, alpha * 0.65 * fill)
		_circle(canvas, Vector2(36, 25), 1.2, accent, alpha * 0.45 * fill)


static func _draw_overclock(
	canvas: CanvasItem,
	alpha: float,
	fill: float,
	outline: Color,
	active: bool,
	phase: float
) -> void:
	var accent := UPGRADE_COLORS["overclock"]
	var segment_index := 0
	for y in [0.0, 6.0, 12.0, 18.0]:
		var lit := active and phase >= float(segment_index) / 4.0
		var segment_color := accent.lightened(0.18) if lit else accent.darkened(0.18)
		_poly(canvas, [
			Vector2(-7, y), Vector2(-3, y - 2), Vector2(-3, y + 3), Vector2(-7, y + 5),
		], segment_color, outline, alpha, fill)
		_poly(canvas, [
			Vector2(7, y), Vector2(3, y - 2), Vector2(3, y + 3), Vector2(7, y + 5),
		], segment_color, outline, alpha, fill)
		segment_index += 1
	var fin_x := 12.0 if active else 8.0
	_poly(canvas, [Vector2(-5, 22), Vector2(-fin_x, 25), Vector2(-5, 28)], DARK_METAL, outline, alpha, fill)
	_poly(canvas, [Vector2(5, 22), Vector2(fin_x, 25), Vector2(5, 28)], DARK_METAL, outline, alpha, fill)
	if active:
		_line(canvas, [Vector2(-10, 7), Vector2(-5, 10), Vector2(-9, 14)], accent.lightened(0.35), 1.2, alpha)
		_line(canvas, [Vector2(10, 15), Vector2(5, 18), Vector2(9, 21)], accent.lightened(0.35), 1.2, alpha)


static func _draw_rear_gunner(canvas: CanvasItem, alpha: float, fill: float, outline: Color, firing: bool) -> void:
	var accent := UPGRADE_COLORS["rear_gunner"]
	_poly(canvas, [
		Vector2(-6, 20), Vector2(6, 20), Vector2(5, 34), Vector2(-5, 34),
	], DARK_METAL, outline, alpha, fill)
	_poly(canvas, [
		Vector2(-2.5, 31), Vector2(2.5, 31), Vector2(2.0, 45), Vector2(-2.0, 45),
	], TITANIUM, outline, alpha, fill)
	_circle(canvas, Vector2(0, 28), 2.0, accent, alpha * 0.8 * fill)
	if firing:
		_poly(canvas, [
			Vector2(-3, 45), Vector2(3, 45), Vector2(0, 51),
		], accent.lightened(0.35), accent, alpha, 1.0)


static func _draw_debug(canvas: CanvasItem, flags: Dictionary) -> void:
	if bool(flags.get("envelope", false)):
		canvas.draw_rect(VISUAL_ENVELOPE, Color(1.0, 0.85, 0.2, 0.75), false, 1.2, true)
	if bool(flags.get("anchors", false)):
		for id in UPGRADE_BOUNDS:
			var bounds: Rect2 = UPGRADE_BOUNDS[id]
			_cross(canvas, bounds.get_center(), Color(0.3, 1.0, 0.5, 0.85))
	if bool(flags.get("muzzles", false)):
		for id in MUZZLE_ANCHORS:
			_circle(canvas, MUZZLE_ANCHORS[id], 2.1, Color(1.0, 0.35, 0.35), 0.8)
	if bool(flags.get("collision", false)):
		var color := Color(1.0, 0.2, 0.25, 0.85)
		var capsule_points := PackedVector2Array()
		var radius := 16.0
		var straight_half := 6.0
		for index in range(13):
			var angle := PI + PI * float(index) / 12.0
			capsule_points.append(Vector2(0.0, -straight_half) + Vector2.from_angle(angle) * radius)
		for index in range(13):
			var angle := PI * float(index) / 12.0
			capsule_points.append(Vector2(0.0, straight_half) + Vector2.from_angle(angle) * radius)
		capsule_points.append(capsule_points[0])
		if canvas is Node2D:
			var inverse_visual_transform := (canvas as Node2D).transform.affine_inverse()
			for index in range(capsule_points.size()):
				capsule_points[index] = inverse_visual_transform * capsule_points[index]
		canvas.draw_polyline(capsule_points, color, 1.4, true)


static func _poly(
	canvas: CanvasItem,
	points: Array[Vector2],
	fill_color: Color,
	outline_override: Color,
	alpha: float,
	fill_factor: float
) -> void:
	var packed := PackedVector2Array(points)
	if fill_factor > 0.001:
		var colored := fill_color
		colored.a *= alpha * fill_factor
		canvas.draw_colored_polygon(packed, colored)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	var stroke := OUTLINE if outline_override == Color.TRANSPARENT else outline_override
	stroke.a *= alpha
	canvas.draw_polyline(closed, stroke, 1.35, true)


static func _line(canvas: CanvasItem, points: Array[Vector2], color: Color, width: float, alpha: float) -> void:
	var tinted := color
	tinted.a *= alpha
	canvas.draw_polyline(PackedVector2Array(points), tinted, width, true)


static func _circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var tinted := color
	tinted.a *= alpha
	canvas.draw_circle(center, radius, tinted, true, -1.0, true)


static func _cross(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_line(center - Vector2(3, 0), center + Vector2(3, 0), color, 1.0, true)
	canvas.draw_line(center - Vector2(0, 3), center + Vector2(0, 3), color, 1.0, true)


static func _mirror(points: Array[Vector2], side: float) -> Array[Vector2]:
	var mirrored: Array[Vector2] = []
	for point in points:
		mirrored.append(Vector2(point.x * side, point.y))
	return mirrored


static func _offset_points(points: Array[Vector2], offset: Vector2) -> Array[Vector2]:
	var shifted: Array[Vector2] = []
	for point in points:
		shifted.append(point + offset)
	return shifted
