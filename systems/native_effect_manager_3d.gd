extends Node
class_name NativeEffectManager3D
## Scene-owned bounded pool for repeated native 3D feedback.

const Effect := preload("res://effects/native_effect_3d.gd")
const EFFECT_SCENE := preload("res://effects/native_effect_3d.tscn")

@export_range(1, 128, 1) var pool_size: int = 96
@export_range(1, 16, 1) var warm_batch_size: int = 8
@export_range(0, 16, 1) var max_local_lights: int = 8

var is_ready := false
var _warming := false
var _active_parent: Node3D
var _idle_parent: Node3D
var _checked_out: Array[Effect] = []
var _warmed_ids: Dictionary[int, bool] = {}
var _pool_growth := 0
var _rejected := 0
var _played := 0
var _lit_effects: Dictionary[int, bool] = {}


func configure(active_parent: Node3D, idle_parent: Node3D) -> void:
	if _active_parent == active_parent and _idle_parent == idle_parent:
		return
	if not _checked_out.is_empty():
		clear_effects()
	_active_parent = active_parent
	_idle_parent = idle_parent


func warm_effect_pool() -> bool:
	if is_ready:
		return true
	if _warming or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var warm_nodes: Array[Effect] = []
	for index in range(pool_size):
		var effect := ObjectPool.acquire(EFFECT_SCENE, _active_parent) as Effect
		if effect == null:
			_warming = false
			return false
		effect.configure_pool(_idle_parent)
		if not effect.returned_to_pool.is_connected(_on_effect_returned):
			effect.returned_to_pool.connect(_on_effect_returned)
		effect.prepare_visual_warmup()
		warm_nodes.append(effect)
		_checked_out.append(effect)
		_warmed_ids[effect.get_instance_id()] = true
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	for index in range(warm_nodes.size()):
		warm_nodes[index].despawn()
		if (index + 1) % warm_batch_size == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	_warming = false
	is_ready = true
	return true


func play_effect(
	kind: Effect.EffectKind,
	effect_position: Vector3,
	direction: Vector3 = Vector3.FORWARD,
	intensity: float = 1.0,
	preserve_height: bool = false
) -> bool:
	if not is_ready or _checked_out.size() >= _warmed_ids.size():
		_rejected += 1
		return false
	var effect := ObjectPool.acquire(EFFECT_SCENE, _active_parent) as Effect
	if effect == null:
		_rejected += 1
		return false
	if not _warmed_ids.has(effect.get_instance_id()):
		_pool_growth += 1
		_warmed_ids[effect.get_instance_id()] = true
	effect.configure_pool(_idle_parent)
	if not effect.returned_to_pool.is_connected(_on_effect_returned):
		effect.returned_to_pool.connect(_on_effect_returned)
	_checked_out.append(effect)
	var emit_local_light := _can_claim_local_light(kind)
	if emit_local_light:
		_lit_effects[effect.get_instance_id()] = true
	if not effect.play(kind, effect_position, direction, intensity, preserve_height, emit_local_light):
		_checked_out.erase(effect)
		_lit_effects.erase(effect.get_instance_id())
		ObjectPool.release(effect, _idle_parent)
		_rejected += 1
		return false
	_played += 1
	return true


func clear_effects() -> void:
	for effect in _checked_out.duplicate():
		if is_instance_valid(effect):
			effect.despawn()
	_lit_effects.clear()


func get_metrics() -> Dictionary:
	var active := 0
	for effect in _checked_out:
		if effect.is_active:
			active += 1
	return {
		"pool_size": _warmed_ids.size(),
		"active": active,
		"returning": _checked_out.size() - active,
		"idle": _warmed_ids.size() - _checked_out.size(),
		"played": _played,
		"rejected": _rejected,
		"pool_growth_after_warmup": _pool_growth,
		"local_lights_active": _lit_effects.size(),
		"local_lights_capacity": max_local_lights,
	}


func _on_effect_returned(effect: Effect) -> void:
	_checked_out.erase(effect)
	_lit_effects.erase(effect.get_instance_id())


func _can_claim_local_light(kind: Effect.EffectKind) -> bool:
	if max_local_lights <= 0 or _lit_effects.size() >= max_local_lights:
		return false
	match kind:
		Effect.EffectKind.IMPACT, Effect.EffectKind.DEATH, Effect.EffectKind.BOOST:
			return true
		Effect.EffectKind.EXPLOSION, Effect.EffectKind.SHIELD:
			return true
	return false
