extends RefCounted
class_name ShipVisualSynchronizer3D
## Copies authoritative 2D ship state onto one 3D proxy each render frame.

const Catalog := preload("res://effects/rendering/ship_render_catalog_3d.gd")
const MaterialLibrary := preload(
	"res://effects/rendering/ship_render_material_library_3d.gd"
)
const VisualProxy := preload(
	"res://effects/rendering/ship_visual_proxy_3d.gd"
)


func sync_proxy(
	proxy: VisualProxy,
	source: Node2D,
	screen_to_world: Callable,
	materials: MaterialLibrary
) -> void:
	var current_generation := Catalog.get_generation(source, proxy.archetype)
	if current_generation != proxy.generation:
		proxy.generation = current_generation
		materials.apply_proxy_materials(proxy)

	var center: Vector3 = screen_to_world.call(source.global_position)
	proxy.root.position = center
	var forward_2d := Vector2.UP.rotated(source.global_rotation)
	var forward_world_point: Vector3 = screen_to_world.call(
		source.global_position + forward_2d * 24.0
	)
	var forward_3d := forward_world_point - center
	forward_3d.y = 0.0
	if not forward_3d.is_zero_approx():
		proxy.root.look_at(center + forward_3d.normalized(), Vector3.UP)

	var source_scale := source.global_scale
	var visual_scale := Vector2.ONE
	var visual_root_2d := source.get_node_or_null("VisualRoot") as Node2D
	if visual_root_2d != null:
		visual_scale = visual_root_2d.scale
	if source is TempestSection:
		var section := source as TempestSection
		visual_scale = Vector2(
			section.section_size.x / 27.0,
			section.section_size.y / 48.0
		)
	var generation_scale := (
		1.0
		if (
			proxy.archetype == &"player"
			or Catalog.STATIC_STYLES.has(proxy.archetype)
		)
		else 1.0 + float(proxy.generation - 1) * 0.055
	)
	var x_scale := absf(source_scale.x * visual_scale.x) * generation_scale
	var z_scale := absf(source_scale.y * visual_scale.y) * generation_scale
	proxy.root.scale = Vector3(x_scale, (x_scale + z_scale) * 0.5, z_scale)

	var source_feedback := source.modulate
	var flash := clampf(
		(
			minf(
				source_feedback.r,
				minf(source_feedback.g, source_feedback.b)
			) - 1.0
		) / 2.0,
		0.0,
		1.0
	)
	var combined_modulate := source_feedback
	if is_instance_valid(proxy.source_visual) and proxy.source_visual != source:
		var visual_feedback: Color = proxy.source_visual.modulate
		combined_modulate *= visual_feedback
		flash = maxf(
			flash,
			clampf(
				(
					minf(
						visual_feedback.r,
						minf(visual_feedback.g, visual_feedback.b)
					) - 1.0
				) / 2.0,
				0.0,
				1.0
			)
		)
	var energy_override := Color(0.0, 0.0, 0.0, 0.0)
	var accent_override := Color(0.0, 0.0, 0.0, 0.0)
	var outline_override := Color(0.0, 0.0, 0.0, 0.0)
	if source is TempestSection:
		var section := source as TempestSection
		var health_ratio := maxf(
			float(section.health) / float(section.max_health),
			0.0
		)
		var section_tint := section.section_color.darkened(
			0.06 + (1.0 - health_ratio) * 0.22
		)
		var body_tint := section_tint.lightened(0.30)
		combined_modulate *= Color(
			body_tint.r,
			body_tint.g,
			body_tint.b,
			1.0
		)
		energy_override = Color(
			section.section_color.r,
			section.section_color.g,
			section.section_color.b,
			1.0
		)
		var bright_accent := section.section_color.lightened(0.48)
		accent_override = Color(
			bright_accent.r,
			bright_accent.g,
			bright_accent.b,
			1.0
		)
		outline_override = energy_override
	var instance_tint := Color(
		clampf(combined_modulate.r, 0.0, 1.5),
		clampf(combined_modulate.g, 0.0, 1.5),
		clampf(combined_modulate.b, 0.0, 1.5),
		1.0
	)
	var visible_alpha := combined_modulate.a
	proxy.root.visible = (
		source.is_visible_in_tree()
		and proxy.source_visual.visible
		and visible_alpha >= Catalog.INVINCIBILITY_VISIBLE_ALPHA
	)
	if proxy.player_assembly != null:
		var upgrade_ids: Array[String] = source.call(
			&"get_active_elite_upgrade_ids"
		)
		proxy.player_assembly.set_active_upgrades(upgrade_ids)
		proxy.player_assembly.set_feedback(
			instance_tint,
			flash,
			proxy.phase_offset
		)
	else:
		for mesh_variant in proxy.meshes:
			var mesh_instance := mesh_variant as MeshInstance3D
			mesh_instance.set_instance_shader_parameter(
				"instance_modulate",
				instance_tint
			)
			mesh_instance.set_instance_shader_parameter("instance_flash", flash)
			mesh_instance.set_instance_shader_parameter(
				"instance_phase_offset",
				proxy.phase_offset
			)
			mesh_instance.set_instance_shader_parameter(
				"instance_energy_override",
				energy_override
			)
			mesh_instance.set_instance_shader_parameter(
				"instance_accent_override",
				accent_override
			)
		for outline_variant in proxy.outlines:
			var outline := outline_variant as MeshInstance3D
			if not is_instance_valid(outline):
				continue
			outline.set_instance_shader_parameter(
				"instance_modulate",
				instance_tint
			)
			outline.set_instance_shader_parameter("instance_flash", flash)
			outline.set_instance_shader_parameter(
				"instance_outline_override",
				outline_override
			)
		if is_instance_valid(proxy.evolution_aura):
			proxy.evolution_aura.set_instance_shader_parameter(
				"instance_modulate",
				instance_tint
			)
			proxy.evolution_aura.set_instance_shader_parameter(
				"instance_flash",
				flash
			)
			proxy.evolution_aura.set_instance_shader_parameter(
				"instance_phase_offset",
				proxy.phase_offset
			)
			proxy.evolution_aura.set_instance_shader_parameter(
				"instance_energy_override",
				energy_override
			)
			proxy.evolution_aura.set_instance_shader_parameter(
				"instance_accent_override",
				accent_override
			)
	if is_instance_valid(proxy.engine_trail):
		proxy.engine_trail.set_instance_shader_parameter(
			"instance_phase_offset",
			proxy.phase_offset
		)
