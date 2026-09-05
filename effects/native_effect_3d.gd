extends Node3D
class_name NativeEffect3D
## Pooled native mesh flashes, shock rings, and GPU sparks.

signal returned_to_pool(effect: NativeEffect3D)

enum EffectKind { MUZZLE, IMPACT, DEATH, BOOST, PICKUP }

@onready var particles: GPUParticles3D = $Particles
@onready var burst_mesh: MeshInstance3D = $BurstMesh
@onready var pulse_mesh: MeshInstance3D = $PulseMesh

const SHOCK_RING := preload("res://assets/models/native/shock_ring.glb")
const MUZZLE_FLARE := preload("res://assets/models/native/muzzle_flare.glb")
var _flare: Mesh
var _impact_mesh: Mesh
var is_active := false
var _idle_parent: Node3D
var _kind := EffectKind.IMPACT
var _elapsed := 0.0
var _duration := 0.24
var _intensity := 1.0


func _ready() -> void:
	_impact_mesh = burst_mesh.mesh
	_flare = _extract_mesh(MUZZLE_FLARE)
	pulse_mesh.material_override = pulse_mesh.mesh.surface_get_material(0)
	pulse_mesh.mesh = _extract_mesh(SHOCK_RING)
	burst_mesh.material_override = _impact_mesh.surface_get_material(0)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	particles.emitting = false
	_set_shader_state(Color.TRANSPARENT, 0.0, 0.0)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render the effect mesh and particle pipeline under the transition cover
## without arming gameplay, starting emission, or joining a live effect set.
func prepare_visual_warmup() -> void:
	is_active = false
	transform = Transform3D.IDENTITY
	visible = true
	burst_mesh.visible = true
	pulse_mesh.visible = true
	particles.amount = 8
	particles.lifetime = 0.18
	particles.restart()
	particles.emitting = true
	_set_shader_state(Color(0.2, 0.8, 1.0, 1.0), 0.18, 1.0)


func play(
	kind: EffectKind,
	effect_position: Vector3,
	direction: Vector3 = Vector3.FORWARD,
	intensity: float = 1.0
) -> bool:
	if is_active or _idle_parent == null:
		return false
	_kind = kind
	_intensity = maxf(intensity, 0.1)
	_elapsed = 0.0
	_duration = _get_duration(kind)
	is_active = true
	global_position = Vector3(effect_position.x, 0.0, effect_position.z)
	rotation.y = _get_yaw(direction)
	scale = Vector3.ONE
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	var color := _get_color(kind)
	_set_shader_state(color, 1.0, _get_emission(kind))
	burst_mesh.mesh = _flare if kind == EffectKind.MUZZLE else _impact_mesh
	burst_mesh.scale = Vector3.ONE * 0.25 * _intensity
	pulse_mesh.scale = Vector3.ONE * 0.35 * _intensity
	burst_mesh.visible = true
	pulse_mesh.visible = kind != EffectKind.MUZZLE
	particles.amount = _get_particle_amount(kind)
	particles.lifetime = _get_particle_lifetime(kind)
	particles.restart()
	particles.emitting = true
	return true


func _process(delta: float) -> void:
	if not is_active:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	if _kind == EffectKind.MUZZLE:
		burst_mesh.scale = Vector3.ONE * lerpf(0.5, 1.8, expansion) * _intensity
		pulse_mesh.scale = Vector3.ONE * lerpf(0.4, 1.2, expansion) * _intensity
	else:
		burst_mesh.scale = Vector3.ONE * lerpf(0.25, 1.3, expansion) * _intensity
		pulse_mesh.scale = Vector3(lerpf(0.35, 2.6, expansion), 1.0, lerpf(0.35, 2.6, expansion)) * _intensity
	_set_shader_state(_get_color(_kind), fade, _get_emission(_kind) * (0.45 + fade * 0.55))
	if _elapsed >= _duration:
		despawn()


func despawn() -> void:
	if not is_active and get_parent() == _idle_parent:
		return
	is_active = false
	visible = false
	set_process(false)
	particles.emitting = false
	process_mode = Node.PROCESS_MODE_DISABLED
	burst_mesh.visible = false
	pulse_mesh.visible = false
	scale = Vector3.ONE
	_set_shader_state(Color.TRANSPARENT, 0.0, 0.0)
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _get_duration(kind: EffectKind) -> float:
	match kind:
		EffectKind.MUZZLE:
			return 0.12
		EffectKind.IMPACT:
			return 0.2
		EffectKind.DEATH:
			return 0.52
		EffectKind.BOOST:
			return 0.3
		EffectKind.PICKUP:
			return 0.34
	return 0.24


func _get_particle_amount(kind: EffectKind) -> int:
	match kind:
		EffectKind.MUZZLE:
			return 5
		EffectKind.IMPACT:
			return 8
		EffectKind.DEATH:
			return 20
		EffectKind.BOOST:
			return 14
		EffectKind.PICKUP:
			return 16
	return 8


func _get_particle_lifetime(kind: EffectKind) -> float:
	return 0.12 if kind == EffectKind.MUZZLE else 0.18 if kind == EffectKind.IMPACT else 0.42 if kind == EffectKind.DEATH else 0.32 if kind == EffectKind.PICKUP else 0.28


func _get_color(kind: EffectKind) -> Color:
	match kind:
		EffectKind.MUZZLE:
			return Color(0.18, 0.8, 1.0, 1.0)
		EffectKind.IMPACT:
			return Color(1.0, 0.45, 0.08, 1.0)
		EffectKind.DEATH:
			return Color(1.0, 0.1, 0.42, 1.0)
		EffectKind.BOOST:
			return Color(0.2, 1.0, 0.56, 1.0)
		EffectKind.PICKUP:
			return Color(1.0, 0.78, 0.18, 1.0)
	return Color.WHITE


func _get_emission(kind: EffectKind) -> float:
	return 2.6 if kind == EffectKind.DEATH else 2.0


func _get_yaw(direction: Vector3) -> float:
	var flat := Vector2(direction.x, direction.z)
	return atan2(-flat.x, -flat.y) if not flat.is_zero_approx() else 0.0


func _set_shader_state(color: Color, alpha: float, emission: float) -> void:
	burst_mesh.set_instance_shader_parameter(&"instance_color", color)
	burst_mesh.set_instance_shader_parameter(&"instance_alpha", alpha)
	burst_mesh.set_instance_shader_parameter(&"instance_emission", emission)
	pulse_mesh.set_instance_shader_parameter(&"instance_color", color)
	pulse_mesh.set_instance_shader_parameter(&"instance_alpha", alpha)
	pulse_mesh.set_instance_shader_parameter(&"instance_emission", emission)


func _extract_mesh(scene: PackedScene) -> Mesh:
	var model := scene.instantiate()
	var mesh_node := model.find_child("*", true, false) as MeshInstance3D
	if mesh_node == null:
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		mesh_node = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	var mesh: Mesh = mesh_node.mesh if mesh_node != null else _impact_mesh
	model.free()
	return mesh
