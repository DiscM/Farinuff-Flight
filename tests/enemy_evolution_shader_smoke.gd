extends Node
## Regression coverage for the shared generation-aware enemy sprite shader.
##
## Run with:
## godot --headless --path . res://tests/enemy_evolution_shader_smoke.tscn

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://entities/enemies/basic_enemy.tscn"),
	preload("res://entities/enemies/fast_enemy.tscn"),
	preload("res://entities/enemies/tank_enemy.tscn"),
	preload("res://entities/enemies/bomber_enemy.tscn"),
	preload("res://entities/enemies/sniper_enemy.tscn"),
]
const SHADER_PATH := "res://effects/shaders/sprites/enemy_evolution.gdshader"
const EXPECTED_CIRCUIT_AMOUNTS := [0.05, 0.72, 0.18, 0.45]
const EXPECTED_HEAT_AMOUNTS := [0.0, 0.08, 0.90, 0.20]
const EXPECTED_APEX_AMOUNTS := [0.0, 0.0, 0.0, 1.0]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemies: Array[Node] = []
	var material_ids: Dictionary = {}

	for archetype_index in range(ENEMY_SCENES.size()):
		for generation in range(1, 5):
			var enemy := ENEMY_SCENES[archetype_index].instantiate()
			enemy.generation = generation
			enemy.spawn_direction = Vector2.UP
			enemy.position = Vector2(
				36.0 + float(archetype_index) * 72.0,
				90.0 + float(generation - 1) * 160.0
			)
			enemy.scale = Vector2.ONE * 1.4
			enemy.set_physics_process(false)
			add_child(enemy)
			enemies.append(enemy)

	await get_tree().process_frame
	await get_tree().process_frame

	for enemy in enemies:
		var sprite := enemy.get_node("VisualRoot/Sprite2D") as Sprite2D
		var controller := enemy.get_node("VisualRoot/Evolution") as EnemyEvolutionController
		var stage := controller.get_stage(enemy.generation)
		var material := sprite.material as ShaderMaterial
		var label := "%s Gen %d" % [enemy.name, enemy.generation]

		_expect(material != null, "%s must receive a ShaderMaterial" % label)
		if material == null:
			continue
		_expect(material.shader.resource_path == SHADER_PATH, "%s uses the wrong shader" % label)
		_expect(sprite.texture == stage.texture, "%s must retain its authored stage texture" % label)
		_expect(sprite.hframes == 4, "%s must retain its four-frame animation strip" % label)
		_expect(
			is_equal_approx(
				float(material.get_shader_parameter("evolution_level")),
				float(enemy.generation - 1) / 3.0
			),
			"%s has the wrong evolution level" % label
		)
		_expect_profile_amount(material, "circuit_amount", EXPECTED_CIRCUIT_AMOUNTS, enemy.generation, label)
		_expect_profile_amount(material, "heat_amount", EXPECTED_HEAT_AMOUNTS, enemy.generation, label)
		_expect_profile_amount(material, "apex_amount", EXPECTED_APEX_AMOUNTS, enemy.generation, label)

		var material_id := material.get_instance_id()
		_expect(not material_ids.has(material_id), "%s shares mutable material state with another enemy" % label)
		material_ids[material_id] = true

	var transition_enemy := enemies[0]
	var transition_sprite := transition_enemy.get_node("VisualRoot/Sprite2D") as Sprite2D
	var transition_controller := (
		transition_enemy.get_node("VisualRoot/Evolution") as EnemyEvolutionController
	)
	var original_material := transition_sprite.material
	var apex_stage := transition_controller.apply_generation(transition_enemy, 4)
	_expect(transition_sprite.material == original_material, "Generation changes must reuse the enemy material")
	_expect(transition_sprite.texture == apex_stage.texture, "Generation changes must swap the stage texture")
	_expect(
		is_equal_approx(
			float((transition_sprite.material as ShaderMaterial).get_shader_parameter("apex_amount")),
			1.0
		),
		"Generation changes must refresh shader parameters"
	)

	for enemy in enemies:
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	if _failures.is_empty():
		print("PASS: enemy evolution shader smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _expect_profile_amount(
	material: ShaderMaterial,
	parameter_name: String,
	expected_values: Array,
	generation: int,
	label: String
) -> void:
	_expect(
		is_equal_approx(
			float(material.get_shader_parameter(parameter_name)),
			float(expected_values[generation - 1])
		),
		"%s has the wrong %s" % [label, parameter_name]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
