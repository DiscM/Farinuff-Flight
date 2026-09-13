extends Node2D
## Independent arena pressure: telegraph, staggered release, then breathing room.
## World-space warning geometry stays aligned while the player camera moves.
const Shot := preload("res://entities/projectiles/projectile_3d.gd")
const PROJECTILE_SPEED := 260.0
const AXIS_SPREAD_SPEED := PROJECTILE_SPEED * 1.25
var boss: Node3D
var space: FlightSpace3D
var manager: ProjectileManager3D
var hazards: NativeHazardManager3D
var pending: Array[Dictionary] = []
var mines: Array[EnemyMine3D] = []
var cooldown := 4.0
var sequence := 0
var enabled := false
var safe_routes: Array[Dictionary] = []

func configure(owner_boss: Node3D, flight_space: FlightSpace3D) -> void:
	boss = owner_boss
	space = flight_space
	manager = get_tree().get_first_node_in_group(&"native_3d_projectile_manager") as ProjectileManager3D
	hazards = get_tree().get_first_node_in_group(&"native_3d_hazard_manager") as NativeHazardManager3D
	enabled = true
	reset_patterns()

func reset_patterns() -> void:
	pending.clear()
	safe_routes.clear()
	cooldown = 4.0
	for mine in mines.duplicate():
		if is_instance_valid(mine) and mine.is_active:
			mine.despawn()
	mines.clear()
	if hazards != null:
		hazards.clear_hazards()

func shutdown() -> void:
	enabled = false
	reset_patterns()
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not enabled or not GameManager.is_game_active or not GameManager.boss_active:
		return
	for index in range(pending.size() - 1, -1, -1):
		var event: Dictionary = pending[index]
		event.time = float(event.time) - delta
		if float(event.time) <= 0.0:
			_release(event)
			pending.remove_at(index)
	for index in range(safe_routes.size() - 1, -1, -1):
		safe_routes[index].time = float(safe_routes[index].time) - delta
		if float(safe_routes[index].time) <= 0.0:
			safe_routes.remove_at(index)
	cooldown -= delta
	if cooldown <= 0.0 and pending.is_empty():
		_plan_pattern()
		sequence += 1
		cooldown = 9.0 - float(boss.get("phase")) * 0.75

func _queue_shot(origin: Vector3, direction: Vector2, delay: float, slot: int, motion: int = Shot.Motion.STRAIGHT) -> void:
	var breaker := slot % 7 == 3
	pending.append({"origin": origin, "direction": direction, "time": delay,
		"motion": Shot.Motion.BOOST_BREAKER if breaker else motion, "trap": false})

func _queue_trap(origin: Vector3, delay: float) -> void:
	pending.append({"origin": origin, "time": delay, "trap": true})

func _plan_pattern() -> void:
	var bounds := space.get_combat_bounds(-45.0)
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	if player == null:
		return
	var variant: int = boss.get("variant")
	var phase: int = boss.get("phase")
	var target := player.global_position
	match variant:
		0:
			# A lateral crosswind overlaps the Commander's aimed lance/ram axis.
			# The open band is fixed at telegraph time, not chasing the player.
			var from_left := sequence % 2 == 0
			var origin_x: float = bounds.position.x if from_left else bounds.end.x
			var step := absf(space.screen_motion_to_combat(Vector2(0.0, 85.0)).z)
			var gap := absf(space.screen_motion_to_combat(Vector2(0.0, 130.0)).z)
			var direction := Vector2.RIGHT if from_left else Vector2.LEFT
			for row in range(int(bounds.size.y / step) + 1):
				var z := bounds.position.y + row * step
				if absf(z - target.z) < gap:
					continue
				for beat in 2:
					_queue_shot(Vector3(origin_x, 0.0, z), direction, 1.8 + beat * 0.8, row + beat)
			_route(Vector3(bounds.position.x, 0.0, target.z), Vector3(bounds.end.x, 0.0, target.z))
			SignalBus.combat_notice.emit("CROSSWIND · FIND THE OPEN BAND; WATCH THE CHARGE")
		1:
			# Alternating gate rows travel from opposite arena edges. Mines deny
			# the flanks, but never occupy the marked passage.
			var gap_x := bounds.get_center().x + bounds.size.x * (0.18 if sequence % 2 == 0 else -0.18)
			var step := absf(space.screen_motion_to_combat(Vector2(95.0, 0.0)).x)
			var gap := absf(space.screen_motion_to_combat(Vector2(150.0, 0.0)).x)
			for row in 2:
				for slot in range(int(bounds.size.x / step) + 1):
					var x := bounds.position.x + slot * step
					if absf(x - gap_x) < gap:
						continue
					_queue_shot(Vector3(x, 0.0, bounds.position.y if row == 0 else bounds.end.y), Vector2.DOWN if row == 0 else Vector2.UP, 2.0 + row * 1.2, slot)
			_route(Vector3(gap_x, 0.0, bounds.position.y), Vector3(gap_x, 0.0, bounds.end.y))
			for side in [-1.0, 1.0]:
				_queue_trap(Vector3(clampf(gap_x + side * gap * 2.0, bounds.position.x, bounds.end.x), 0.0, target.z), 2.0)
			SignalBus.combat_notice.emit("SIEGE CORRIDOR · CROSS THE GATES; AVOID MINED FLANKS")
		2:
			# Two distant storm fronts send staggered diagonal ribbons. Their
			# separation leaves a wide zigzag route between the advancing fronts.
			for front in 2:
				var center := Vector3(bounds.position.x + bounds.size.x * (0.2 if front == 0 else 0.8), 0.0, bounds.position.y if sequence % 2 == 0 else bounds.end.y)
				for beat in 3:
					for slot in 7:
						var angle := (slot - 3) * 0.14 + (0.35 if front == 0 else -0.35)
						var direction := (Vector2.DOWN if sequence % 2 == 0 else Vector2.UP).rotated(angle)
						_queue_shot(center, direction, 1.8 + front * 1.1 + beat * 0.7, slot + beat)
			SignalBus.combat_notice.emit("STORM FRONTS · WEAVE BETWEEN THE TWO RIBBONS")
		3:
			# A closing box pauses before entering the middle; one entire face
			# remains absent. Echo marks independently punish camping in that exit.
			var exit_side := sequence % 4
			for side in 4:
				if side == exit_side:
					continue
				for slot in 13:
					var fraction := float(slot + 1) / 14.0
					var origin := Vector3(lerpf(bounds.position.x, bounds.end.x, fraction), 0.0, bounds.position.y if side == 0 else bounds.end.y)
					var direction := Vector2.DOWN if side == 0 else Vector2.UP
					if side >= 2:
						origin = Vector3(bounds.position.x if side == 2 else bounds.end.x, 0.0, lerpf(bounds.position.y, bounds.end.y, fraction))
						direction = Vector2.RIGHT if side == 2 else Vector2.LEFT
					_queue_shot(origin, direction, 2.1, slot, Shot.Motion.STOP_RELEASE)
			var exits: Array[String] = ["NORTH", "SOUTH", "WEST", "EAST"]
			SignalBus.combat_notice.emit("CLOSING ECHO BOX · %s SIDE OPEN" % exits[exit_side])
		4:
			# Alternating reactor cells ignite in checkerboard order rather than
			# a screen-covering ring. Delayed flowers overlap the interruptible beam.
			for x in 4:
				for z in 3:
					if (x + z + sequence) % 2 != 0:
						continue
					var center := Vector3(bounds.position.x + bounds.size.x * (x + 0.5) / 4.0, 0.0, bounds.position.y + bounds.size.y * (z + 0.5) / 3.0)
					for slot in 6:
						_queue_shot(center, Vector2.from_angle(slot * TAU / 6.0 + sequence * 0.25), 2.2 + z * 0.4, slot, Shot.Motion.BRAKING)
					if x == sequence % 4:
						_queue_trap(center, 2.0)
			SignalBus.combat_notice.emit("REACTOR CELLS · MOVE TO AN UNMARKED CELL")
	# Later phases add a delayed mine at the previous position. Its visible
	# warning allows repositioning; it never materializes as instant damage.
	if phase > 0 and variant in [0, 2, 3]:
		_queue_trap(target, 2.4)

func _route(start: Vector3, end: Vector3) -> void:
	safe_routes.append({"start": start, "end": end, "time": 3.5})

func _release(event: Dictionary) -> void:
	var origin: Vector3 = event.origin
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	# Camera movement can bring a distant emitter onto the craft. Keep a
	# local spawn cushion while still letting existing shots cross the player.
	if player != null and space.combat_motion_to_screen(origin - player.global_position).length() < 110.0:
		return
	if bool(event.trap):
		if hazards != null:
			var mine := hazards.spawn_mine(origin, false, true)
			if mine != null:
				mines.append(mine)
				mine.returned_to_pool.connect(_mine_returned, CONNECT_ONE_SHOT)
	elif manager != null:
		var variant: int = boss.get("variant")
		var colors: Array[Color] = [Color.CORAL, Color.GOLD, Color.MEDIUM_PURPLE, Color.HOT_PINK, Color.IVORY]
		# Crosswind, siege gates, and closing-box volleys cross the arena axes.
		var speed := AXIS_SPREAD_SPEED if variant in [0, 1, 3] else PROJECTILE_SPEED
		manager.fire_enemy_projectile(origin, space.input_to_combat_direction(event.direction), speed, int(event.motion), colors[variant], variant)

func _mine_returned(mine: EnemyMine3D) -> void:
	mines.erase(mine)

func _draw() -> void:
	if not enabled or not is_instance_valid(boss) or not GameManager.boss_active:
		return
	var bounds := space.get_combat_bounds()
	# Sparse world-anchored grid gives lateral flying a visible sense of travel.
	var grid_step := space.screen_motion_to_combat(Vector2(240.0, 240.0))
	for x in range(int(bounds.size.x / grid_step.x) + 1):
		var world_x := bounds.position.x + x * grid_step.x
		draw_line(space.combat_to_screen(Vector3(world_x, 0.0, bounds.position.y)), space.combat_to_screen(Vector3(world_x, 0.0, bounds.end.y)), Color(0.25, 0.65, 0.8, 0.09), 1.0)
	for z in range(int(bounds.size.y / grid_step.z) + 1):
		var world_z := bounds.position.y + z * grid_step.z
		draw_line(space.combat_to_screen(Vector3(bounds.position.x, 0.0, world_z)), space.combat_to_screen(Vector3(bounds.end.x, 0.0, world_z)), Color(0.25, 0.65, 0.8, 0.09), 1.0)
	var corners := PackedVector2Array()
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y), bounds.position]:
		corners.append(space.combat_to_screen(Vector3(point.x, 0.0, point.y)))
	draw_polyline(corners, Color(0.3, 0.8, 1.0, 0.5), 3.0, true)
	for event in pending:
		var origin: Vector3 = event.origin
		var start := space.combat_to_screen(origin)
		if bool(event.trap):
			draw_arc(start, 34.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.15, 0.8), 2.0, true)
			draw_line(start - Vector2(12.0, 0.0), start + Vector2(12.0, 0.0), Color.CORAL, 2.0)
		else:
			var finish := space.combat_to_screen(origin + space.screen_motion_to_combat(Vector2(event.direction) * 3400.0))
			var tint := Color(0.1, 1.0, 1.0, 0.3) if int(event.motion) == Shot.Motion.BOOST_BREAKER else Color(1.0, 0.7, 0.3, 0.18)
			draw_line(start, finish, tint, 1.0, true)
	for route in safe_routes:
		draw_line(space.combat_to_screen(route.start), space.combat_to_screen(route.end), Color(0.3, 1.0, 0.6, 0.3), 4.0, true)
	_draw_navigation(bounds)

func _draw_navigation(bounds: Rect2) -> void:
	var viewport := get_viewport_rect()
	var boss_screen := space.combat_to_screen(boss.global_position)
	var safe := viewport.grow(-65.0)
	if not safe.has_point(boss_screen):
		var center := viewport.get_center()
		var direction := (boss_screen - center).normalized()
		var distance := minf((safe.size.x * 0.5) / maxf(absf(direction.x), 0.001), (safe.size.y * 0.5) / maxf(absf(direction.y), 0.001))
		var tip := center + direction * distance
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 20.0 + direction.orthogonal() * 9.0, tip - direction * 20.0 - direction.orthogonal() * 9.0]), Color.CORAL)
		draw_string(ThemeDB.fallback_font, tip + Vector2(-20.0, -16.0), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CORAL)
	var map := Rect2(Vector2(viewport.end.x - 180.0, viewport.end.y - 130.0), Vector2(150.0, 90.0))
	draw_rect(map, Color(0.02, 0.04, 0.08, 0.8))
	draw_rect(map, Color(0.3, 0.8, 1.0, 0.5), false)
	var visible_start := space.screen_to_combat_plane(viewport.position)
	var visible_end := space.screen_to_combat_plane(viewport.end)
	var map_start := (Vector2(visible_start.x, visible_start.z) - bounds.position) / bounds.size
	var map_end := (Vector2(visible_end.x, visible_end.z) - bounds.position) / bounds.size
	draw_rect(Rect2(map.position + map_start * map.size, (map_end - map_start) * map.size), Color(0.3, 0.8, 1.0, 0.3), false)
	var player := get_tree().get_first_node_in_group(&"player_craft") as Node3D
	for actor in [player, boss]:
		if actor != null:
			var normalized := (Vector2(actor.global_position.x, actor.global_position.z) - bounds.position) / bounds.size
			draw_circle(map.position + normalized * map.size, 4.0, Color.CORAL if actor == boss else Color.AQUAMARINE)
