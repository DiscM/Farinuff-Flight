extends RefCounted
## Window presentation is independent of the 1280x720 gameplay/UI baseline.
## Full-resolution canvas_items rendering gives larger windows more 3D detail.

const DEFAULT_PRESET := "large"
const PRESET_IDS := ["compact", "medium", "large", "fit"]
const PRESET_LABELS := ["1280 × 720", "1600 × 900", "1920 × 1080", "Fit display"]
const PRESET_SIZES := {
	"compact": Vector2i(1280, 720),
	"medium": Vector2i(1600, 900),
	"large": Vector2i(1920, 1080),
}
const DISPLAY_FRACTION := 0.90

var _applied_preset := ""
var _applied_fullscreen := false
var _windowed_rect := Rect2i()


static func normalize_preset(value: Variant) -> String:
	return value if value is String and value in PRESET_IDS else DEFAULT_PRESET


static func preset_rect(preset: String, usable_rect: Rect2i) -> Rect2i:
	var requested: Vector2i = PRESET_SIZES.get(preset, Vector2i(1920, 1080))
	if preset == "fit":
		requested = Vector2i(usable_rect.size.x, roundi(usable_rect.size.x * 9.0 / 16.0))
	var fitted := fit_size(requested, usable_rect.size)
	return Rect2i(usable_rect.position + Vector2i((Vector2(usable_rect.size) - Vector2(fitted)) * 0.5), fitted)


static func fit_size(requested: Vector2i, usable_size: Vector2i) -> Vector2i:
	var safe_request := Vector2(maxi(requested.x, 2), maxi(requested.y, 2))
	var available := Vector2(maxi(usable_size.x, 2), maxi(usable_size.y, 2)) * DISPLAY_FRACTION
	var factor := minf(1.0, minf(available.x / safe_request.x, available.y / safe_request.y))
	var fitted := safe_request * factor
	return Vector2i(maxi(2, floori(fitted.x)), maxi(2, floori(fitted.y)))


func apply(window: Window, fullscreen: bool, preset_value: Variant) -> void:
	if window == null or DisplayServer.get_name() == "headless":
		return
	var preset := normalize_preset(preset_value)
	var initial := _applied_preset.is_empty()
	var preset_changed := preset != _applied_preset
	var fullscreen_changed := initial or fullscreen != _applied_fullscreen
	# Volume, CRT, and accessibility changes must not resize or unmaximize a
	# window the player has just adjusted with the native window controls.
	if not initial and not preset_changed and not fullscreen_changed:
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		usable = Rect2i(Vector2i.ZERO, DisplayServer.screen_get_size(window.current_screen))
	if fullscreen:
		if fullscreen_changed and not initial:
			_windowed_rect = Rect2i(window.position, window.size)
		if initial or preset_changed:
			_windowed_rect = preset_rect(preset, usable)
		window.mode = Window.MODE_FULLSCREEN
	else:
		var target := preset_rect(preset, usable)
		if not initial and not preset_changed and _applied_fullscreen and _windowed_rect.has_area():
			target = _windowed_rect
			target.size = fit_size(target.size, usable.size)
			target.position.x = clampi(target.position.x, usable.position.x, usable.end.x - target.size.x)
			target.position.y = clampi(target.position.y, usable.position.y, usable.end.y - target.size.y)
		window.mode = Window.MODE_WINDOWED
		window.size = target.size
		window.position = target.position
		_windowed_rect = target
	_applied_preset = preset
	_applied_fullscreen = fullscreen
