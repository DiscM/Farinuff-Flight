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

func _ready() -> void:
	_spawn_planet()

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
