extends Control
## Animated arcade-poster backdrop for the main menu.

const CYAN := Color(0.14, 0.91, 1.0)
const MAGENTA := Color(1.0, 0.18, 0.63)
const VIOLET := Color(0.39, 0.16, 0.78)


class Star:
	var position: Vector2
	var radius: float
	var alpha: float
	var speed: float
	var accent: bool

	func _init(
		initial_position: Vector2,
		initial_radius: float,
		initial_alpha: float,
		initial_speed: float,
		is_accent: bool
	) -> void:
		position = initial_position
		radius = initial_radius
		alpha = initial_alpha
		speed = initial_speed
		accent = is_accent


var _stars: Array[Star] = []
var _drift := 0.0
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_stars)
	_rebuild_stars()
	set_process(true)


func _process(delta: float) -> void:
	_drift += delta * 5.0
	_pulse += delta
	queue_redraw()


func _rebuild_stars() -> void:
	_stars.clear()
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 0xFA71C4
	for index in range(150):
		_stars.append(Star.new(
			Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y)),
			rng.randf_range(0.45, 1.8),
			rng.randf_range(0.35, 0.95),
			rng.randf_range(0.25, 1.0),
			index % 17 == 0
		))
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	_draw_halftone_cloud(Vector2(size.x * 0.10, size.y * 0.58), 8, VIOLET)
	_draw_halftone_cloud(Vector2(size.x * 0.77, size.y * 0.15), 10, VIOLET.lightened(0.1))

	for star in _stars:
		var star_position := star.position
		star_position.y = fposmod(star_position.y + _drift * star.speed, size.y)
		var color := CYAN if star.accent else Color(0.82, 0.92, 1.0)
		color.a = star.alpha
		if star.radius > 1.35:
			draw_line(star_position - Vector2(star.radius * 2.0, 0.0), star_position + Vector2(star.radius * 2.0, 0.0), color, 1.0)
			draw_line(star_position - Vector2(0.0, star.radius * 2.0), star_position + Vector2(0.0, star.radius * 2.0), color, 1.0)
		else:
			draw_rect(Rect2(star_position, Vector2.ONE * maxf(star.radius, 1.0)), color)

	var beam_start := Vector2(size.x * 0.43, size.y * 0.76)
	var beam_end := Vector2(size.x * 0.96, -12.0)
	draw_line(beam_start + Vector2(6.0, 8.0), beam_end + Vector2(6.0, 8.0), Color(MAGENTA, 0.24), 2.0)
	draw_line(beam_start, beam_end, Color(CYAN, 0.88), 2.0)

	var glint_alpha := 0.45 + sin(_pulse * 2.1) * 0.20
	var glint := Vector2(size.x * 0.89, size.y * 0.09)
	draw_line(glint - Vector2(11.0, 0.0), glint + Vector2(11.0, 0.0), Color(0.9, 1.0, 1.0, glint_alpha), 1.0)
	draw_line(glint - Vector2(0.0, 11.0), glint + Vector2(0.0, 11.0), Color(0.9, 1.0, 1.0, glint_alpha), 1.0)


func _draw_halftone_cloud(center: Vector2, radius_in_dots: int, color: Color) -> void:
	var spacing := 8.0
	for y in range(-radius_in_dots, radius_in_dots + 1):
		for x in range(-radius_in_dots, radius_in_dots + 1):
			var distance := Vector2(float(x), float(y)).length()
			if distance > float(radius_in_dots):
				continue
			var alpha := (1.0 - distance / float(radius_in_dots)) * 0.18
			var dot_color := color
			dot_color.a = alpha
			draw_circle(center + Vector2(x, y) * spacing, 1.2, dot_color)
