extends Node
class_name NativeEffectManager3D
## Scene-owned bounded pool for repeated native 3D feedback.

const Effect := preload("res://effects/native_effect_3d.gd")
const EFFECT_SCENE := preload("res://effects/native_effect_3d.tscn")
const FrameWorkBudget := preload("res://systems/frame_work_budget.gd")

@export_range(1, 128, 1) var pool_size: int = 96
## Retained for saved-scene compatibility. Warm-up now yields from an elapsed
## work budget so a slow effect instance cannot force a long fixed-frame stall.
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
	is_ready = false
	_warming = false
	_checked_out.clear()
	_warmed_ids.clear()
	_lit_effects.clear()
	_pool_growth = 0
	_rejected = 0
	_played = 0


func warm_effect_pool() -> bool:
	if is_ready:
		return true
	if _warming or _active_parent == null or _idle_parent == null:
		return false
	_warming = true
	var budget := FrameWorkBudget.new()
	# Keep a stable warm-up snapshot for the deferred return pass. This array
	# exists only during startup; event-time effect playback remains allocation
	# free apart from the pool's own bookkeeping.
	var warm_nodes: Array[Effect] = []
	for index in range(pool_size):
		var effect := ObjectPool.acquire(EFFECT_SCENE, _active_parent) as Effect
		if effect == null:
			await _abort_warmup()
			return false
		effect.configure_pool(_idle_parent)
		if not effect.returned_to_pool.is_connected(_on_effect_returned):
			effect.returned_to_pool.connect(_on_effect_returned)
		effect.prepare_visual_warmup()
		warm_nodes.append(effect)
		_checked_out.append(effect)
		_warmed_ids[effect.get_instance_id()] = true
		if budget.should_yield():
			await get_tree().process_frame
			budget.reset()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
	# Despawn is deferred by the wrapper, so the stable warm-up snapshot remains
	# valid when a budget yield lets returned_to_pool callbacks run.
	for effect in warm_nodes:
		if is_instance_valid(effect):
			effect.despawn()
		if budget.should_yield():
			await get_tree().process_frame
			budget.reset()
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
	if not is_ready:
		_rejected += 1
		return false
	if _checked_out.size() >= _warmed_ids.size():
		# Stale strong references are only possible after an external scene
		# teardown. Pay the compact cost on saturation, never on every effect.
		_compact_checked_out()
	if _checked_out.size() >= _warmed_ids.size():
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
	for effect in _checked_out:
		if is_instance_valid(effect):
			effect.despawn()
	_lit_effects.clear()


func get_metrics() -> Dictionary:
	_compact_checked_out()
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
	if is_instance_valid(effect):
		_lit_effects.erase(effect.get_instance_id())


func _compact_checked_out() -> void:
	var write_index := 0
	for effect in _checked_out:
		if not is_instance_valid(effect):
			continue
		_checked_out[write_index] = effect
		write_index += 1
	if write_index != _checked_out.size():
		_checked_out.resize(write_index)


func _abort_warmup() -> void:
	clear_effects()
	_warmed_ids.clear()
	_lit_effects.clear()
	await get_tree().process_frame
	_checked_out.clear()
	_warming = false
	is_ready = false


func _can_claim_local_light(kind: Effect.EffectKind) -> bool:
	if max_local_lights <= 0 or _lit_effects.size() >= max_local_lights:
		return false
	match kind:
		Effect.EffectKind.IMPACT, Effect.EffectKind.DEATH, Effect.EffectKind.BOOST:
			return true
		Effect.EffectKind.EXPLOSION, Effect.EffectKind.SHIELD:
			return true
	return false
