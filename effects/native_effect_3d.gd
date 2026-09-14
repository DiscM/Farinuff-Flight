extends Node3D
class_name NativeEffect3D
## Bounded native 3D feedback unit for combat, telegraphs, and pickups.
##
## Every visual is local to this pooled wrapper: meshes and particles are
## reused, gameplay remains on the Combat Plane, and the manager decides which
## effects may claim one of the small number of local light slots.

signal returned_to_pool(effect: NativeEffect3D)

enum EffectKind {
	MUZZLE,
	IMPACT,
	DEATH,
	BOOST,
	PICKUP,
	PROJECTILE,
	EXPLOSION,
	SHIELD,
	TELEGRAPH,
	REFLECT,
	ARMOR_BREAK,
	VOID_COLLAPSE,
	HOSTILE_MUZZLE,
}

const Palette := preload("res://effects/rendering/frontier_palette.gd")
const Fragments := preload("res://effects/frontier_fragments_3d.gd")
var fragments: Fragments

const SHOCK_RING := preload("res://assets/models/native/shock_ring.glb")
const MUZZLE_FLARE := preload("res://assets/models/native/muzzle_flare.glb")

const DEFAULT_DURATION := 0.24
const MAX_EFFECT_DURATION := 0.85
const MIN_INTENSITY := 0.1
const MAX_INTENSITY := 2.5
## Keep the warm-up at the largest runtime particle buffer so no effect event
## needs to grow a GPUParticles3D buffer on its first use.
const WARMUP_PARTICLE_AMOUNT := 24
const WARMUP_PARTICLE_LIFETIME := 0.48

@onready var core_mesh: MeshInstance3D = $CoreMesh
@onready var burst_mesh: MeshInstance3D = $BurstMesh
@onready var pulse_mesh: MeshInstance3D = $PulseMesh
@onready var secondary_ring: MeshInstance3D = $SecondaryRing
@onready var streak_mesh: MeshInstance3D = $StreakMesh
@onready var particles: GPUParticles3D = $Particles
@onready var burst_light: OmniLight3D = $BurstLight

var _flare: Mesh
var _impact_mesh: Mesh
var _shock_ring: Mesh
var _streak_mesh: Mesh
var is_active := false
var _idle_parent: Node3D
var _kind := EffectKind.IMPACT
var _elapsed := 0.0
var _duration := DEFAULT_DURATION
var _intensity := 1.0
var _phase_offset := 0.0
var _local_light_enabled := false


func _ready() -> void:
	fragments = Fragments.new()
	fragments.name = "Fragments"
	add_child(fragments)
	_impact_mesh = burst_mesh.mesh
	_streak_mesh = streak_mesh.mesh
	_flare = _extract_mesh(MUZZLE_FLARE)
	_shock_ring = _extract_mesh(SHOCK_RING)
	var effect_material := _impact_mesh.surface_get_material(0)
	var ring_material := pulse_mesh.mesh.surface_get_material(0)
	burst_mesh.material_override = effect_material
	streak_mesh.material_override = effect_material
	pulse_mesh.material_override = ring_material
	secondary_ring.material_override = ring_material
	pulse_mesh.mesh = _shock_ring
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	particles.emitting = false
	burst_light.visible = false
	burst_light.light_energy = 0.0
	_set_shader_state(Color.TRANSPARENT, 0.0, 0.0)


func configure_pool(idle_parent: Node3D) -> void:
	_idle_parent = idle_parent


## Render every mesh/material and the particle pipeline under the transition
## cover without arming gameplay, starting a live effect, or claiming a light.
func prepare_visual_warmup() -> void:
	fragments.configure(false)
	fragments.advance(0.2, 1.0, 0.0)
	is_active = false
	transform = Transform3D.IDENTITY
	_kind = EffectKind.IMPACT
	_elapsed = 0.0
	_duration = 0.24
	_intensity = 1.0
	_phase_offset = 0.0
	_local_light_enabled = false
	visible = true
	burst_mesh.mesh = _impact_mesh
	# Reuse the streak slot to draw the imported muzzle mesh during warm-up.
	# It is restored before play, so this adds no pooled nodes or event-time
	# allocations while warming both geometry families under the cover.
	streak_mesh.mesh = _flare
	core_mesh.visible = true
	burst_mesh.visible = true
	pulse_mesh.visible = true
	secondary_ring.visible = true
	streak_mesh.visible = true
	particles.amount = WARMUP_PARTICLE_AMOUNT
	particles.lifetime = WARMUP_PARTICLE_LIFETIME
	burst_light.visible = false
	burst_light.light_energy = 0.0
	particles.restart()
	particles.emitting = true
	_set_shader_state(Color(0.2, 0.8, 1.0, 1.0), 0.18, 1.0)


func play(
	kind: EffectKind,
	effect_position: Vector3,
	direction: Vector3 = Vector3.FORWARD,
	intensity: float = 1.0,
	preserve_height: bool = false,
	emit_local_light: bool = false
) -> bool:
	if is_active or _idle_parent == null:
		return false
	_kind = kind
	_intensity = clampf(intensity, MIN_INTENSITY, MAX_INTENSITY)
	_elapsed = 0.0
	_duration = minf(_get_duration(kind), MAX_EFFECT_DURATION)
	_phase_offset = float(Time.get_ticks_usec() % 1000) * 0.006
	is_active = true
	var visual_position := effect_position
	visual_position.y = effect_position.y if preserve_height else 0.0
	global_position = visual_position
	rotation.y = _get_yaw(direction)
	scale = Vector3.ONE
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	var color := _get_color(kind)
	burst_mesh.mesh = _flare if kind in [EffectKind.MUZZLE, EffectKind.HOSTILE_MUZZLE, EffectKind.REFLECT] else _impact_mesh
	streak_mesh.mesh = _streak_mesh
	core_mesh.visible = kind != EffectKind.TELEGRAPH
	burst_mesh.visible = kind != EffectKind.TELEGRAPH
	pulse_mesh.visible = _uses_pulse_mesh(kind)
	secondary_ring.visible = _uses_secondary_ring(kind)
	streak_mesh.visible = _uses_streak_mesh(kind)
	fragments.visible = kind in [EffectKind.DEATH, EffectKind.ARMOR_BREAK, EffectKind.VOID_COLLAPSE]
	if fragments.visible:
		fragments.configure(kind == EffectKind.VOID_COLLAPSE)
		fragments.advance(0.0, _intensity, _phase_offset)
	particles.amount = _get_particle_amount(kind)
	particles.lifetime = _get_particle_lifetime(kind)
	particles.restart()
	particles.emitting = true
	_set_shader_state(color, 1.0, _get_emission(kind))
	_local_light_enabled = emit_local_light and _get_light_energy(kind) > 0.0
	burst_light.visible = _local_light_enabled
	burst_light.light_color = color
	burst_light.light_energy = _get_light_energy(kind) * _intensity if _local_light_enabled else 0.0
	return true


func _process(delta: float) -> void:
	if not is_active:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 1.0 - progress
	if fragments.visible:
		fragments.advance(progress, _intensity, _phase_offset)
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	var pulse := 0.78 + 0.22 * sin(_elapsed * 18.0 + _phase_offset)
	var mesh_scale := 0.25
	var ring_scale := 0.35
	var streak_width := 0.5
	var streak_length := 1.0
	match _kind:
		EffectKind.MUZZLE, EffectKind.HOSTILE_MUZZLE:
			mesh_scale = lerpf(0.45, 1.45, expansion)
			ring_scale = lerpf(0.45, 1.1, expansion)
			streak_width = lerpf(0.7, 0.35, progress)
			streak_length = lerpf(0.7, 1.8, expansion)
		EffectKind.PROJECTILE:
			mesh_scale = lerpf(0.16, 0.48, expansion)
			streak_width = lerpf(0.32, 0.12, progress)
			streak_length = lerpf(0.45, 1.25, expansion)
		EffectKind.TELEGRAPH:
			streak_width = lerpf(1.35, 0.6, progress)
			streak_length = lerpf(7.0, 9.0, expansion)
			ring_scale = lerpf(0.55, 1.4, expansion)
		EffectKind.SHIELD:
			mesh_scale = lerpf(0.6, 2.1, expansion)
			ring_scale = lerpf(0.75, 3.2, expansion)
		EffectKind.EXPLOSION:
			mesh_scale = lerpf(0.3, 2.65, expansion)
			ring_scale = lerpf(0.4, 3.8, expansion)
			streak_length = lerpf(1.0, 2.2, expansion)
		EffectKind.DEATH:
			mesh_scale = lerpf(0.25, 1.75, expansion)
			ring_scale = lerpf(0.35, 2.8, expansion)
		EffectKind.BOOST:
			mesh_scale = lerpf(0.22, 0.82, expansion)
			ring_scale = lerpf(0.4, 1.8, expansion)
			streak_width = lerpf(1.0, 0.35, progress)
			streak_length = lerpf(2.0, 4.2, expansion)
		EffectKind.PICKUP:
			mesh_scale = lerpf(0.18, 0.72, expansion)
			ring_scale = lerpf(0.3, 1.55, expansion)
		EffectKind.REFLECT:
			mesh_scale = lerpf(1.2, 0.15, progress)
			ring_scale = lerpf(0.45, 2.2, expansion)
			streak_width = lerpf(1.4, 0.12, progress)
			streak_length = lerpf(1.0, 5.2, expansion)
		EffectKind.ARMOR_BREAK:
			mesh_scale = lerpf(1.4, 0.12, expansion)
			ring_scale = lerpf(0.5, 3.4, expansion)
		EffectKind.VOID_COLLAPSE:
			mesh_scale = lerpf(1.5, 0.08, minf(progress / 0.42, 1.0)) if progress < 0.42 else lerpf(1.8, 0.0, (progress - 0.42) / 0.58)
			ring_scale = lerpf(3.2, 0.12, minf(progress / 0.42, 1.0))
	if _kind == EffectKind.IMPACT:
		mesh_scale = lerpf(0.95, 0.05, expansion)
		streak_width = lerpf(0.7, 0.05, progress)
		streak_length = lerpf(0.6, 1.8, expansion)
	core_mesh.scale = Vector3.ONE * mesh_scale * _intensity
	burst_mesh.scale = Vector3.ONE * mesh_scale * _intensity
	pulse_mesh.scale = Vector3(ring_scale, 1.0, ring_scale) * _intensity * (0.92 + pulse * 0.08)
	secondary_ring.scale = Vector3.ONE * ring_scale * _intensity * (0.9 + pulse * 0.1)
	streak_mesh.scale = Vector3(streak_width, streak_width, streak_length) * _intensity
	_set_shader_state(
		_get_color(_kind),
		fade,
		_get_emission(_kind) * (0.45 + fade * 0.55)
	)
	# The bright core ends quickly; cooling fragments carry the death's tail.
	if _kind in [EffectKind.DEATH, EffectKind.ARMOR_BREAK]:
		core_mesh.visible = progress < 0.24
		burst_mesh.visible = progress < 0.28
	if _local_light_enabled:
		burst_light.light_energy = _get_light_energy(_kind) * _intensity * fade * fade
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
	core_mesh.visible = false
	burst_mesh.visible = false
	pulse_mesh.visible = false
	secondary_ring.visible = false
	streak_mesh.visible = false
	fragments.hide()
	burst_light.visible = false
	burst_light.light_energy = 0.0
	_local_light_enabled = false
	burst_mesh.mesh = _impact_mesh
	streak_mesh.mesh = _streak_mesh
	particles.amount = WARMUP_PARTICLE_AMOUNT
	particles.lifetime = WARMUP_PARTICLE_LIFETIME
	_kind = EffectKind.IMPACT
	_elapsed = 0.0
	_duration = DEFAULT_DURATION
	_intensity = 1.0
	_phase_offset = 0.0
	core_mesh.scale = Vector3.ONE
	burst_mesh.scale = Vector3.ONE
	pulse_mesh.scale = Vector3.ONE
	secondary_ring.scale = Vector3.ONE
	streak_mesh.scale = Vector3.ONE
	scale = Vector3.ONE
	_set_shader_state(Color.TRANSPARENT, 0.0, 0.0)
	ObjectPool.release(self, _idle_parent)
	returned_to_pool.emit(self)


func _get_duration(kind: EffectKind) -> float:
	match kind:
		EffectKind.MUZZLE, EffectKind.HOSTILE_MUZZLE:
			return 0.08
		EffectKind.PROJECTILE:
			return 0.06
		EffectKind.IMPACT:
			return 0.16
		EffectKind.DEATH:
			return 0.68
		EffectKind.ARMOR_BREAK, EffectKind.VOID_COLLAPSE:
			return 0.82
		EffectKind.REFLECT:
			return 0.22
		EffectKind.BOOST:
			return 0.28
		EffectKind.PICKUP:
			return 0.3
		EffectKind.EXPLOSION:
			return 0.52
		EffectKind.SHIELD:
			return 0.4
		EffectKind.TELEGRAPH:
			return 0.55
	return DEFAULT_DURATION


func _get_particle_amount(kind: EffectKind) -> int:
	match kind:
		EffectKind.REFLECT, EffectKind.ARMOR_BREAK:
			return 10
		EffectKind.VOID_COLLAPSE:
			return 4
		EffectKind.MUZZLE:
			return 6
		EffectKind.PROJECTILE:
			return 2
		EffectKind.IMPACT:
			return 8
		EffectKind.DEATH:
			return 18
		EffectKind.BOOST:
			return 14
		EffectKind.PICKUP:
			return 12
		EffectKind.EXPLOSION:
			return WARMUP_PARTICLE_AMOUNT
		EffectKind.SHIELD:
			return 20
		EffectKind.TELEGRAPH:
			return 4
	return 6


func _get_particle_lifetime(kind: EffectKind) -> float:
	match kind:
		EffectKind.REFLECT, EffectKind.HOSTILE_MUZZLE:
			return 0.08
		EffectKind.MUZZLE:
			return 0.08
		EffectKind.PROJECTILE:
			return 0.06
		EffectKind.IMPACT:
			return 0.14
		EffectKind.DEATH:
			return 0.38
		EffectKind.BOOST:
			return 0.24
		EffectKind.PICKUP:
			return 0.28
		EffectKind.EXPLOSION:
			return 0.48
		EffectKind.SHIELD:
			return 0.36
		EffectKind.TELEGRAPH:
			return 0.3
	return DEFAULT_DURATION


func _uses_pulse_mesh(kind: EffectKind) -> bool:
	return kind in [EffectKind.EXPLOSION, EffectKind.SHIELD, EffectKind.TELEGRAPH, EffectKind.VOID_COLLAPSE]


func _uses_secondary_ring(kind: EffectKind) -> bool:
	match kind:
		EffectKind.REFLECT, EffectKind.PICKUP, EffectKind.ARMOR_BREAK:
			return true
		EffectKind.EXPLOSION, EffectKind.SHIELD, EffectKind.TELEGRAPH:
			return true
	return false


func _uses_streak_mesh(kind: EffectKind) -> bool:
	match kind:
		EffectKind.MUZZLE, EffectKind.HOSTILE_MUZZLE, EffectKind.PROJECTILE, EffectKind.BOOST, EffectKind.TELEGRAPH, EffectKind.REFLECT, EffectKind.IMPACT:
			return true
	return false


func _get_color(kind: EffectKind) -> Color:
	match kind:
		EffectKind.MUZZLE, EffectKind.PROJECTILE, EffectKind.BOOST, EffectKind.SHIELD:
			return Palette.CYAN
		EffectKind.IMPACT, EffectKind.DEATH, EffectKind.ARMOR_BREAK, EffectKind.EXPLOSION:
			return Palette.SPARK
		EffectKind.VOID_COLLAPSE:
			return Palette.VIOLET
		EffectKind.REFLECT:
			return Palette.ICE
		EffectKind.HOSTILE_MUZZLE:
			return Palette.HOSTILE
		EffectKind.PICKUP:
			return Palette.GOLD
		EffectKind.TELEGRAPH:
			return Color(1.0, 0.16, 0.04, 1.0)
	return Color.WHITE


func _get_accent(kind: EffectKind) -> Color:
	match kind:
		EffectKind.VOID_COLLAPSE:
			return Color(0.86, 0.68, 1.0)
		EffectKind.DEATH, EffectKind.ARMOR_BREAK:
			return Palette.GOLD
		EffectKind.MUZZLE, EffectKind.PROJECTILE, EffectKind.SHIELD, EffectKind.REFLECT:
			return Color(0.88, 1.0, 1.0, 1.0)
		EffectKind.BOOST:
			return Palette.ICE
		EffectKind.HOSTILE_MUZZLE:
			return Color(1.0, 0.75, 0.95)
		EffectKind.TELEGRAPH, EffectKind.EXPLOSION:
			return Color(1.0, 0.82, 0.24, 1.0)
	return Color(1.0, 0.96, 0.72, 1.0)


func _get_emission(kind: EffectKind) -> float:
	match kind:
		EffectKind.EXPLOSION, EffectKind.SHIELD:
			return 3.2
		EffectKind.DEATH, EffectKind.TELEGRAPH:
			return 2.8
		EffectKind.BOOST:
			return 2.5
	return 2.0


func _get_light_energy(kind: EffectKind) -> float:
	match kind:
		EffectKind.ARMOR_BREAK, EffectKind.VOID_COLLAPSE:
			return 2.0
		EffectKind.REFLECT:
			return 1.1
		EffectKind.EXPLOSION:
			return 3.8
		EffectKind.SHIELD:
			return 2.8
		EffectKind.DEATH:
			return 2.2
		EffectKind.IMPACT, EffectKind.BOOST:
			return 1.4
	return 0.0


func _get_yaw(direction: Vector3) -> float:
	var flat := Vector2(direction.x, direction.z)
	return atan2(-flat.x, -flat.y) if not flat.is_zero_approx() else 0.0


func _set_shader_state(color: Color, alpha: float, emission: float) -> void:
	var accent := _get_accent(_kind)
	_set_effect_shader_state(burst_mesh, color, accent, alpha, emission)
	_set_effect_shader_state(streak_mesh, color, accent, alpha, emission)
	_set_effect_shader_state(pulse_mesh, color, accent, alpha, emission)
	_set_effect_shader_state(secondary_ring, color, accent, alpha, emission)
	core_mesh.set_instance_shader_parameter(&"instance_color", color)
	core_mesh.set_instance_shader_parameter(&"instance_alpha", alpha)
	core_mesh.set_instance_shader_parameter(&"instance_intensity", emission)
	core_mesh.set_instance_shader_parameter(&"instance_phase", _phase_offset + _elapsed * 10.0)
	particles.set_instance_shader_parameter(&"instance_color", color)
	particles.set_instance_shader_parameter(&"instance_alpha", alpha)
	particles.set_instance_shader_parameter(&"instance_intensity", emission * 0.65)
	particles.set_instance_shader_parameter(&"instance_phase", _phase_offset + _elapsed * 10.0)


func _set_effect_shader_state(
	mesh: MeshInstance3D,
	color: Color,
	accent: Color,
	alpha: float,
	emission: float
) -> void:
	mesh.set_instance_shader_parameter(&"instance_color", color)
	mesh.set_instance_shader_parameter(&"instance_accent", accent)
	mesh.set_instance_shader_parameter(&"instance_alpha", alpha)
	mesh.set_instance_shader_parameter(&"instance_emission", emission)
	mesh.set_instance_shader_parameter(&"instance_phase", _phase_offset + _elapsed * 8.0)


func _extract_mesh(scene: PackedScene) -> Mesh:
	var model := scene.instantiate()
	var mesh_node := model.find_child("*", true, false) as MeshInstance3D
	if mesh_node == null:
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		mesh_node = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	var mesh: Mesh = mesh_node.mesh if mesh_node != null else _impact_mesh
	model.free()
	return mesh
