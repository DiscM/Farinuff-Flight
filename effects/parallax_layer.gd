extends Node2D
## Procedural parallax star-field layer.
## Draws a tiling field of stars (and optional nebulae) using _draw().
## Parameters are set by the spawner in game.gd before the node enters the tree.

@export var star_count: int = 80
@export var min_size: float = 1.0
@export var max_size: float = 2.5
@export var base_color: Color = Color(0.85, 0.9, 1.0)
@export var show_nebulae: bool = false
@export var nebula_count: int = 3
@export var repeat_size: Vector2 = Vector2(720.0, 1024.0)

# Pre-baked star data so _draw() doesn't re-randomise every frame.
var _stars: Array[Dictionary] = []   # [{pos, size, alpha}]
var _nebulae: Array[Dictionary] = [] # [{pos, radius, color}]

func _ready() -> void:
	_generate()

func _generate() -> void:
	_stars.clear()
	_nebulae.clear()

	for i in range(star_count):
		_stars.append({
			"pos": Vector2(randf() * repeat_size.x, randf() * repeat_size.y),
			"size": randf_range(min_size, max_size),
			"alpha": randf_range(0.55, 1.0),
		})

	if show_nebulae:
		for i in range(nebula_count):
			var col := Color(
				base_color.r * randf_range(0.6, 1.0),
				base_color.g * randf_range(0.3, 0.9),
				base_color.b * randf_range(0.6, 1.0),
				randf_range(0.06, 0.18)
			)
			_nebulae.append({
				"pos": Vector2(randf() * repeat_size.x, randf() * repeat_size.y),
				"radius": randf_range(60.0, 180.0),
				"color": col,
			})

func _draw() -> void:
	# Nebulae first so stars render on top
	for neb in _nebulae:
		draw_circle(neb["pos"], neb["radius"], neb["color"])

	for star in _stars:
		var col := Color(base_color.r, base_color.g, base_color.b, star["alpha"])
		var sz: float = star["size"]
		if sz <= 1.5:
			draw_rect(Rect2(star["pos"], Vector2(sz, sz)), col)
		else:
			draw_circle(star["pos"], sz * 0.5, col)
