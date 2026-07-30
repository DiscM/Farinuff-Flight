extends Node2D
## Looping art-review scene for the in-house combat VFX.
##
## Run with:
## godot --path . res://tests/combat_vfx_preview.tscn

const EXPLOSION_SCENE := preload("res://effects/explosion.tscn")
const FEEDBACK_SCENE := preload("res://effects/pixel_sprite_effect.tscn")
const REPLAY_INTERVAL := 1.15

var _replay_timer := 0.0


func _ready() -> void:
	call_deferred("_play_showcase")


func _process(delta: float) -> void:
	_replay_timer -= delta
	if _replay_timer <= 0.0:
		_play_showcase()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.004, 0.008, 0.035))

	for y in range(40, int(viewport_size.y), 40):
		draw_line(
			Vector2(0.0, float(y)),
			Vector2(viewport_size.x, float(y)),
			Color(0.08, 0.24, 0.38, 0.16),
			1.0
		)
	for x in range(40, int(viewport_size.x), 40):
		draw_line(
			Vector2(float(x), 0.0),
			Vector2(float(x), viewport_size.y),
			Color(0.08, 0.24, 0.38, 0.16),
			1.0
		)


func _play_showcase() -> void:
	_replay_timer = REPLAY_INTERVAL
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x * 0.5

	var large_explosion := ObjectPool.acquire(EXPLOSION_SCENE, self)
	large_explosion.play_at(Vector2(center_x - 78.0, 165.0), false)

	var small_explosion := ObjectPool.acquire(EXPLOSION_SCENE, self)
	small_explosion.play_at(Vector2(center_x + 78.0, 165.0), true)

	var impact := ObjectPool.acquire(EXPLOSION_SCENE, self)
	impact.play_impact_at(Vector2(center_x, 315.0))

	var warp := ObjectPool.acquire(FEEDBACK_SCENE, self)
	warp.play_warp_at(Vector2(center_x - 78.0, 500.0), Vector2.UP)

	var sparkle := ObjectPool.acquire(FEEDBACK_SCENE, self)
	sparkle.play_sparkle_at(Vector2(center_x + 78.0, 500.0))
