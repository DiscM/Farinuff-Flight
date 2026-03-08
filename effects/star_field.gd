extends Node2D
## Procedural scrolling star-field background with parallax layers.

var stars: Array[Dictionary] = []
var viewport_size: Vector2 = Vector2(720, 1024)
const NUM_STARS: int = 120

func _ready() -> void:
	viewport_size = get_viewport_rect().size
	# Create stars at random positions with varying sizes and speeds
	for i in range(NUM_STARS):
		var star := {
			"pos": Vector2(randf() * viewport_size.x, randf() * viewport_size.y),
			"speed": randf_range(15.0, 100.0),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0),
			"twinkle_speed": randf_range(1.0, 4.0),
			"twinkle_offset": randf() * TAU,
		}
		stars.append(star)

func _process(delta: float) -> void:
	for star in stars:
		star["pos"].y += star["speed"] * delta
		if star["pos"].y > viewport_size.y + 5:
			star["pos"].y = -5.0
			star["pos"].x = randf() * viewport_size.x
	queue_redraw()

func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for star in stars:
		var twinkle := (sin(time * star["twinkle_speed"] + star["twinkle_offset"]) + 1.0) * 0.5
		var alpha: float = star["brightness"] * lerpf(0.4, 1.0, twinkle)
		var color := Color(0.7, 0.8, 1.0, alpha)
		var pos: Vector2 = star["pos"]
		var sz: float = star["size"]
		draw_rect(Rect2(pos.x - sz * 0.5, pos.y - sz * 0.5, sz, sz), color)
