extends Sprite2D

## Runtime-painted XP orb texture, restyled to the PixelPlanets recipe: the
## base->edge gradient is posterized into discrete radial bands, the band
## boundaries dither on a 2px checkerboard, and the rim carries the shared
## dark void outline.

const VOID_RIM := Color(0.016, 0.020, 0.043)
const CORE_COLOR := Color(0.96, 1.0, 1.0)
const BAND_COUNT := 3

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
				if dist >= center - 1.0:
					continue
				# White-hot core, like the lit face of a Star shader planet.
				if dist < 3.0:
					img.set_pixel(x, y, CORE_COLOR)
					continue
				# Dark void rim, one pixel thick.
				if dist >= center - 2.5:
					img.set_pixel(x, y, VOID_RIM)
					continue
				var t := dist / center
				# Posterize the radial gradient into bands; checker pixels
				# nudge the boundary so transitions dither.
				var nudge := 0.45 if (x + y) % 2 == 0 else 0.0
				var band := clampi(
					int(t * BAND_COUNT + nudge),
					0,
					BAND_COUNT
				)
				var color := base_color.lerp(edge_color, float(band) / float(BAND_COUNT))
				img.set_pixel(x, y, color)
		_texture_cache[key] = ImageTexture.create_from_image(img)
	texture = _texture_cache[key]
	# The texture is painted pixel-perfect; never blur it during pop tweens.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
