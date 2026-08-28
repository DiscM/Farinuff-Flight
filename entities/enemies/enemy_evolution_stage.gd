@tool
extends Node2D
class_name EnemyEvolutionStage
## Passive, Inspector-editable configuration for one enemy generation.

const GenerationStats := preload("res://entities/enemies/enemy_generation_stats.gd")

@export_range(1, 4, 1) var generation: int = 1
@export var display_name: String = "Standard"
@export var texture: Texture2D
@export var collision_shape: Shape2D
## Migrated stages use shared balance; unported stages retain their authored fields.
@export var gameplay_stats: GenerationStats
@export var max_health: int = 1
@export var move_speed: float = 150.0
@export var base_points: int = 100
@export var animation_fps: float = 8.0
