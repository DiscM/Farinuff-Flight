extends Node2D
## Spawns PixelPlanets scenery and scrolls it continuously behind combat.

const BASE_PATH = "res://effects/shaders/PixelPlanets/Planets/"
# Note: BlackHole is intentionally excluded from the random pool — it is
# reserved for boss fights (see effects/boss_black_hole.gd).
const PLANET_SCENES = [
	"Asteroids/Asteroid.tscn",
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
## Canvas pixels per second; independent of player movement and planet scale.
@export var drift_velocity := Vector2(-8.0, 24.0)
@export_range(0.0, 256.0, 1.0, "or_greater") var wrap_padding := 32.0

var current_planet: Control
var _planet_layers: Array[Control] = []

## Spawns a random planet on creation.
func _ready() -> void:
	_spawn_planet()

func _process(delta: float) -> void:
	if not is_instance_valid(current_planet):
		return
	# Freeze the vendored planet's surface clock as well as its travel. Its
	# own time resumes where it stopped, without a catch-up jump after the boss.
	current_planet.set_process(not GameManager.boss_active)
	if GameManager.boss_active or drift_velocity.is_zero_approx():
		return
	global_position += drift_velocity * delta
	var viewport_rect := get_viewport().get_visible_rect().grow(wrap_padding)
	var planet_rect := current_planet.get_global_rect()
	for layer in _planet_layers:
		planet_rect = planet_rect.merge(layer.get_global_rect())
	# Include rings and other oversized layers. Wrap only after the entire
	# visual is offscreen, retaining overshoot so travel is frame-rate independent.
	var origin_offset := global_position - planet_rect.position
	var wrap_start := viewport_rect.position - planet_rect.size + origin_offset
	var wrap_end := viewport_rect.end + origin_offset
	if not is_zero_approx(drift_velocity.x):
		global_position.x = wrapf(global_position.x, wrap_start.x, wrap_end.x)
	if not is_zero_approx(drift_velocity.y):
		global_position.y = wrapf(global_position.y, wrap_start.y, wrap_end.y)

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
	current_planet.set_process(not GameManager.boss_active)
	_make_materials_local(current_planet)
	_planet_layers.assign(current_planet.find_children("*", "Control", true, false))
	
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
