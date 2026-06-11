extends Sprite2D

static var _bullet_texture: Texture2D

func _ready() -> void:
	if _bullet_texture == null:
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 1.0, 0.6))
		# Make it a diamond/bullet shape
		for x in range(12):
			for y in range(12):
				var cx := x - 5.5
				var cy := y - 5.5
				if absf(cx) + absf(cy) > 5.5:
					img.set_pixel(x, y, Color.TRANSPARENT)
		_bullet_texture = ImageTexture.create_from_image(img)
	texture = _bullet_texture
