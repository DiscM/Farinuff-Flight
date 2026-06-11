extends Area2D
## Enemy bullet — moves in a direction (default: straight down). Damages player on contact.

@export var speed: float = 400.0
static var _visibility_ring_texture: Texture2D
const PLAYER_PROJECTILE_COLOR := Color(0.2, 1.0, 0.6, 1.0)
var direction: Vector2 = Vector2.DOWN
var _visibility_ring: Sprite2D
var _pulse_time: float = 0.0
var is_deflected: bool = false
@onready var sprite: Sprite2D = $Sprite2D

## Initializes the bullet: reads direction, speed, and color overrides from
## metadata (set by spawning enemies), configures high z_index for visibility,
## creates a pulsing visibility ring outline, and sets up screen-exit cleanup.
func _ready() -> void:
	# Tank radial bullets set direction/speed via metadata before add_child
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("custom_speed"):
		speed = get_meta("custom_speed")

	if has_meta("bullet_color"):
		sprite.modulate = get_meta("bullet_color")
	else:
		sprite.modulate = Color(3.0, 0.8, 0.1, 1.0) # Default orange/red

	# Keep hostile shots above bright enemy art and add a color-independent outline.
	z_index = 24
	_create_visibility_ring()

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)

## Moves the bullet along its direction and animates a subtle pulse on the
## visibility ring for readability against busy backgrounds.
func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_pulse_time += delta
	if is_instance_valid(_visibility_ring):
		var pulse := (sin(_pulse_time * 11.0) + 1.0) * 0.5
		var base_scale := 1.18 if is_deflected else 1.0
		_visibility_ring.scale = Vector2.ONE * base_scale * lerpf(0.98, 1.07, pulse)
		_visibility_ring.modulate.a = lerpf(0.86, 1.0, pulse)


## Deflects the bullet when hit by a boosting player. Reverses its direction
## (biased toward the deflector's velocity), increases speed, changes collision
## layers so it damages enemies instead of the player, and recolors it green
## to indicate it's now friendly. Returns true on success, false if already
## deflected.
func deflect(deflector_position: Vector2, deflector_velocity: Vector2) -> bool:
	if is_deflected:
		return false
	is_deflected = true
	var reflected_direction := (global_position - deflector_position).normalized()
	if reflected_direction.is_zero_approx():
		reflected_direction = -direction
	if not deflector_velocity.is_zero_approx():
		reflected_direction = reflected_direction.lerp(deflector_velocity.normalized(), 0.32).normalized()
	direction = reflected_direction
	speed = maxf(speed * 1.35, 560.0)
	remove_from_group("enemy_bullets")
	# Detect enemies from this script only, avoiding duplicate player-bullet damage.
	collision_layer = 0
	collision_mask = 2
	sprite.modulate = PLAYER_PROJECTILE_COLOR
	if is_instance_valid(_visibility_ring):
		_visibility_ring.modulate = PLAYER_PROJECTILE_COLOR
		_visibility_ring.scale = Vector2.ONE * 1.18
	return true


## Creates a static visibility ring texture (shared across all instances for
## performance) consisting of a dark outline ring and a bright inner ring.
## Attaches it as a child Sprite2D drawn behind the bullet sprite.
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


## Handles collision: if deflected, damages enemies on contact and self-destructs.
## If not deflected and touching the player, checks whether the player can
## deflect (is boosting), attempts deflection, and self-destructs if the player
## can't deflect.
func _on_area_entered(area: Area2D) -> void:
	if is_deflected:
		if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
			area.take_damage(1 + GameManager.bonus_damage)
			queue_free()
		return
	if area.is_in_group("player"):
		var can_be_deflected := bool(area.get("is_boosting"))
		if area.has_method("can_deflect_projectiles"):
			can_be_deflected = area.can_deflect_projectiles()
		if can_be_deflected:
			if deflect(area.global_position, area.velocity) and area.has_method("register_boost_reflection"):
				area.register_boost_reflection()
			return
		queue_free()
