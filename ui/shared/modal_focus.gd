extends RefCounted
## Temporarily removes controls behind a modal from keyboard/controller focus.
## Nested modals restore only the focus modes they suspended themselves.

static func suspend_outside(modal: Control) -> Dictionary:
	var suspended := {}
	var viewport := modal.get_viewport()
	for control: Control in viewport.find_children("*", "Control", true, false):
		if control.get_viewport() != viewport or control == modal or modal.is_ancestor_of(control):
			continue
		if control.focus_mode != Control.FOCUS_NONE:
			suspended[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	# A scene/page replacement can remove a modal without its normal closed signal.
	modal.tree_exiting.connect(restore.bind(suspended), CONNECT_ONE_SHOT)
	return suspended


static func restore(suspended: Dictionary) -> void:
	for control: Control in suspended:
		if is_instance_valid(control) and not control.is_queued_for_deletion():
			control.focus_mode = suspended[control]
	suspended.clear()
