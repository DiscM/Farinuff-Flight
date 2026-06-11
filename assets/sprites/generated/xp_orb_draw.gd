extends Sprite2D

static var _texture_cache: Dictionary = {}

func generate_texture(base_color: Color, edge_color: Color) -> void:
	var key := "%s|%s" % [base_color.to_html(true), edge_color.to_html(true)]
	if not _texture_cache.has(key):
		var size := 20
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var center := size / 2.0
		for y in range(size):
			for x in range(size):
				var dist := Vector2(float(x) - center, float(y) - center).length()
				# Glowing orb
				if dist < center - 1.0:
					var t := dist / center
					var color := base_color.lerp(edge_color, t)
					img.set_pixel(x, y, color)
				# Bright core
				if dist < 3.0:
					img.set_pixel(x, y, Color(0.9, 1.0, 1.0, 1.0))
		_texture_cache[key] = ImageTexture.create_from_image(img)
	texture = _texture_cache[key]
