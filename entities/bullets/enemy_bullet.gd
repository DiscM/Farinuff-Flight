extends Area2D
## Enemy bullet — moves in a direction (default: straight down). Damages player on contact.

@export var speed: float = 400.0
var direction: Vector2 = Vector2.DOWN

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

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.get("is_boosting"):
			return
		queue_free()
