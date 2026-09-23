extends Node3D
class_name BossCombatPresentation
## Visuals only: never deals damage or decides the next attack.
const Definition := preload("res://systems/boss_attack_definition.gd")
var _actor: BasicEnemy3D
var _space: FlightSpace3D
var _warning: MeshInstance3D
var _lane: MeshInstance3D
var _slam: MeshInstance3D

func _ready() -> void:
	_lane = _make_plane(preload("res://effects/shaders/lane_telegraph_3d.gdshader"))
	_slam = _make_plane(preload("res://effects/shaders/boss_slam_telegraph.gdshader"))

func configure(actor: BasicEnemy3D, space: FlightSpace3D) -> void:
	_actor = actor
	_space = space
	_warning = actor.get_node("Attachments/Warning")
	clear()

func _make_plane(shader: Shader) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.top_level = true
	mesh.hide()
	return mesh

func face(delta: float, target: Vector3, response: float) -> void:
	var direction := target - _actor.global_position
	if direction.is_zero_approx():
		return
	# Rotate only the model; damage geometry and the committed tell stay fixed.
	var heading := atan2(-direction.x, -direction.z) - _actor.global_rotation.y
	_actor.visuals.rotation.y = lerp_angle(_actor.visuals.rotation.y, heading, 1.0 - exp(-response * delta))

func telegraph(plan: BossAttackPlan) -> void:
	clear()
	_actor.play_motion(&"windup", plan.warning_seconds, true)
	_warning.show()
	match plan.definition.family:
		Definition.Family.SLAM:
			var radius := plan.definition.slam_radius
			var across := _space.screen_motion_to_combat(Vector2(radius * 2.0, 0))
			var along := _space.screen_motion_to_combat(Vector2(0, radius * 2.0))
			_slam.global_transform = Transform3D(Basis(across, Vector3.UP, along), plan.origin + Vector3.UP * 0.06)
			_slam.show()
		Definition.Family.CHARGE:
			var along := plan.charge_endpoint - plan.origin
			var across := _space.screen_motion_to_combat(plan.aim.orthogonal() * plan.definition.charge_half_width * 2.0)
			_lane.global_transform = Transform3D(Basis(across, Vector3.UP, along), (plan.origin + plan.charge_endpoint) * 0.5 + Vector3.UP * 0.06)
			_lane.set_instance_shader_parameter(&"lane_size", Vector2(plan.definition.charge_half_width * 2.0, _space.combat_motion_to_screen(along).length()))
			_lane.show()
		Definition.Family.PROJECTILE:
			pass
	progress(0.0)

func progress(fraction: float) -> void:
	_lane.set_instance_shader_parameter(&"charge_progress", fraction)
	_slam.set_instance_shader_parameter(&"charge_progress", fraction)
	_warning.scale = Vector3.ONE * (1.0 + fraction * 0.15)

func release() -> void:
	clear()
	attack_pulse()

func attack_pulse() -> void:
	_actor.play_motion(&"attack")

func clear(reset_motion: bool = true) -> void:
	_lane.hide()
	_slam.hide()
	if is_instance_valid(_warning):
		_warning.hide()
		_warning.scale = Vector3.ONE
	if reset_motion and is_instance_valid(_actor):
		_actor.play_motion(&"cruise")
