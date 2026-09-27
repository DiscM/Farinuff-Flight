extends Native3DGameplay
## Verify real hull transforms, safe combat integration and per-craft variety.
const Flight := preload("res://effects/enemy_flight_motion_3d.gd")
const BoneMotion := preload("res://effects/ship_motion_3d.gd")
const ENEMIES := {
	"basic": preload("res://entities/enemies/basic_enemy_3d.tscn"),
	"fast": preload("res://entities/enemies/fast_enemy_3d.tscn"),
	"bomber": preload("res://entities/enemies/bomber_enemy_3d.tscn"),
	"tank": preload("res://entities/enemies/tank_enemy_3d.tscn"),
	"sniper": preload("res://entities/enemies/sniper_enemy_3d.tscn"),
	"courier": preload("res://entities/enemies/courier_enemy_3d.tscn"),
	"boss": preload("res://entities/enemies/boss_enemy_3d.tscn"),
}
const STEP := 1.0 / 60.0
var _failures: Array[String] = []


func _ready() -> void:
	await super._ready()
	_run.call_deferred()


func _run() -> void:
	player.set_physics_process(false)
	player.set_dev_god_mode(true)
	GameManager.is_game_active = true
	var previous_reduced: bool = SaveManager.get_setting("reduced_motion", false)
	SaveManager.settings["reduced_motion"] = false
	for role in ENEMIES:
		var enemy := _spawn(role)
		_check_cruise_safety(enemy, role)
		_check_expressive_banking(enemy, role)
		_check_telegraph(enemy, role)
		_check_reduced_motion(enemy, role)
		if role == "basic":
			_check_rolls(enemy)
			_check_interruptions(enemy)
			await _check_pause(enemy)
		if role == "fast":
			_check_phase_transition(enemy)
		if role == "boss":
			_check_boss_facing(enemy)
		enemy.queue_free()
		await get_tree().process_frame
	_check_independent_timing()
	SaveManager.settings["reduced_motion"] = previous_reduced
	await ResourceCache.wait_for_scene("res://scenes/native_3d_run.tscn")
	for failure in _failures:
		push_error(failure)
	print("ENEMY_FLIGHT_MOTION_SMOKE_PASS" if _failures.is_empty() else "ENEMY_FLIGHT_MOTION_SMOKE_FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _spawn(role: String) -> BasicEnemy3D:
	var enemy := (ENEMIES[role] as PackedScene).instantiate() as BasicEnemy3D
	actors_root.add_child(enemy)
	_expect(enemy.activate_generation(flight_space, Vector3.ZERO, Vector3.FORWARD, 4), role + " activates")
	enemy.set_physics_process(false)
	if role == "boss":
		enemy.get("_arena_patterns").set_physics_process(false)
	return enemy


func _check_cruise_safety(enemy: BasicEnemy3D, role: String) -> void:
	var collision := enemy.collision_shape.global_transform
	var actor_transform := enemy.global_transform
	var velocity_before := enemy.velocity
	var state_before := enemy.state
	var attachments_before := enemy.attachments.transform
	var maneuvers: Array[int] = []
	var previous := Flight.Maneuver.NONE
	var previous_rotation := Quaternion.IDENTITY
	var largest_step := 0.0
	for tick in 180:
		enemy.advance_motion(STEP)
		var flight := enemy._flight_motion
		var rotation_now := flight.pose.basis.get_rotation_quaternion()
		largest_step = maxf(largest_step, previous_rotation.angle_to(rotation_now))
		previous_rotation = rotation_now
		if flight.current_maneuver != Flight.Maneuver.NONE and flight.current_maneuver != previous:
			maneuvers.append(flight.current_maneuver)
			previous = flight.current_maneuver
			_check_sockets(enemy, role)
	_expect(maneuvers.is_empty(), role + " cruise cannot advertise a combat maneuver without its gameplay action")
	_expect(largest_step < 0.35, role + " starts, rolls and settles without a rotation snap")
	_expect(enemy.global_transform.is_equal_approx(actor_transform) and enemy.velocity == velocity_before and enemy.state == state_before, role + " animation preserves locomotion and AI state")
	_expect(enemy.collision_shape.global_transform.is_equal_approx(collision), role + " animation leaves the contact envelope fixed")
	_expect(enemy.attachments.transform.is_equal_approx(attachments_before), role + " leaves warning and armor parents fixed")
	if role in ["bomber", "tank", "sniper", "boss"]:
		_expect(not maneuvers.has(Flight.Maneuver.AILERON_ROLL) and not maneuvers.has(Flight.Maneuver.BARREL_ROLL) and not maneuvers.has(Flight.Maneuver.SPIN), role + " uses restrained maneuvers")


func _check_expressive_banking(enemy: BasicEnemy3D, role: String) -> void:
	var flight := enemy._flight_motion
	flight.reset(0.0, 31)
	var heading := 0.0
	for tick in 60:
		heading += STEP * deg_to_rad(90.0)
		flight.advance(STEP, heading, false)
	var lean := flight.pose.basis.y.angle_to(Vector3.UP)
	_expect(lean > deg_to_rad(15.0 if role == "boss" else 22.0), role + " visibly leans into an ordinary turn at gameplay scale")
	var maneuver := Flight.Maneuver.WINGOVER if role == "sniper" else Flight.Maneuver.BANK_REVERSAL
	var peak := 0.0
	for frame in 121:
		peak = maxf(peak, flight._sample(maneuver, float(frame) / 120.0).basis.y.angle_to(Vector3.UP))
	_expect(peak > deg_to_rad(30.0), role + " has a distinct broad bank during its combat maneuver")
	flight.reset(enemy.global_rotation.y + enemy.visuals.rotation.y, 31)


func _check_sockets(enemy: BasicEnemy3D, role: String) -> void:
	for pair in enemy._animated_sockets:
		if pair[1].is_visible_in_tree():
			_expect(pair[0].global_transform.is_equal_approx(BoneMotion.socket_transform(pair[1])), role + " bone socket stays on the animated hull")
	var core := enemy.get_socket(&"Core")
	if core != null:
		var flight := enemy._flight_motion
		var marker_index := flight._markers.find(core)
		var original: Transform3D = enemy.sockets.global_transform * flight._marker_rest[marker_index]
		var visual_delta := enemy.visuals.global_transform * flight.pose * enemy.visuals.global_transform.affine_inverse()
		_expect(core.global_transform.is_equal_approx(visual_delta * original), role + " unrigged core follows the hull")


func _check_rolls(enemy: BasicEnemy3D) -> void:
	for maneuver in [Flight.Maneuver.AILERON_ROLL, Flight.Maneuver.BARREL_ROLL, Flight.Maneuver.SPIN]:
		enemy._flight_motion.reset(0.0, 31)
		enemy._flight_motion.play(maneuver, 1.0, 1.2)
		var model := enemy.visuals.get_child(0) as Node3D
		var rest := model.transform
		var previous := Quaternion.IDENTITY
		var rotation_travel := 0.0
		var translated := false
		for tick in 73:
			enemy.advance_motion(STEP)
			var relative := model.transform * rest.affine_inverse()
			var current := relative.basis.get_rotation_quaternion()
			rotation_travel += previous.angle_to(current)
			previous = current
			translated = translated or relative.origin.length() > 0.1
			_check_sockets(enemy, "rolling fighter")
		_expect(rotation_travel > 6.0, "Full rolls/spins complete 360 degrees instead of interpolating identical endpoints")
		_expect(previous.angle_to(Quaternion.IDENTITY) < deg_to_rad(5.0), "Completed maneuver returns the hull to level cruise")
		_expect(translated == (maneuver == Flight.Maneuver.BARREL_ROLL), "Only the barrel roll adds a small helical arc")
		_expect(not enemy._flight_motion.is_playing(), "Long and normal frames finish maneuvers cleanly")
	enemy._flight_motion.play(Flight.Maneuver.SPIN)
	enemy.advance_motion(4.0)
	_expect(not enemy._flight_motion.is_playing(), "A long frame completes without a stuck spin")


func _check_interruptions(enemy: BasicEnemy3D) -> void:
	for elapsed in [0.55, 0.6, 0.65]:
		enemy._flight_motion.reset(0.0, 31)
		enemy._flight_motion.play(Flight.Maneuver.SPIN, 1.0, 1.2)
		enemy.advance_motion(elapsed)
		var previous := enemy._flight_motion.pose.basis.get_rotation_quaternion()
		enemy._flight_motion.play(Flight.Maneuver.SPIN, -1.0, 1.2)
		for tick in 16:
			enemy.advance_motion(STEP)
			var current := enemy._flight_motion.pose.basis.get_rotation_quaternion()
			_expect(previous.angle_to(current) < 0.65, "Interrupting an inverted spin never flips the interpolation arc")
			previous = current


func _check_telegraph(enemy: BasicEnemy3D, role: String) -> void:
	enemy._flight_motion.play(Flight.Maneuver.BARREL_ROLL, 1.0, 1.2)
	enemy.advance_motion(0.5)
	var held := enemy._flight_motion.pose
	enemy.play_motion(&"windup", 0.55, true)
	_expect(enemy._flight_motion.pose.is_equal_approx(held), role + " entering a warning does not snap the hull")
	for tick in 60:
		enemy.advance_motion(STEP)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY), role + " settles and holds level throughout the warning")
	enemy.play_motion(&"hit")
	enemy._flight_motion.play(Flight.Maneuver.SPIN)
	enemy.advance_motion(0.1)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY), role + " damage and new maneuvers cannot obscure the warning")
	enemy.play_motion(&"attack")
	_check_sockets(enemy, role + " release")


func _check_reduced_motion(enemy: BasicEnemy3D, role: String) -> void:
	enemy._flight_motion.play(Flight.Maneuver.AILERON_ROLL)
	enemy.advance_motion(0.35)
	SaveManager.settings["reduced_motion"] = true
	enemy.advance_motion(STEP)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY), role + " Reduced Motion clears active aerobatics")
	enemy._flight_motion.react(&"EVADE", 1.0)
	enemy.advance_motion(3.0)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY), role + " Reduced Motion suppresses new aerobatics")
	SaveManager.settings["reduced_motion"] = false
	enemy.advance_motion(STEP)
	enemy._flight_motion.reset(enemy.global_rotation.y + enemy.visuals.rotation.y, 31)
	_expect(enemy._flight_motion.pose.is_equal_approx(Transform3D.IDENTITY) and not enemy._flight_motion.is_playing(), role + " reset restores authored hull transforms")


func _check_pause(enemy: BasicEnemy3D) -> void:
	enemy._flight_motion.play(Flight.Maneuver.BARREL_ROLL)
	enemy.advance_motion(0.3)
	var held := enemy._flight_motion.pose
	GameManager.is_game_active = false
	enemy._physics_process(0.2)
	_expect(enemy._flight_motion.pose.is_equal_approx(held), "Inactive gameplay freezes aerobatics")
	GameManager.is_game_active = true
	get_tree().paused = true
	enemy.set_physics_process(true)
	await get_tree().create_timer(0.06, true).timeout
	_expect(enemy._flight_motion.pose.is_equal_approx(held), "Scene pause freezes the hull at its current pose")
	enemy.set_physics_process(false)
	get_tree().paused = false


func _check_phase_transition(enemy: BasicEnemy3D) -> void:
	var fast := enemy as FastEnemy3D
	fast._visible_time = 1.0
	fast._phase_cooldown = 0.0
	_expect(fast._try_begin_phase(), "Fast enemy starts a real phase warning")
	fast.advance_motion(FastEnemy3D.PHASE_WARNING_SECONDS)
	fast.state_remaining = 0.0
	fast._advance_movement(STEP)
	_expect(fast._flight_motion.current_maneuver == Flight.Maneuver.SPIN, "The actual phase-dash release triggers a spin transition")
	fast.advance_motion(0.12)
	var held := fast._flight_motion.pose
	fast.state_remaining = 0.0
	fast._advance_movement(STEP)
	_expect(fast.state == BasicEnemy3D.State.TRANSIT and fast._flight_motion.current_maneuver == Flight.Maneuver.NONE, "Completed flanking spin resumes normal flight")
	_expect(fast._flight_motion.pose.is_equal_approx(held), "Dash-to-cruise blends from the existing pose")


func _check_boss_facing(enemy: BasicEnemy3D) -> void:
	var ai: BossAI = enemy.get("_boss_ai")
	ai.presentation.face(0.3, Vector3(20, 0, -10), 5.0)
	var facing := enemy.visuals.rotation.y
	enemy.advance_motion(0.3)
	_expect(is_equal_approx(enemy.visuals.rotation.y, facing), "Boss banking preserves the presentation controller's facing")
	_check_sockets(enemy, "turning boss")


func _check_independent_timing() -> void:
	var first := _spawn("basic")
	var second := _spawn("basic")
	var varied := false
	for tick in 150:
		first.advance_motion(STEP)
		second.advance_motion(STEP)
		varied = varied or not first._flight_motion.pose.is_equal_approx(second._flight_motion.pose)
	_expect(varied, "Identical enemies have independent timing and roll direction")
	first.queue_free()
	second.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
