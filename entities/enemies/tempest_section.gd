extends Area2D
class_name TempestSection

signal destroyed(section: TempestSection)

var health: int = 1
var max_health: int = 1
var section_color: Color = Color(0.2, 0.9, 1.0)
var section_size: Vector2 = Vector2(26.0, 42.0)
var disabled: bool = false


## Initializes the section with a display name, hit points, collision size,
## and color. Sets up collision layers (enemy layer 2, detects player bullets
## layer 4), adds to the "tempest_sections" group, creates a rectangle
## collision shape, and triggers a draw pass for the visual hull.
func setup(display_name: String, hp: int, size: Vector2, color: Color) -> void:
	name = display_name.replace(" ", "")
	health = hp
	max_health = hp
	section_size = size
	section_color = color
	collision_layer = 2
	collision_mask = 4
	add_to_group("tempest_sections")

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


## Reduces the section's health. If health reaches 0, marks as disabled,
## emits the destroyed signal, and frees the node. Otherwise, plays a
## white flash tween and redraws the hull (color darkens as health drops).
func take_damage(amount: int) -> void:
	if disabled:
		return
	health -= amount
	if health <= 0:
		disabled = true
		destroyed.emit(self)
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	queue_redraw()


## Draws the section's hexagonal hull shape. The fill color darkens as health
## decreases, the outline uses the section's assigned color, and a glowing
## center dot indicates the section is active.
func _draw() -> void:
	var half := section_size * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, -half.y),
		Vector2(half.x, -half.y * 0.45),
		Vector2(half.x * 0.82, half.y * 0.62),
		Vector2(0.0, half.y),
		Vector2(-half.x * 0.82, half.y * 0.62),
		Vector2(-half.x, -half.y * 0.45),
	])
	var health_ratio := maxf(float(health) / float(max_health), 0.0)
	draw_colored_polygon(points, section_color.darkened(0.25 + (1.0 - health_ratio) * 0.25))
	draw_polyline(points + PackedVector2Array([points[0]]), section_color, 2.0, true)
	draw_circle(Vector2.ZERO, 5.0, section_color.lightened(0.35))
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
