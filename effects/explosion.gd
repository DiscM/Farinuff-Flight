extends Node2D
## Explosion effect — particle burst then self-destruct.

## Creates a one-shot CPU particle system with an orange-to-dark gradient,
## adds a brief white flash sprite that shrinks and fades, and schedules
## automatic cleanup after 0.7 seconds.
func _ready() -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 0.95
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 40)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color_ramp = _create_gradient()
	particles.color = Color(1.0, 0.6, 0.1)

	# Also add a brief flash
	var flash := Sprite2D.new()
	add_child(flash)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.9, 0.5, 0.8))
	flash.texture = ImageTexture.create_from_image(img)
	flash.scale = Vector2(3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)

	# Self destruct
	get_tree().create_timer(0.7).timeout.connect(queue_free)

## Creates a 3-stop color gradient for the explosion particles:
## bright yellow → orange → transparent dark, simulating a fireball decay.
func _create_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3),
		Color(1.0, 0.4, 0.1),
		Color(0.4, 0.1, 0.05, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	return gradient
