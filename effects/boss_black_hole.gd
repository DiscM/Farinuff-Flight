extends Node2D
## Boss-fight set piece — a black hole that phases in when a boss spawns,
## slowly grows for the duration of the fight (capped at a fraction of the
## screen), then shrinks away and frees itself when the boss dies.
## Created by scenes/game.gd in response to SignalBus.boss_spawned.

const BLACK_HOLE_SCENE := preload("res://effects/shaders/PixelPlanets/Planets/BlackHole/BlackHole.tscn")
const DISK_DIAMETER := 300.0             # BlackHole scene's full disk extent at scale 1
const HOLE_CENTER := Vector2(50.0, 50.0) # Visual center of the hole in the scene's local space

@export var max_screen_fraction := 0.9   # Cap: share of viewport width at full growth
@export var start_screen_fraction := 0.18
@export var phase_in_time := 3.0
@export var phase_out_time := 2.0
@export var grow_duration := 50.0        # Seconds of boss fight needed to reach the cap

var _hole: Control = null
var _growth := 0.0
var _phasing_out := false
var _start_scale := 1.0
var _max_scale := 1.0

## Centers on the screen, instantiates the BlackHole planet with local
## materials, and starts the phase-in fade. Connects boss_died so the hole
## phases out as soon as the fight ends.
func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = vp * 0.5
	_start_scale = (vp.x * start_screen_fraction) / DISK_DIAMETER
	_max_scale = (vp.x * max_screen_fraction) / DISK_DIAMETER

	_hole = BLACK_HOLE_SCENE.instantiate()
	_hole.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hole.position = -HOLE_CENTER # Center the hole on this node's origin
	add_child(_hole)
	_make_materials_local(_hole)
	_hole.set_seed(randi() % 1000)
	_hole.set_rotates(randf_range(0.1, 0.4))

	scale = Vector2.ONE * _start_scale
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, phase_in_time).set_ease(Tween.EASE_IN)
	SignalBus.boss_died.connect(_on_boss_died)

## Grows the hole slowly and linearly for the fight's duration, clamped at
## the max-size cap.
func _process(delta: float) -> void:
	if _phasing_out:
		return
	_growth = minf(_growth + delta / grow_duration, 1.0)
	scale = Vector2.ONE * lerpf(_start_scale, _max_scale, _growth)

## On boss death: fade and shrink the hole away, then free this node.
func _on_boss_died(_points: int) -> void:
	if _phasing_out:
		return
	_phasing_out = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, phase_out_time).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", scale * 0.4, phase_out_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

## PixelPlanets scenes share materials by default; local copies keep this
## hole's palette and shader seed independent of any other planet instance.
func _make_materials_local(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		if canvas_item.material:
			canvas_item.material = canvas_item.material.duplicate(true)
	for child in node.get_children():
		_make_materials_local(child)
