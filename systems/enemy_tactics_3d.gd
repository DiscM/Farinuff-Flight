extends RefCounted
class_name EnemyTactics3D
## Perception, maneuver selection and committed path geometry.
## The owning enemy FSM alone advances warnings, flight and motion.
const Flight := preload("res://effects/enemy_flight_motion_3d.gd")
const Tell := preload("res://effects/enemy_maneuver_tell_3d.gd")
enum Action { NONE, SPLIT_S, IMMELMANN, SCISSORS, CORKSCREW, KNIFE_EDGE,
	HIGH_YO_YO, LOW_YO_YO, HAMMERHEAD, BOMBING_RUN }
const OBSERVATION_SECONDS := 0.22
const MAX_NEIGHBORS := 32
const MAX_SHOTS := 64
const FOLLOWUP_SECONDS := 0.9
const LABELS := ["", "BREAK AWAY", "PURSUIT TURN", "SCISSORS", "FLANK RUN", "CLEARING LANE",
	"CLIMBING TURN", "DIVING PURSUIT", "STALL TURN", "BOMBING RUN"]

var pressure := 0.0
var threat_count := 0
var approaching_fire := false
var separation := Vector2.ZERO
var line_blocked := false
var has_support := false
var support_position := Vector3.ZERO
var last_action: Action = Action.NONE
var last_reason := "cruise"
var role := 0 # 0 = pressure, 1 = flanker, 2 = cautious
var _observe_in := 0.0
var _decision_ready := false
var _cooldown := 0.0
var _repeat_lock := 0.0
var _action: Action = Action.NONE
var _flight_state := 0
var _duration := 1.0
var _warning := 0.0
var _direction := 1.0
var _points := PackedVector3Array()
var _entry_velocity := Vector3.ZERO
var _exit_velocity := Vector3.ZERO
var _cross_velocity := Vector3.ZERO
var _allies := PackedVector3Array()
var _shot_positions := PackedVector2Array()
var _shot_velocities := PackedVector2Array()
var _threat_direction := Vector2.UP
var _tell: Node3D
var _locked_target := Vector3.ZERO
var _followup: Action = Action.NONE
var _followup_left := 0.0
var _chain_depth := 0


func reset(seed_value: int) -> void:
	role = posmod(seed_value, 3)
	_observe_in = float(posmod(seed_value, 11)) * 0.02
	_decision_ready = false
	_cooldown = 0.8 + float(role) * 0.15
	_repeat_lock = 0.0
	pressure = 0.0
	threat_count = 0
	approaching_fire = false
	separation = Vector2.ZERO
	line_blocked = false
	has_support = false
	last_action = Action.NONE
	last_reason = "cruise"
	_allies.clear()
	_shot_positions.clear()
	_shot_velocities.clear()
	cancel()


func record_damage(fraction: float) -> void:
	pressure = minf(pressure + fraction * 5.0, 3.0)


func tick(actor: Node3D, delta: float) -> void:
	# Only perception and decision memory advance here, never combat states.
	_cooldown = maxf(0.0, _cooldown - delta)
	_repeat_lock = maxf(0.0, _repeat_lock - delta)
	pressure = maxf(0.0, pressure - delta * 0.55)
	_followup_left = maxf(0.0, _followup_left - delta)
	if _followup_left <= 0.0 or actor.state != actor._maneuver_entry_state():
		discard_followup()
	_observe_in -= delta
	if _observe_in <= 0.0:
		_observe_in = OBSERVATION_SECONDS
		observe(actor)


func has_plan() -> bool:
	return _action != Action.NONE and not _points.is_empty()


func update_warning(actor: Node3D) -> void:
	_points[0] = actor.global_position
	_entry_velocity = actor.velocity
	_present_tell(actor)


func hide_warning() -> void:
	if is_instance_valid(_tell):
		_tell.hide()


func advance_path(actor: Node3D, progress: float, delta: float) -> void:
	var next: Vector3 = actor._clamp_maneuver_point(sample_path(progress))
	actor.velocity = (next - actor.global_position) / maxf(delta, 0.0001)
	actor.global_position = next
	if progress >= 1.0:
		actor.velocity = _exit_velocity
	if actor.velocity.length_squared() > 0.01:
		var heading: Vector3 = actor.velocity.normalized()
		actor._heading = heading
		actor._update_facing(heading, delta)
	if progress >= 1.0:
		actor._strafe_sign = -actor._strafe_sign
		if is_instance_valid(actor._observed_player):
			var offset: Vector2 = actor._flight_space.combat_motion_to_screen(next - actor._observed_player.global_position)
			actor._strafe_angle = offset.angle()
			actor._strafe_radius = clampf(offset.length(), 140.0, 420.0)


func complete(actor: Node3D) -> void:
	var completed := _action
	var may_chain: bool = actor._supports_maneuver(Action.LOW_YO_YO) and _chain_depth == 0
	cancel()
	if may_chain:
		if completed == Action.CORKSCREW:
			_followup = Action.HIGH_YO_YO
		elif completed == Action.HIGH_YO_YO:
			_followup = Action.LOW_YO_YO
		_followup_left = FOLLOWUP_SECONDS if _followup != Action.NONE else 0.0


func discard_followup() -> void:
	_followup = Action.NONE
	_followup_left = 0.0


func observe(actor: Node3D) -> void:
	_decision_ready = true
	threat_count = 0
	approaching_fire = false
	_shot_positions.clear()
	_shot_velocities.clear()
	_allies.clear()
	separation = Vector2.ZERO
	line_blocked = false
	has_support = false
	if actor.generation < 2 or not is_instance_valid(actor._observed_player):
		return
	var space = actor._flight_space
	var player_offset: Vector2 = space.combat_motion_to_screen(actor._observed_player.global_position - actor.global_position)
	var shots: Array[Node] = actor.get_tree().get_nodes_in_group(&"player_projectiles")
	var first := posmod(actor.get_instance_id(), maxi(1, shots.size()))
	for index in mini(shots.size(), MAX_SHOTS):
		var shot = shots[(first + index) % shots.size()]
		if not shot.is_active:
			continue
		var relative: Vector2 = space.combat_motion_to_screen(shot.global_position - actor.global_position)
		if relative.length_squared() > 650.0 * 650.0:
			continue
		var speed: Vector2 = space.combat_motion_to_screen(shot.velocity)
		_shot_positions.append(relative)
		_shot_velocities.append(speed)
		if relative.length() <= actor.REFLECT_ALERT_PIXELS and threatens(actor, shot, 1.5):
			approaching_fire = true
		if threatens(actor, shot, 0.85):
			threat_count += 1
			_threat_direction = speed.normalized()
	pressure = maxf(pressure, minf(float(threat_count) * 0.6, 3.0))
	var neighbors: Array[Node] = actor.get_tree().get_nodes_in_group(&"native_3d_enemies")
	first = posmod(actor.get_instance_id(), maxi(1, neighbors.size()))
	var closest_support := 320.0
	for index in mini(neighbors.size(), MAX_NEIGHBORS):
		var ally = neighbors[(first + index) % neighbors.size()]
		if ally == actor or not ally.is_active or ally.is_queued_for_deletion():
			continue
		var offset: Vector2 = space.combat_motion_to_screen(ally.global_position - actor.global_position)
		var distance := offset.length()
		if distance > 400.0:
			continue
		_allies.append(ally.global_position)
		if distance < 155.0:
			var away := -offset.normalized() if distance > 1.0 else Vector2.RIGHT * (-1.0 if actor.get_instance_id() < ally.get_instance_id() else 1.0)
			separation += away * (155.0 - distance)
		var along := offset.dot(player_offset.normalized())
		var across := absf(offset.cross(player_offset.normalized()))
		if along > 20.0 and along < player_offset.length() - 25.0 and across < 65.0:
			line_blocked = true
		if actor.flight_style == Flight.Style.TANK and ally._health_fraction() < 0.45 and distance < closest_support:
			closest_support = distance
			has_support = true
			var toward_player: Vector3 = actor._observed_player.global_position - ally.global_position
			support_position = ally.global_position + space.screen_motion_to_combat(space.combat_motion_to_screen(toward_player).normalized() * 95.0)
	separation = separation.limit_length(140.0)


static func threatens(actor: Node3D, shot: Node3D, horizon: float) -> bool:
	var space = actor._flight_space
	var offset: Vector2 = space.combat_motion_to_screen(shot.global_position - actor.global_position)
	var relative_velocity: Vector2 = space.combat_motion_to_screen(shot.velocity - actor.velocity)
	var speed_squared := relative_velocity.length_squared()
	if speed_squared < 1.0 or offset.dot(relative_velocity) >= 0.0:
		return false
	var intercept := -offset.dot(relative_velocity) / speed_squared
	if intercept > horizon:
		return false
	var side := Vector2(-relative_velocity.y, relative_velocity.x).normalized()
	var radius: float = actor._dodge_clearance_pixels(side)
	return (offset + relative_velocity * intercept).length() <= radius


func adjust_target(actor: Node3D, target: Vector3) -> Vector3:
	if actor.generation < 2:
		return target
	if has_support and actor.flight_style == Flight.Style.TANK:
		target = target.lerp(support_position, 0.65)
	return target + actor._flight_space.screen_motion_to_combat(separation)


func lane_cost(actor: Node3D, point: Vector3) -> float:
	var space = actor._flight_space
	var cost := 0.0
	for ally in _allies:
		var distance: float = space.combat_motion_to_screen(point - ally).length()
		cost += maxf(0.0, 145.0 - distance) * 2.0
	var offset: Vector2 = space.combat_motion_to_screen(point - actor.global_position)
	for index in _shot_positions.size():
		var nearest := Geometry2D.get_closest_point_to_segment(offset, _shot_positions[index], _shot_positions[index] + _shot_velocities[index] * 0.6)
		cost += maxf(0.0, 80.0 - nearest.distance_to(offset))
	# Read committed routes live. A second craft chooses the other flank even
	# when it made its perception snapshot before the first craft committed.
	var checked := 0
	for ally in actor.get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if ally == actor or not ally.is_active or ally.is_queued_for_deletion():
			continue
		if space.combat_motion_to_screen(ally.global_position - actor.global_position).length() > 650.0:
			continue
		checked += 1
		var brain = ally._tactics
		if ally.is_maneuver_committed() and _is_offensive(brain._action):
			var distance: float = space.combat_motion_to_screen(point - brain.sample_path(1.0)).length()
			cost += maxf(0.0, 280.0 - distance) * 2.5
			var corridor: float = space.combat_motion_to_screen(point - brain.sample_path(0.65)).length()
			cost += maxf(0.0, 160.0 - corridor)
		if checked >= MAX_NEIGHBORS:
			break
	return cost


func attack_slot_available(actor: Node3D) -> bool:
	# Check live intentions at commitment, not the delayed perception cache.
	# Simultaneous decisions therefore cannot all claim the same opening.
	var committed := 0
	for ally in actor.get_tree().get_nodes_in_group(&"native_3d_enemies"):
		if ally == actor or not ally.is_active or ally.is_queued_for_deletion():
			continue
		if actor._flight_space.combat_motion_to_screen(ally.global_position - actor.global_position).length() > 650.0:
			continue
		var tactical_attack: bool = ally.is_maneuver_committed() and _is_offensive(ally._tactics._action)
		if ally.state in [actor.State.CHARGE_WINDUP, actor.State.CHARGE, actor.State.PHASE_WINDUP, actor.State.PHASE_DASH] or tactical_attack:
			committed += 1
			if committed >= 2:
				return false
	return true


static func _is_offensive(action: Action) -> bool:
	return action in [Action.IMMELMANN, Action.CORKSCREW, Action.LOW_YO_YO, Action.BOMBING_RUN]


func _yo_yo_situation(actor: Node3D, action: Action) -> bool:
	if actor.generation < 4 or approaching_fire or pressure >= 1.0 or actor._health_fraction() < 0.65 or actor._observed_player.get("is_boosting") == true:
		return false
	var to_player: Vector2 = actor._flight_space.combat_motion_to_screen(actor._observed_player.global_position - actor.global_position)
	var motion: Vector2 = actor._flight_space.combat_motion_to_screen(actor._observed_player.velocity)
	var heading: Vector2 = actor._flight_space.combat_motion_to_screen(actor._heading).normalized()
	if heading.dot(to_player.normalized()) < 0.2:
		return false
	if action == Action.HIGH_YO_YO:
		return to_player.length() > 130.0 and to_player.length() < 330.0 and absf(motion.cross(to_player.normalized())) > 100.0
	return to_player.length() > 260.0 and to_player.length() < 620.0 and actor._player_radial_speed > 90.0 and attack_slot_available(actor)


func _try_followup(actor: Node3D) -> bool:
	if _followup == Action.NONE:
		return false
	# New threats cancel the opportunity rather than forcing a rehearsed combo.
	if approaching_fire or pressure >= 1.0 or actor._health_fraction() < 0.65 or actor._observed_player.get("is_boosting") == true:
		_followup = Action.NONE
		return false
	if not _yo_yo_situation(actor, _followup):
		return false
	return prepare_plan(actor, _followup, "continuous follow-up from fresh observation", true)


func prepare_best_plan(actor: Node3D) -> bool:
	if not _decision_ready or has_plan():
		return false
	if actor.generation < 2 or actor._time_alive < 0.8 or not actor._inside_view() or not is_instance_valid(actor._observed_player):
		return false
	var is_sniper: bool = actor._supports_maneuver(Action.KNIFE_EDGE)
	if actor.state != actor._maneuver_entry_state():
		return false
	_decision_ready = false
	if _try_followup(actor):
		return true
	if _cooldown > 0.0 or actor._evade_cooldown > 0.0:
		return false
	if is_sniper:
		if actor.generation >= 3 and line_blocked and actor._player_distance_pixels >= 260.0:
			return prepare_plan(actor, Action.KNIFE_EDGE, "ally blocks firing lane")
		return false
	if actor._supports_maneuver(Action.BOMBING_RUN):
		if actor.generation >= 3 and not approaching_fire and pressure < 1.0 and actor._player_distance_pixels > 250.0 and actor._player_distance_pixels < 620.0 and actor._drop_timer > actor.BOMB_WINDUP_SECONDS and actor._mine_timer > actor.MINE_DEPLOY_SECONDS and not (last_action == Action.BOMBING_RUN and _repeat_lock > 0.0):
			return prepare_plan(actor, Action.BOMBING_RUN, "clear approach for a committed payload sweep")
		return false
	if not actor._supports_maneuver(Action.IMMELMANN):
		return false
	var to_player: Vector2 = actor._flight_space.combat_motion_to_screen(actor._observed_player.global_position - actor.global_position)
	var heading: Vector2 = actor._flight_space.combat_motion_to_screen(actor._heading).normalized()
	var boosting: bool = actor._observed_player.get("is_boosting") == true
	var closing_boost: bool = boosting and actor._player_radial_speed < -80.0
	var scores := {
		Action.SPLIT_S: 0.0, Action.SCISSORS: 0.0,
		Action.IMMELMANN: 0.0, Action.CORKSCREW: 0.0,
		Action.HIGH_YO_YO: 0.0, Action.LOW_YO_YO: 0.0, Action.HAMMERHEAD: 0.0,
	}
	if actor.generation >= 3:
		var retreat_health := 0.55 if role == 2 else 0.4
		if to_player.length() < 350.0 and (closing_boost or actor._health_fraction() < retreat_health):
			scores[Action.SPLIT_S] = 90.0 + pressure * 5.0
		if threat_count >= 3 or (pressure >= 1.6 and threat_count > 0):
			scores[Action.SCISSORS] = 75.0 + pressure * 5.0
		var willing_to_press: bool = role != 2 or actor._health_fraction() > 0.65
		if willing_to_press and not approaching_fire and not boosting and to_player.length() > 280.0 and to_player.length() < 650.0 and attack_slot_available(actor):
			scores[Action.CORKSCREW] = 35.0 + (20.0 if role == 1 else 0.0) + (10.0 if line_blocked else 0.0)
		var ahead: Vector3 = actor.global_position + actor._flight_space.screen_motion_to_combat(heading * 170.0)
		var clipped: float = actor._flight_space.combat_motion_to_screen(ahead - actor._clamp_maneuver_point(ahead)).length()
		if not approaching_fire and clipped > 65.0:
			scores[Action.HAMMERHEAD] = 82.0
	if _yo_yo_situation(actor, Action.HIGH_YO_YO):
		scores[Action.HIGH_YO_YO] = 70.0
	if _yo_yo_situation(actor, Action.LOW_YO_YO):
		scores[Action.LOW_YO_YO] = 68.0 + (6.0 if role == 0 else 0.0)
	if not approaching_fire and not boosting and to_player.length() > 180.0 and to_player.length() < 550.0 and heading.dot(to_player.normalized()) < -0.45 and attack_slot_available(actor):
		scores[Action.IMMELMANN] = 60.0
	var chosen: Action = Action.NONE
	var highest := 0.0
	for action: Action in scores:
		var score: float = scores[action]
		if action == last_action and _repeat_lock > 0.0:
			score = 0.0
		if score > highest:
			highest = score
			chosen = action
	if chosen == Action.NONE:
		return false
	var reasons := {Action.SPLIT_S: "close pressure / damaged hull", Action.SCISSORS: "sustained incoming fire", Action.IMMELMANN: "target behind flight path", Action.CORKSCREW: "open flank and squad attack slot",
		Action.HIGH_YO_YO: "brake for a crossing target", Action.LOW_YO_YO: "cut inside a fleeing target", Action.HAMMERHEAD: "turn away from the arena edge"}
	return prepare_plan(actor, chosen, reasons[chosen])


func prepare_plan(actor: Node3D, action: Action, reason: String, followup: bool = false) -> bool:
	if has_plan() or not actor.is_active or not actor._supports_maneuver(action) or actor.state != actor._maneuver_entry_state() or not is_instance_valid(actor._observed_player):
		return false
	if _is_offensive(action) and not attack_slot_available(actor):
		return false
	var space = actor._flight_space
	var origin: Vector3 = actor.global_position
	if origin.distance_to(actor._clamp_maneuver_point(origin)) > 0.1:
		return false
	var to_player: Vector2 = space.combat_motion_to_screen(actor._predicted_player - origin).normalized()
	if to_player.is_zero_approx():
		to_player = Vector2.DOWN
	var side := Vector2(-to_player.y, to_player.x)
	var lane: Vector3 = actor._choose_maneuver_shift(side, 450.0)
	var direction := signf(space.combat_motion_to_screen(lane).dot(side))
	if is_zero_approx(direction):
		return false
	side *= direction
	var travel: Vector2 = space.combat_motion_to_screen(actor._heading).normalized()
	var offsets: Array[Vector2] = []
	_warning = 0.0
	# These are baseline combat pixels (3300 vertically), not display pixels.
	# Broad arcs stay legible beside the scaled hulls at ordinary camera zoom.
	# Pursuit endpoints retain standoff; their control points supply the sweep.
	match action:
		Action.SPLIT_S:
			offsets = [Vector2.ZERO, travel * 145.0 + side * 260.0, -to_player * 470.0 + side * 360.0, -to_player * 575.0 + side * 240.0]
			_duration = 1.35
			_flight_state = actor.State.SPLIT_S
		Action.IMMELMANN:
			offsets = [Vector2.ZERO, travel * 310.0, to_player * 55.0 + side * 420.0, to_player * 330.0 + side * 260.0]
			_duration = 1.45
			_warning = 0.28
			_flight_state = actor.State.IMMELMANN
		Action.SCISSORS:
			var shot_side := Vector2(-_threat_direction.y, _threat_direction.x) * direction
			var width: float = maxf(360.0, actor._dodge_clearance_pixels(shot_side) * 2.0)
			offsets = [Vector2.ZERO, shot_side * width * 1.2, shot_side * width - to_player * 175.0, -shot_side * width * 1.2 - to_player * 275.0, -shot_side * width - to_player * 440.0]
			_duration = 1.85
			_flight_state = actor.State.SCISSORS
		Action.CORKSCREW:
			var target: Vector2 = space.combat_motion_to_screen(actor._predicted_player - origin) - to_player * 185.0 + side * 420.0
			target = target.limit_length(680.0)
			offsets = [Vector2.ZERO, side * 470.0, target - to_player * 230.0 + side * 230.0, target]
			_duration = 1.5
			_warning = 0.42
			_flight_state = actor.State.CORKSCREW
		Action.KNIFE_EDGE:
			offsets = [Vector2.ZERO, side * 175.0 - to_player * 70.0, side * 400.0 - to_player * 95.0, side * 520.0]
			_duration = 1.15
			_flight_state = actor.State.KNIFE_EDGE
		Action.HIGH_YO_YO:
			offsets = [Vector2.ZERO, travel * 240.0 + side * 150.0, side * 520.0 - to_player * 175.0, side * 420.0 - to_player * 80.0]
			_duration = 1.6
			_warning = 0.28
			_flight_state = actor.State.HIGH_YO_YO
		Action.LOW_YO_YO:
			var target: Vector2 = space.combat_motion_to_screen(actor._predicted_player - origin) - to_player * 175.0 + side * 260.0
			target = target.limit_length(520.0)
			offsets = [Vector2.ZERO, to_player * 240.0 - side * 460.0, target - to_player * 180.0 - side * 360.0, target]
			_duration = 1.35
			_warning = 0.4
			_flight_state = actor.State.LOW_YO_YO
		Action.HAMMERHEAD:
			var bounds: Rect2 = space.get_combat_bounds()
			var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
			var inward: Vector2 = space.combat_motion_to_screen(center - origin).normalized()
			if inward.is_zero_approx():
				inward = -travel
			# A real braking leg, short stall and fast return toward open space.
			offsets = [Vector2.ZERO, travel * 185.0, travel * 210.0, travel * 170.0 + side * 110.0, inward * 450.0 + side * 170.0, inward * 640.0 + side * 90.0]
			_duration = 1.7
			_flight_state = actor.State.HAMMERHEAD
		Action.BOMBING_RUN:
			var target: Vector2 = space.combat_motion_to_screen(actor._predicted_player - origin) * 0.65
			target = target.limit_length(400.0)
			offsets = [Vector2.ZERO, to_player * 240.0 - side * 240.0, target - side * 120.0, target + side * 510.0]
			_duration = 1.6
			_warning = 0.65
			_flight_state = actor.State.BOMBING_RUN
	_points.clear()
	for offset in offsets:
		_points.append(actor._clamp_maneuver_point(origin + space.screen_motion_to_combat(offset)))
	_points[0] = origin
	if space.combat_motion_to_screen(_points[-1] - origin).length() < 70.0:
		_points.clear()
		return false
	_entry_velocity = actor.velocity
	_exit_velocity = actor._cruise_velocity(_points[-1] - _points[-2])
	_cross_velocity = actor._cruise_velocity(_points[3] - _points[1]) if action == Action.SCISSORS else Vector3.ZERO
	_action = action
	_locked_target = actor._predicted_player
	_followup = Action.NONE
	_followup_left = 0.0
	_chain_depth = 1 if followup else 0
	last_action = action
	last_reason = reason
	_repeat_lock = 8.0
	_cooldown = 4.5 + float(role) * 0.3
	_direction = direction
	return true


func sample_path(progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	if _action == Action.HAMMERHEAD:
		# Keep the intentional apex stall, carrying velocity at the outer ends.
		if t < 0.36:
			t = smoothstep(0.0, 0.36, t)
			var climb := _points[0].lerp(_points[1], t).lerp(_points[1].lerp(_points[2], t), t)
			return carry_path_velocity(climb, progress / 0.36, _duration * 0.36, _entry_velocity, Vector3.ZERO)
		if t < 0.54:
			return _points[2]
		t = smoothstep(0.54, 1.0, t)
		var start := _points[2].lerp(_points[3], t)
		var middle := _points[3].lerp(_points[4], t)
		var end := _points[4].lerp(_points[5], t)
		var descent := start.lerp(middle, t).lerp(middle.lerp(end, t), t)
		return carry_path_velocity(descent, (progress - 0.54) / 0.46, _duration * 0.46, Vector3.ZERO, _exit_velocity)
	if _action == Action.SCISSORS:
		var segment := 0 if t < 0.5 else 2
		var leg := t * 2.0 - (1.0 if segment == 2 else 0.0)
		t = smoothstep(0.0, 1.0, leg)
		var cut := _points[segment].lerp(_points[segment + 1], t).lerp(_points[segment + 1].lerp(_points[segment + 2], t), t)
		return carry_path_velocity(cut, leg, _duration * 0.5, _entry_velocity if segment == 0 else _cross_velocity, _cross_velocity if segment == 0 else _exit_velocity)
	t = smoothstep(0.0, 1.0, t)
	var a := _points[0].lerp(_points[1], t)
	var b := _points[1].lerp(_points[2], t)
	var c := _points[2].lerp(_points[3], t)
	return carry_path_velocity(a.lerp(b, t).lerp(b.lerp(c, t), t), progress, _duration, _entry_velocity, _exit_velocity)


static func carry_path_velocity(point: Vector3, progress: float, seconds: float, entry_velocity: Vector3, exit_velocity: Vector3, original_entry: Vector3 = Vector3.ZERO, blend_seconds: float = 0.18) -> Vector3:
	# Local endpoint corrections preserve the route and match its derivative to
	# the incoming/outgoing flight. The correction and its first two derivatives
	# vanish at the blend boundary, so no new corner appears inside the path.
	var blend := minf(blend_seconds, seconds * 0.25)
	var elapsed := clampf(progress, 0.0, 1.0) * seconds
	var remaining := seconds - elapsed
	if elapsed < blend:
		point += (entry_velocity - original_entry) * elapsed * pow(1.0 - elapsed / blend, 3.0)
	if remaining < blend:
		point -= exit_velocity * remaining * pow(1.0 - remaining / blend, 3.0)
	return point


func _present_tell(actor: Node3D) -> void:
	if not is_instance_valid(_tell):
		_tell = Tell.new()
		actor.add_child(_tell)
	var samples := PackedVector3Array()
	for index in 17:
		samples.append(sample_path(float(index) / 16.0))
	_tell.present(samples, LABELS[_action], _locked_target, _action == Action.BOMBING_RUN)


func cancel() -> void:
	_action = Action.NONE
	_followup = Action.NONE
	_followup_left = 0.0
	_chain_depth = 0
	_points.clear()
	if is_instance_valid(_tell):
		_tell.hide()


func debug_state() -> Dictionary:
	return {"role": ["pressure", "flanker", "cautious"][role], "pressure": pressure,
		"incoming_threats": threat_count, "approaching_fire": approaching_fire, "lane_blocked": line_blocked,
		"screening_ally": has_support, "last_maneuver": Action.keys()[last_action],
		"reason": last_reason, "cooldown": _cooldown,
		"followup": Action.keys()[_followup], "chain_depth": _chain_depth}
