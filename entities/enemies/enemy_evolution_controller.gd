@tool
extends Node2D
class_name EnemyEvolutionController
## Applies a passive generation stage to the unique enemy root.
## Editor preview only swaps authored visual/collision data; it never creates nodes.

@export_enum("Gen I — Standard:1", "Gen II — Augmented:2", "Gen III — Warform:3", "Gen IV — Apex:4")
var preview_generation: int = 1:
	set(value):
		preview_generation = clampi(value, 1, 4)
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_apply_editor_preview")


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

	var collision := enemy_host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.shape = stage.collision_shape

	if not Engine.is_editor_hint():
		enemy_host.max_health = stage.max_health
		enemy_host.speed = stage.move_speed
		enemy_host.points = stage.base_points
		preview_generation = stage.generation

