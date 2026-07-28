extends Sprite2D

static var _bullet_texture: Texture2D

func _ready() -> void:
	if _bullet_texture == null:
		var image_size := 32
		var img := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		# Small fallback diamond; the shader uses the padded texture bounds for
		# its halo, trailing energy, and upgrade indicators.
		for x in range(image_size):
			for y in range(image_size):
				var cx := float(x) - 15.5
				var cy := float(y) - 15.5
				if absf(cx) * 1.6 + absf(cy) <= 7.5:
					img.set_pixel(x, y, Color(0.2, 1.0, 0.85))
		_bullet_texture = ImageTexture.create_from_image(img)
	texture = _bullet_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
