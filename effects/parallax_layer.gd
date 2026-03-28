extends Node2D
## Procedural parallax star/nebula renderer for a single depth layer.
## Attach as a child of a Parallax2D node.

@export var star_count: int = 80
@export var min_size: float = 1.0
@export var max_size: float = 2.5
@export var base_color: Color = Color(0.75, 0.85, 1.0)
@export var min_brightness: float = 0.3
@export var max_brightness: float = 1.0
@export var show_nebulae: bool = false
@export var nebula_count: int = 6

var _stars: Array[Dictionary] = []
var _nebulae: Array[Dictionary] = []
var _viewport_size: Vector2

func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_generate()

func _generate() -> void:
	_stars.clear()
	_nebulae.clear()

	# Scatter stars across a tall area (2x viewport height) so scrolling looks seamless
	var area_height := _viewport_size.y * 2.0
	for i in range(star_count):
		_stars.append({
			"pos": Vector2(randf() * _viewport_size.x, randf() * area_height),
			"size": randf_range(min_size, max_size),
			"brightness": randf_range(min_brightness, max_brightness),
			"twinkle_speed": randf_range(0.8, 3.5),
			"twinkle_offset": randf() * TAU,
		})

	if show_nebulae:
		for i in range(nebula_count):
			_nebulae.append({
				"pos": Vector2(randf() * _viewport_size.x, randf() * area_height),
				"radius": randf_range(40.0, 100.0),
				"color": Color(
					base_color.r * randf_range(0.6, 1.0),
					base_color.g * randf_range(0.4, 0.8),
					base_color.b * randf_range(0.8, 1.0),
					randf_range(0.03, 0.10)),
			})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0

	# Draw nebula clouds first (behind stars)
	for n in _nebulae:
		# Draw a soft radial glow using concentric circles
		var steps := 6
		for s in range(steps, 0, -1):
			var frac: float = float(s) / float(steps)
			var r: float = n["radius"] * frac
			var c: Color = n["color"]
			c.a = n["color"].a * (1.0 - frac) * 2.5
			draw_circle(n["pos"], r, c)

	# Draw stars
	for star in _stars:
		var twinkle := (sin(t * star["twinkle_speed"] + star["twinkle_offset"]) + 1.0) * 0.5
		var alpha: float = star["brightness"] * lerpf(0.35, 1.0, twinkle)
		var col := Color(base_color.r, base_color.g, base_color.b, alpha)
		var pos: Vector2 = star["pos"]
		var sz: float = star["size"]
		draw_rect(Rect2(pos.x - sz * 0.5, pos.y - sz * 0.5, sz, sz), col)
