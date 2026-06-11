extends Sprite2D

static var _enemy_bullet_texture: Texture2D

func _ready() -> void:
	if _enemy_bullet_texture == null:
		var size := 24
		var img := Image.create(size, size, false, Image.FORMAT_RGBAF)
		img.fill(Color.TRANSPARENT)

		var center := float(size) / 2.0
		var radius := center
		for x in range(size):
			for y in range(size):
				var cx := float(x) - center + 0.5
				var cy := float(y) - center + 0.5
				var dist := sqrt(cx * cx + cy * cy)
				if dist <= radius:
					var t := dist / radius
					var c := Color(1.0, 1.0, 1.0, 1.0)
					if t < 0.35:
						c = Color(2.0, 2.0, 2.0, 1.0)
					else:
						c.a = lerp(1.0, 0.0, (t - 0.35) / 0.65)
					img.set_pixel(x, y, c)
		_enemy_bullet_texture = ImageTexture.create_from_image(img)
	texture = _enemy_bullet_texture
