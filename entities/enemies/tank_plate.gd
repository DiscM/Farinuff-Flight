extends Area2D
class_name TankPlate
## One-hit physical armor plate authored as a child of a Tank enemy.

var orbit_angle := 0.0
var orbit_radius := 43.0
var orbit_speed := deg_to_rad(40.0)


func _ready() -> void:
	add_to_group("enemy_armor")


func configure(angle: float, radius: float) -> void:
	orbit_angle = angle
	orbit_radius = radius
	position = Vector2.from_angle(orbit_angle) * orbit_radius


func _physics_process(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	position = Vector2.from_angle(orbit_angle) * orbit_radius
	modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.006 + orbit_angle))


func take_damage(_amount: int) -> void:
	queue_free()

