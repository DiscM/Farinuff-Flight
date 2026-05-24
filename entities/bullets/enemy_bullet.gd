extends Area2D
## Enemy bullet — moves in a direction (default: straight down). Damages player on contact.

@export var speed: float = 400.0
static var _visibility_ring_texture: Texture2D
var direction: Vector2 = Vector2.DOWN
var _visibility_ring: Sprite2D
var _pulse_time: float = 0.0

func _ready() -> void:
	# Tank radial bullets set direction/speed via metadata before add_child
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("custom_speed"):
		speed = get_meta("custom_speed")

	if has_meta("bullet_color"):
		$Sprite2D.modulate = get_meta("bullet_color")
	else:
		$Sprite2D.modulate = Color(3.0, 0.8, 0.1, 1.0) # Default orange/red

	# Keep hostile shots above bright enemy art and add a color-independent outline.
	z_index = 24
	_create_visibility_ring()

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_pulse_time += delta
	if is_instance_valid(_visibility_ring):
		var pulse := (sin(_pulse_time * 11.0) + 1.0) * 0.5
		_visibility_ring.scale = Vector2.ONE * lerpf(0.98, 1.07, pulse)
		_visibility_ring.modulate.a = lerpf(0.86, 1.0, pulse)


func _create_visibility_ring() -> void:
	if _visibility_ring_texture == null:
		var image_size := 34
		var center := float(image_size) / 2.0
		var image := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(image_size):
			for x in range(image_size):
				var distance := Vector2(float(x) - center + 0.5, float(y) - center + 0.5).length()
				if distance >= 12.0 and distance <= 15.25:
					image.set_pixel(x, y, Color(0.01, 0.025, 0.08, 0.96))
				elif distance >= 9.25 and distance < 12.0:
					image.set_pixel(x, y, Color(1.0, 1.0, 0.96, 0.98))
		_visibility_ring_texture = ImageTexture.create_from_image(image)

	_visibility_ring = Sprite2D.new()
	_visibility_ring.name = "VisibilityRing"
	_visibility_ring.texture = _visibility_ring_texture
	_visibility_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visibility_ring.z_index = -1
	add_child(_visibility_ring)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.get("is_boosting"):
			return
		queue_free()
