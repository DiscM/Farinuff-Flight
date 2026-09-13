extends Node
## Reward selection is reversible until Install, and applies exactly once.
class UpgradeReceiver extends Node:
	var installed: Array[String] = []
	func apply_elite_upgrade(id: String) -> bool:
		installed.append(id)
		return true

func _ready() -> void:
	# Let the boot cache finish before this short test tears down the engine.
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	var original_ids := GameManager.chosen_upgrade_ids.duplicate()
	GameManager.chosen_upgrade_ids.clear()
	var receiver := UpgradeReceiver.new()
	add_child(receiver)
	var popup := preload("res://ui/elite_upgrade_popup.tscn").instantiate()
	popup.panel_only = true
	popup.show_ship_previews = false
	popup.upgrade_target = receiver
	add_child(popup)
	await get_tree().process_frame
	var first: String = popup.chosen_upgrades[0].id
	var second: String = popup.chosen_upgrades[1].id
	popup._stage_upgrade(first)
	popup._stage_upgrade(second)
	if not receiver.installed.is_empty() or popup.selection_locked or popup._install_button.disabled:
		push_error("Selecting a card must not install it or lock the choice")
		get_tree().quit(1)
		return
	popup._install_button.pressed.emit()
	popup._install_button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	var passed: bool = receiver.installed == [second] and popup.selection_locked
	GameManager.chosen_upgrade_ids.assign(original_ids)
	popup.queue_free()
	receiver.queue_free()
	await get_tree().process_frame
	if passed:
		print("NEON_CABINET_SMOKE_PASS: selection can change; install applies exactly once")
	else:
		push_error("Install must apply only the final selected module exactly once")
	get_tree().quit(0 if passed else 1)
