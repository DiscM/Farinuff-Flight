extends Node2D
## Logic for managing randomly generated background planets using PixelPlanets shaders.

const BASE_PATH = "res://effects/shaders/PixelPlanets/Planets/"
const PLANET_SCENES = [
	"Asteroids/Asteroid.tscn",
	"BlackHole/BlackHole.tscn",
	"DryTerran/DryTerran.tscn",
	"Galaxy/Galaxy.tscn",
	"GasPlanet/GasPlanet.tscn",
	"GasPlanetLayers/GasPlanetLayers.tscn",
	"IceWorld/IceWorld.tscn",
	"LandMasses/LandMasses.tscn",
	"LavaWorld/LavaWorld.tscn",
	"NoAtmosphere/NoAtmosphere.tscn",
	"Rivers/Rivers.tscn",
	"Star/Star.tscn"
]

@export var type_index: int = -1 # -1 for random
@export var planet_seed: int = -1 # -1 for random

var current_planet: Control

## Spawns a random planet on creation.
func _ready() -> void:
	_spawn_planet()

## Loads and instantiates a PixelPlanets scene (random type if type_index < 0),
## duplicates its materials to prevent shared-material palette overwrites,
## randomizes the seed and colors, centers it on this node's local origin,
## and sets a random rotation speed.
func _spawn_planet() -> void:
	if current_planet:
		current_planet.queue_free()
	
	var idx = type_index
	if idx < 0 or idx >= PLANET_SCENES.size():
		idx = randi() % PLANET_SCENES.size()
	
	var scene_path = BASE_PATH + PLANET_SCENES[idx]
	var scene = load(scene_path)
	if not scene:
		push_error("Failed to load planet scene: " + scene_path)
		return
		
	current_planet = scene.instantiate()
	add_child(current_planet)
	_make_materials_local(current_planet)
	
	# Randomize
	if planet_seed < 0:
		current_planet.set_seed(randi() % 1000)
	else:
		current_planet.set_seed(int(planet_seed))
		
	current_planet.randomize_colors()
	
	# Center the planet
	# PixelPlanets nodes use Control anchors, but we want to treat it as a sprite
	# Most are ~100-200px. We'll set the pivot to center.
	current_planet.set_anchors_preset(Control.PRESET_CENTER)
	current_planet.position = Vector2.ZERO # Local zero is where we placed the spawner
	
	# Random rotation speed if supported
	current_planet.set_rotates(randf_range(0.01, 0.05))

## PixelPlanets scenes share materials by default; local copies prevent later spawns
## from overwriting palettes and shader seeds on planets already on screen.
## Recursively duplicates materials on all CanvasItem descendants.
func _make_materials_local(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		if canvas_item.material:
			canvas_item.material = canvas_item.material.duplicate(true)
	for child in node.get_children():
		_make_materials_local(child)
