@tool
extends Node2D
class_name EnemyEvolutionController
## Applies a passive generation stage to the unique enemy root.
## Editor preview only swaps authored visual/collision data; it never creates nodes.

const EVOLUTION_SHADER := preload("res://effects/shaders/sprites/enemy_evolution.gdshader")
const SHADER_PROFILES := [
	{
		"energy_color": Color(0.12, 0.72, 1.0, 1.0),
		"accent_color": Color(0.76, 0.95, 1.0, 1.0),
		"outline_strength": 0.55,
		"circuit_amount": 0.05,
		"heat_amount": 0.0,
		"apex_amount": 0.0,
		"emission_strength": 0.12,
	},
	{
		"energy_color": Color(1.0, 0.58, 0.10, 1.0),
		"accent_color": Color(0.28, 1.0, 0.50, 1.0),
		"outline_strength": 0.72,
		"circuit_amount": 0.72,
		"heat_amount": 0.08,
		"apex_amount": 0.0,
		"emission_strength": 0.18,
	},
	{
		"energy_color": Color(1.0, 0.08, 0.05, 1.0),
		"accent_color": Color(1.0, 0.52, 0.05, 1.0),
		"outline_strength": 0.90,
		"circuit_amount": 0.18,
		"heat_amount": 0.90,
		"apex_amount": 0.0,
		"emission_strength": 0.26,
	},
	{
		"energy_color": Color(1.0, 0.04, 0.72, 1.0),
		"accent_color": Color(0.24, 0.92, 1.0, 1.0),
		"outline_strength": 1.05,
		"circuit_amount": 0.45,
		"heat_amount": 0.20,
		"apex_amount": 1.0,
		"emission_strength": 0.34,
	},
]

@export_enum("Gen I — Standard:1", "Gen II — Augmented:2", "Gen III — Warform:3", "Gen IV — Apex:4")
var preview_generation: int = 1:
	set(value):
		preview_generation = clampi(value, 1, 4)
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_apply_editor_preview")

var _evolution_material: ShaderMaterial


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_editor_preview()


func apply_generation(enemy_host: Node, generation: int) -> EnemyEvolutionStage:
	var stage := get_stage(generation)
	if stage == null:
		push_warning("Evolution stage %d is missing from %s" % [generation, get_path()])
		return null
	_apply_stage(enemy_host, stage)
	return stage


func get_stage(generation: int) -> EnemyEvolutionStage:
	for child in get_children():
		var stage := child as EnemyEvolutionStage
		if stage != null and stage.generation == generation:
			return stage
	return null


func get_active_origin(origin_name: StringName) -> Marker2D:
	var stage := get_stage(preview_generation)
	if not Engine.is_editor_hint():
		var enemy_host := get_parent().get_parent()
		if enemy_host != null and "generation" in enemy_host:
			stage = get_stage(int(enemy_host.generation))
	if stage == null:
		return null
	return stage.get_node_or_null(NodePath("Origins/" + String(origin_name))) as Marker2D


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var visual_root := get_parent()
	var enemy_host := visual_root.get_parent() if visual_root != null else null
	var stage := get_stage(preview_generation)
	if enemy_host != null and stage != null:
		_apply_stage(enemy_host, stage)


func _apply_stage(enemy_host: Node, stage: EnemyEvolutionStage) -> void:
	for child in get_children():
		if child is EnemyEvolutionStage:
			(child as EnemyEvolutionStage).visible = child == stage

	var visual_root := get_parent()
	var sprite := visual_root.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = stage.texture
		sprite.hframes = 4
		if "fps" in sprite:
			sprite.fps = stage.animation_fps
		_apply_sprite_shader(sprite, enemy_host, stage.generation)

	var collision := enemy_host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.shape = stage.collision_shape

	if not Engine.is_editor_hint():
		var stats := stage.gameplay_stats
		enemy_host.max_health = stats.max_health if stats != null else stage.max_health
		enemy_host.speed = stats.move_speed if stats != null else stage.move_speed
		enemy_host.points = stats.base_points if stats != null else stage.base_points
		preview_generation = stage.generation


func _apply_sprite_shader(sprite: Sprite2D, enemy_host: Node, generation: int) -> void:
	if _evolution_material == null:
		_evolution_material = ShaderMaterial.new()
		_evolution_material.shader = EVOLUTION_SHADER
		var phase := float(enemy_host.get_instance_id() % 997) / 997.0
		_evolution_material.set_shader_parameter("phase_offset", phase * TAU)

	var profile: Dictionary = SHADER_PROFILES[clampi(generation, 1, 4) - 1]
	_evolution_material.set_shader_parameter("evolution_level", float(generation - 1) / 3.0)
	for parameter_name: String in profile:
		_evolution_material.set_shader_parameter(parameter_name, profile[parameter_name])
	sprite.material = _evolution_material
