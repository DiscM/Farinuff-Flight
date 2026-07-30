extends BaseEnemy
## Fast enemy — quick & agile, slight sine wave movement.

var time_alive: float = 0.0
var wave_amplitude: float = 80.0
var wave_frequency: float = 3.0
var start_pos: Vector2 = Vector2.ZERO
var pattern_timer := 0.0
var sidestep_cooldown := 0.0
## Throttles the bullet-proximity scan so it runs ~8x/sec instead of every
## physics frame (0.12s is imperceptible for a dodge reaction).
var sidestep_scan_timer := 0.0
var phase_timer := 0.0
var phase_state := 0
var phase_direction := Vector2.ZERO

## Initializes the fast enemy: records the spawn position for sine-wave
## offset calculations and staggers the pattern timer. Health, speed, and
## points come from the evolution-stage data in the scene, not this script.
func _ready() -> void:
	archetype_id = &"fast"
	super._ready()
	start_pos = position
	pattern_timer = randf_range(1.4, 2.2)
	phase_timer = 1.5

## Moves the enemy along its spawn direction at high speed while oscillating
## perpendicular to that direction in a sine wave pattern, creating a weaving
## flight path that makes it harder to hit.
func _move(delta: float) -> void:
	time_alive += delta
	pattern_timer -= delta
	sidestep_cooldown = maxf(0.0, sidestep_cooldown - delta)
	if generation >= 2 and pattern_timer <= 0.0:
		pattern_timer = randf_range(1.4, 2.2)
		wave_amplitude = randf_range(48.0, 104.0)
		wave_frequency = randf_range(2.4, 4.6)
		var flare := make_ring_warning(13.0, Color(1.0, 0.62, 0.12, 0.85), 2.0)
		var tween := create_tween()
		tween.tween_property(flare, "scale", Vector2.ONE * 2.2, 0.18)
		tween.parallel().tween_property(flare, "modulate:a", 0.0, 0.18)
		tween.tween_callback(flare.queue_free)

	if generation >= 3 and sidestep_cooldown <= 0.0:
		sidestep_scan_timer -= delta
		if sidestep_scan_timer <= 0.0:
			sidestep_scan_timer = 0.12
			_try_reactive_sidestep()

	if generation >= 4 and phase_state == 0:
		phase_timer -= delta
		if phase_timer <= 0.0 and can_begin_special():
			phase_state = 1
			phase_timer = 0.4
			phase_direction = Vector2(-spawn_direction.y, spawn_direction.x) * [-1.0, 1.0].pick_random()
			make_line_warning(phase_direction, 100.0, Color(1.0, 0.08, 0.78, 0.9), 4.0)
	elif phase_state == 1:
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase_state = 2
			_spawn_afterimages()
			start_pos += phase_direction * 100.0
			for child in get_children():
				if child.name == "AttackWarning":
					child.queue_free()
	# Advance along travel direction
	position += spawn_direction * speed * delta
	# Oscillate perpendicular to travel direction (sine wave stays centred on the entry path)
	var perp := Vector2(-spawn_direction.y, spawn_direction.x)
	var along := spawn_direction.dot(position - start_pos)
	var base_pos := start_pos + spawn_direction * along
	position = base_pos + perp * sin(time_alive * wave_frequency) * wave_amplitude


func _try_reactive_sidestep() -> void:
	for projectile in get_tree().get_nodes_in_group("player_bullets"):
		if not is_instance_valid(projectile):
			continue
		var offset: Vector2 = global_position - projectile.global_position
		if offset.length_squared() > 95.0 * 95.0:
			continue
		var projectile_direction: Vector2 = projectile.get("direction")
		if projectile_direction.dot(offset.normalized()) > 0.78:
			var side := Vector2(-projectile_direction.y, projectile_direction.x)
			start_pos += side * 44.0 * [-1.0, 1.0].pick_random()
			sidestep_cooldown = 2.5
			return


func _spawn_afterimages() -> void:
	var ship_renderer := get_tree().get_first_node_in_group(&"ship_render_layer_3d")
	if (
		ship_renderer != null
		and ship_renderer.has_method(&"get_visual_for")
		and ship_renderer.call(&"get_visual_for", self) != null
	):
		# Keep the Apex phase effect fully 3D; the proxy's animated shader and
		# engine trails replace the legacy Sprite2D ghosts.
		return
	for i in range(3):
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.hframes = 4
		ghost.frame = sprite.frame
		ghost.global_position = global_position - phase_direction * float(i) * 18.0
		ghost.global_rotation = global_rotation
		ghost.modulate = Color(0.9, 0.08, 0.85, 0.42)
		get_tree().current_scene.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.28)
		tween.tween_callback(ghost.queue_free)


func dev_trigger_ability() -> void:
	phase_state = 0
	phase_timer = 0.0
	sidestep_cooldown = 0.0
	visible_time = 1.0
