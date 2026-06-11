extends Sprite2D

static var _powerup_texture: Texture2D

func _ready() -> void:
	if _powerup_texture == null:
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var center := size / 2.0
		for y in range(size):
			for x in range(size):
				var dist := Vector2(float(x) - center, float(y) - center).length()
				# Outer ring
				if dist < center - 1.0 and dist > center - 4.0:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.9))
				# Inner fill
				elif dist < center - 4.0:
					var t := dist / (center - 4.0)
					var color := Color(1.0, 1.0, 1.0, 0.8).lerp(Color(0.8, 0.8, 0.8, 0.5), t)
					img.set_pixel(x, y, color)
		_powerup_texture = ImageTexture.create_from_image(img)
	texture = _powerup_texture
