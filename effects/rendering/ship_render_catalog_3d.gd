extends RefCounted
class_name ShipRenderCatalog3D
## Canonical ship-model, palette, and layout definitions for the shared
## gameplay renderer. Keeping these definitions out of the layer makes the
## runtime coordinator easier to navigate without changing its public API.

const MODEL_SCENES := {
	&"player": preload("res://assets/models/redesign/player_butterfly.glb"),
	&"basic": preload("res://assets/models/mockups/basic_enemy_mockup.glb"),
	&"fast": preload("res://assets/models/mockups/fast_enemy_mockup.glb"),
	&"bomber": preload("res://assets/models/mockups/bomber_enemy_mockup.glb"),
	&"tank": preload("res://assets/models/mockups/tank_enemy_mockup.glb"),
	&"sniper": preload("res://assets/models/mockups/sniper_enemy_mockup.glb"),
	&"boss_assault": preload("res://assets/models/mockups/boss_assault_mockup.glb"),
	&"boss_bulwark": preload("res://assets/models/mockups/boss_bulwark_mockup.glb"),
	&"boss_tempest": preload("res://assets/models/mockups/boss_tempest_mockup.glb"),
	&"boss_void_harbinger": preload("res://assets/models/mockups/boss_void_harbinger_mockup.glb"),
	&"boss_tempest_core": preload("res://assets/models/mockups/boss_tempest_core_mockup.glb"),
	&"tempest_section": preload("res://assets/models/mockups/tempest_section_mockup.glb"),
	&"drone_escort": preload("res://assets/models/redesign/butterfly_elites/bf_elite_drone_escort.glb"),
}

const MODEL_PATHS := {
	&"player": "res://assets/models/redesign/player_butterfly.glb",
	&"basic": "res://assets/models/mockups/basic_enemy_mockup.glb",
	&"fast": "res://assets/models/mockups/fast_enemy_mockup.glb",
	&"bomber": "res://assets/models/mockups/bomber_enemy_mockup.glb",
	&"tank": "res://assets/models/mockups/tank_enemy_mockup.glb",
	&"sniper": "res://assets/models/mockups/sniper_enemy_mockup.glb",
	&"boss_assault": "res://assets/models/mockups/boss_assault_mockup.glb",
	&"boss_bulwark": "res://assets/models/mockups/boss_bulwark_mockup.glb",
	&"boss_tempest": "res://assets/models/mockups/boss_tempest_mockup.glb",
	&"boss_void_harbinger": "res://assets/models/mockups/boss_void_harbinger_mockup.glb",
	&"boss_tempest_core": "res://assets/models/mockups/boss_tempest_core_mockup.glb",
	&"tempest_section": "res://assets/models/mockups/tempest_section_mockup.glb",
	&"drone_escort": "res://assets/models/redesign/butterfly_elites/bf_elite_drone_escort.glb",
}

const CLASS_ENERGY := {
	&"player": Color(0.0, 0.78, 1.0),
	&"basic": Color(1.0, 0.231, 0.141),
	&"fast": Color(1.0, 0.541, 0.141),
	&"bomber": Color(0.424, 1.0, 0.478),
	&"tank": Color(0.478, 0.169, 1.0),
	&"sniper": Color(0.157, 0.749, 1.0),
	&"boss_assault": Color(1.0, 0.231, 0.141),
	&"boss_bulwark": Color(0.478, 0.169, 1.0),
	&"boss_tempest": Color(0.08, 0.78, 1.0),
	&"boss_void_harbinger": Color(0.48, 1.0, 0.18),
	&"boss_tempest_core": Color(1.0, 0.58, 0.10),
	&"tempest_section": Color(0.20, 0.92, 1.0),
	&"drone_escort": Color(0.40, 0.85, 1.0),
}

const CLASS_ACCENT := {
	&"player": Color(0.843, 0.933, 1.0),
	&"basic": Color(1.0, 0.757, 0.302),
	&"fast": Color(0.843, 0.933, 1.0),
	&"bomber": Color(0.718, 1.0, 0.29),
	&"tank": Color(1.0, 0.235, 0.812),
	&"sniper": Color(1.0, 0.604, 0.122),
	&"boss_assault": Color(1.0, 0.757, 0.302),
	&"boss_bulwark": Color(1.0, 0.235, 0.812),
	&"boss_tempest": Color(0.72, 0.94, 1.0),
	&"boss_void_harbinger": Color(0.78, 1.0, 0.58),
	&"boss_tempest_core": Color(1.0, 0.86, 0.48),
	&"tempest_section": Color(0.86, 0.98, 1.0),
	&"drone_escort": Color(0.78, 0.96, 1.0),
}

const STATIC_STYLES := {
	&"boss_assault": {
		"evolution_level": 0.72,
		"circuit_amount": 0.28,
		"heat_amount": 0.48,
		"apex_amount": 0.08,
		"emission_strength": 1.05,
		"pattern_scale": 1.35,
	},
	&"boss_bulwark": {
		"evolution_level": 0.76,
		"circuit_amount": 0.42,
		"heat_amount": 0.14,
		"apex_amount": 0.18,
		"emission_strength": 1.10,
		"pattern_scale": 1.25,
	},
	&"boss_tempest": {
		"evolution_level": 0.88,
		"circuit_amount": 0.52,
		"heat_amount": 0.08,
		"apex_amount": 0.42,
		"emission_strength": 1.15,
		"pattern_scale": 1.40,
	},
	&"boss_void_harbinger": {
		"evolution_level": 1.0,
		"circuit_amount": 0.55,
		"heat_amount": 0.24,
		"apex_amount": 0.65,
		"emission_strength": 1.25,
		"pattern_scale": 1.35,
	},
	&"boss_tempest_core": {
		"evolution_level": 1.0,
		"circuit_amount": 0.60,
		"heat_amount": 0.30,
		"apex_amount": 0.58,
		"emission_strength": 1.35,
		"pattern_scale": 1.20,
	},
	&"tempest_section": {
		"evolution_level": 0.84,
		"circuit_amount": 0.40,
		"heat_amount": 0.08,
		"apex_amount": 0.34,
		"emission_strength": 1.15,
		"pattern_scale": 2.20,
	},
	&"drone_escort": {
		"evolution_level": 0.46,
		"circuit_amount": 0.28,
		"heat_amount": 0.0,
		"apex_amount": 0.0,
		"emission_strength": 0.92,
		"pattern_scale": 4.80,
	},
}

const ENGINE_LAYOUTS := {
	# Twin trails ride the butterfly's swallowtail streamer tips.
	&"player": {"x": 1.05, "z": 1.56, "length": 1.30, "half_width": 0.06, "y": 0.0},
	&"basic": {"x": 0.25, "z": 1.17, "length": 0.95},
	&"fast": {"x": 0.15, "z": 1.59, "length": 1.35},
	&"bomber": {"x": 0.33, "z": 1.48, "length": 1.10},
	&"tank": {"x": 0.50, "z": 1.69, "length": 0.95},
	&"sniper": {"x": 0.23, "z": 1.53, "length": 1.18},
	&"boss_assault": {
		"x": 0.817, "z": 3.705, "length": 1.75,
		"half_width": 0.15, "y": -0.09,
	},
	&"boss_bulwark": {
		"x": 1.147, "z": 3.090, "length": 1.45,
		"half_width": 0.17, "y": -0.20,
	},
	&"boss_tempest": {
		"x": 0.748, "z": 2.618, "length": 1.65,
		"half_width": 0.15, "y": -0.15,
	},
	&"boss_void_harbinger": {
		"x": 0.706, "z": 3.377, "length": 1.85,
		"half_width": 0.16, "y": -0.13,
	},
	&"boss_tempest_core": {
		"x": 1.10, "z": 3.982, "length": 1.70,
		"half_width": 0.18, "y": -0.21,
	},
}

const PIXELS_PER_MODEL_UNIT := 11.0
# The ship SubViewport renders at 1/PIXELATION of the composite size and is
# upscaled with NEAREST filtering, giving the 3D fleet the same chunky pixel
# grid as the PixelPlanets background shaders.
const PIXELATION := 2
const CAMERA_HEIGHT := 45.0
const CAMERA_DEPTH := 28.125
const INVINCIBILITY_VISIBLE_ALPHA := 0.5
const RENDER_OVERSCAN_PIXELS := 32
const VOXEL_STYLE_SETTING := "rendering/voxel_style_enabled"
const VOXEL_STYLE_ARG := "--voxel-style"


static func voxel_style_enabled() -> bool:
	# Keep the shipped renderer unchanged by default. The user argument makes
	# the experimental path selectable from headless smoke tests and local
	# captures without requiring an editor-only toggle.
	if OS.get_cmdline_user_args().has(VOXEL_STYLE_ARG):
		return true
	return bool(ProjectSettings.get_setting(VOXEL_STYLE_SETTING, false))


static func instantiate_model(archetype: StringName) -> Node3D:
	if archetype == &"player":
		return PlayerShipAssembly3D.new()
	if not MODEL_SCENES.has(archetype):
		return null
	var packed_scene := MODEL_SCENES[archetype] as PackedScene
	return packed_scene.instantiate() as Node3D


static func get_archetype(source: Node2D) -> StringName:
	if source.is_in_group("player"):
		return &"player"
	if source.is_in_group("drone_escort"):
		return &"drone_escort"
	if source is BossEnemy:
		var boss := source as BossEnemy
		if boss.is_tempest_core:
			return &"boss_tempest_core"
		if boss.is_elite:
			return &"boss_void_harbinger"
		match boss.boss_variant:
			BossEnemy.BossVariant.ASSAULT:
				return &"boss_assault"
			BossEnemy.BossVariant.BULWARK:
				return &"boss_bulwark"
			BossEnemy.BossVariant.TEMPEST:
				return &"boss_tempest"
	if source is TempestSection:
		return &"tempest_section"
	if source is BaseEnemy:
		var enemy := source as BaseEnemy
		if enemy.is_regular_enemy:
			return enemy.archetype_id
	return &""


static func get_source_visual(source: Node2D, archetype: StringName) -> CanvasItem:
	if archetype == &"player":
		return source.get_node_or_null("Sprite2D") as Sprite2D
	if archetype == &"drone_escort":
		return source.get_node_or_null("DroneVisual") as CanvasItem
	if archetype == &"tempest_section":
		return source
	return source.get_node_or_null("VisualRoot/Sprite2D") as Sprite2D


static func get_generation(source: Node2D, archetype: StringName) -> int:
	if archetype == &"player" or STATIC_STYLES.has(archetype):
		return 0
	if source is BaseEnemy:
		return clampi((source as BaseEnemy).generation, 1, 4)
	return 1
