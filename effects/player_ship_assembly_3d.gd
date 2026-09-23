extends Node3D
class_name PlayerShipAssembly3D
## Reusable low-poly player hull plus every ship-mounted elite upgrade.
##
## Upgrade models are authored in the base hull's local coordinate system, so
## enabling one is an immediate visibility change. No animation-frame offsets,
## transform interpolation, or attachment tweens are involved.

const OUTLINE_SHADER: Shader = preload("res://effects/shaders/models/pixel_outline_3d.gdshader")
const INTERCEPTOR_SCENE := preload("res://assets/models/redesign/player_butterfly_morpho.glb")
const BULWARK_SCENE := preload("res://assets/models/redesign/player_butterfly_monarch.glb")
const HULL_SCENE: PackedScene = preload("res://assets/models/redesign/player_butterfly.glb")
const DRONE_SCENE: PackedScene = preload("res://assets/models/redesign/butterfly_elites/bf_elite_drone_escort.glb")

const ATTACHED_IDS: Array[String] = [
	"twin_cannons",
	"auto_aim",
	"hull_plating",
	"afterburner",
	"spread_shot_elite",
	"shield_burst",
	"magnet_field",
	"overclock",
	"rear_gunner",
	"orbitals", "piercing", "explosive_rounds",
]

const MODULE_SCENES := {
	"orbitals": preload("res://assets/models/native/upgrade_orbitals.glb"),
	"piercing": preload("res://assets/models/native/upgrade_piercing.glb"),
	"explosive_rounds": preload("res://assets/models/native/upgrade_explosive.glb"),

	"twin_cannons": preload("res://assets/models/redesign/butterfly_elites/bf_elite_twin_cannons.glb"),
	"auto_aim": preload("res://assets/models/redesign/butterfly_elites/bf_elite_auto_aim.glb"),
	"hull_plating": preload("res://assets/models/redesign/butterfly_elites/bf_elite_hull_plating.glb"),
	"afterburner": preload("res://assets/models/redesign/butterfly_elites/bf_elite_afterburner.glb"),
	"spread_shot_elite": preload("res://assets/models/redesign/butterfly_elites/bf_elite_spread_shot.glb"),
	"shield_burst": preload("res://assets/models/redesign/butterfly_elites/bf_elite_shield_burst.glb"),
	"magnet_field": preload("res://assets/models/redesign/butterfly_elites/bf_elite_magnet_field.glb"),
	"overclock": preload("res://assets/models/redesign/butterfly_elites/bf_elite_overclock.glb"),
	"rear_gunner": preload("res://assets/models/redesign/butterfly_elites/bf_elite_rear_gunner.glb"),
}

const MODULE_PATHS := {
	"orbitals": "res://assets/models/native/upgrade_orbitals.glb",
	"piercing": "res://assets/models/native/upgrade_piercing.glb",
	"explosive_rounds": "res://assets/models/native/upgrade_explosive.glb",

	"twin_cannons": "res://assets/models/redesign/butterfly_elites/bf_elite_twin_cannons.glb",
	"auto_aim": "res://assets/models/redesign/butterfly_elites/bf_elite_auto_aim.glb",
	"hull_plating": "res://assets/models/redesign/butterfly_elites/bf_elite_hull_plating.glb",
	"afterburner": "res://assets/models/redesign/butterfly_elites/bf_elite_afterburner.glb",
	"spread_shot_elite": "res://assets/models/redesign/butterfly_elites/bf_elite_spread_shot.glb",
	"shield_burst": "res://assets/models/redesign/butterfly_elites/bf_elite_shield_burst.glb",
	"magnet_field": "res://assets/models/redesign/butterfly_elites/bf_elite_magnet_field.glb",
	"overclock": "res://assets/models/redesign/butterfly_elites/bf_elite_overclock.glb",
	"rear_gunner": "res://assets/models/redesign/butterfly_elites/bf_elite_rear_gunner.glb",
}

const UPGRADE_COLORS := {
	"orbitals": Color(0.3, 0.9, 1.0),
	"piercing": Color(0.3, 0.9, 1.0),
	"explosive_rounds": Color(0.3, 0.9, 1.0),

	"twin_cannons": Color(1.0, 0.8, 0.2),
	"auto_aim": Color(0.3, 1.0, 0.5),
	"drone_escort": Color(0.4, 0.85, 1.0),
	"hull_plating": Color(0.8, 0.55, 1.0),
	"afterburner": Color(1.0, 0.45, 0.15),
	"spread_shot_elite": Color(1.0, 0.55, 0.9),
	"shield_burst": Color(0.3, 0.8, 1.0),
	"magnet_field": Color(1.0, 0.75, 0.1),
	"overclock": Color(0.9, 1.0, 0.2),
	"rear_gunner": Color(1.0, 0.35, 0.35),
}

const HULL_ENERGY := Color(0.02, 0.72, 1.0)
const HULL_ACCENT := Color(0.76, 0.95, 1.0)
const DRONE_PREVIEW_OFFSET := Vector3(2.62, 0.05, -0.42)

var hull_model: Node3D
var hull_meshes: Array[MeshInstance3D] = []
var hull_outlines: Array[MeshInstance3D] = []
var module_roots: Dictionary = {}
var module_meshes: Dictionary = {}
var module_outlines: Dictionary = {}
var drone_preview_root: Node3D
var drone_preview_meshes: Array[MeshInstance3D] = []
var drone_preview_outlines: Array[MeshInstance3D] = []

var _built := false
var _active_upgrades: Array[String] = []
var _highlight_id := ""
var _dim_existing := false
var _show_preview_drone := false
var _runtime_modulate := Color.WHITE
var _runtime_flash := 0.0
var _phase_offset := 0.0


func build() -> void:
	if _built:
		return
	_built = true

	var hull_scene: PackedScene = INTERCEPTOR_SCENE if MetaProgression.selected_ship == "ship_interceptor" else BULWARK_SCENE if MetaProgression.selected_ship == "ship_bulwark" else HULL_SCENE
	hull_model = hull_scene.instantiate() as Node3D
	hull_model.name = "PlayerHullGLB"
	add_child(hull_model)
	_style_model(
		hull_model,
		&"player",
		HULL_ENERGY,
		HULL_ACCENT,
		true,
		hull_meshes,
		hull_outlines
	)

	for id in ATTACHED_IDS:
		var scene := MODULE_SCENES[id] as PackedScene
		var module_root := scene.instantiate() as Node3D
		module_root.name = "Upgrade_%s" % id
		module_root.visible = false
		add_child(module_root)
		var meshes: Array[MeshInstance3D] = []
		var outlines: Array[MeshInstance3D] = []
		var energy := UPGRADE_COLORS[id] as Color
		_style_model(
			module_root,
			StringName(id),
			energy,
			energy.lightened(0.38),
			false,
			meshes,
			outlines
		)
		module_roots[id] = module_root
		module_meshes[id] = meshes
		module_outlines[id] = outlines

	drone_preview_root = DRONE_SCENE.instantiate() as Node3D
	drone_preview_root.name = "DroneEscortPreviewGLB"
	drone_preview_root.position = DRONE_PREVIEW_OFFSET
	drone_preview_root.visible = false
	add_child(drone_preview_root)
	var drone_energy := UPGRADE_COLORS["drone_escort"] as Color
	_style_model(
		drone_preview_root,
		&"drone_escort",
		drone_energy,
		drone_energy.lightened(0.38),
		false,
		drone_preview_meshes,
		drone_preview_outlines
	)
	_apply_visibility_and_instance_state()


func set_active_upgrades(
	upgrade_ids: Array[String],
	highlight_id: String = "",
	dim_existing: bool = false,
	show_preview_drone: bool = false
) -> void:
	build()
	var normalized_upgrades: Array[String] = []
	for id in upgrade_ids:
		if not normalized_upgrades.has(id):
			normalized_upgrades.append(id)
	if (
		normalized_upgrades == _active_upgrades
		and highlight_id == _highlight_id
		and dim_existing == _dim_existing
		and show_preview_drone == _show_preview_drone
	):
		return
	_active_upgrades.assign(normalized_upgrades)
	_highlight_id = highlight_id
	_dim_existing = dim_existing
	_show_preview_drone = show_preview_drone
	_apply_visibility_and_instance_state()


func _style_model(
	model_root: Node3D,
	style_id: StringName,
	energy_color: Color,
	accent_color: Color,
	animate_shader: bool,
	mesh_output: Array[MeshInstance3D],
	outline_output: Array[MeshInstance3D]
) -> void:
	_collect_meshes(model_root, mesh_output)
	for mesh_index in range(mesh_output.size()):
		var mesh_instance := mesh_output[mesh_index]
		if mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			var material := _make_surface_material(
				style_id,
				energy_color,
				accent_color,
				animate_shader,
				source_material
			)
			mesh_instance.set_surface_override_material(surface_index, material)

		var outline := MeshInstance3D.new()
		outline.name = "%s_NeonOutline" % mesh_instance.name
		outline.mesh = mesh_instance.mesh
		outline.transform = mesh_instance.transform
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline.material_override = _make_outline_material(
			energy_color,
			animate_shader
		)
		mesh_instance.get_parent().add_child(outline)
		outline_output.append(outline)


func _make_surface_material(
	_style_id: StringName,
	_energy_color: Color,
	_accent_color: Color,
	_animate_shader: bool,
	source_material: Material
) -> ShaderMaterial:
	return preload("res://effects/rendering/frontier_ship_materials.gd").surface(source_material)


func _make_outline_material(_energy_color: Color, _animate_shader: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_width", 0.018)
	material.set_shader_parameter("outline_color", Color(0.08, 0.25, 0.32))
	return material


func _apply_visibility_and_instance_state() -> void:
	if not _built:
		return
	_apply_mesh_feedback(hull_meshes, hull_outlines, Color.WHITE)
	for id in ATTACHED_IDS:
		var root := module_roots[id] as Node3D
		root.visible = _active_upgrades.has(id)
		var presentation_tint := _get_presentation_tint(id)
		var meshes: Array[MeshInstance3D] = module_meshes[id]
		var outlines: Array[MeshInstance3D] = module_outlines[id]
		_apply_mesh_feedback(meshes, outlines, presentation_tint)

	var show_drone := _show_preview_drone and _active_upgrades.has("drone_escort")
	drone_preview_root.visible = show_drone
	if show_drone:
		_apply_mesh_feedback(
			drone_preview_meshes,
			drone_preview_outlines,
			_get_presentation_tint("drone_escort")
		)


func _get_presentation_tint(upgrade_id: String) -> Color:
	if _highlight_id != "" and upgrade_id == _highlight_id:
		return Color(1.18, 1.18, 1.18, 1.0)
	if _dim_existing and _highlight_id != "":
		return Color(0.30, 0.32, 0.38, 1.0)
	return Color.WHITE


func _apply_mesh_feedback(
	meshes: Array[MeshInstance3D],
	outlines: Array[MeshInstance3D],
	presentation_tint: Color
) -> void:
	var tint := Color(
		_runtime_modulate.r * presentation_tint.r,
		_runtime_modulate.g * presentation_tint.g,
		_runtime_modulate.b * presentation_tint.b,
		1.0
	)
	for mesh_instance in meshes:
		mesh_instance.set_instance_shader_parameter("instance_modulate", tint)
		mesh_instance.set_instance_shader_parameter("instance_flash", _runtime_flash)
		mesh_instance.set_instance_shader_parameter("instance_phase_offset", _phase_offset)
	for outline in outlines:
		outline.set_instance_shader_parameter("instance_modulate", tint)
		outline.set_instance_shader_parameter("instance_flash", _runtime_flash)


func _collect_meshes(root: Node, output: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D and not root.name.ends_with("_NeonOutline"):
		output.append(root as MeshInstance3D)
	for child in root.get_children():
		_collect_meshes(child, output)
