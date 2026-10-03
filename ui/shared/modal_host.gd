extends Node
## Owns one modal's lifetime and focus isolation. A nested host suspends only
## the controls enabled by its parent, so closing it preserves outer isolation.

signal dismissed(modal: Control)

const Focus := preload("res://ui/shared/modal_focus.gd")
var _modal: Control
var _invoker: Control
var _suspended: Dictionary = {}


func get_modal() -> Control:
	return _modal if is_open() else null


func is_open() -> bool:
	return is_instance_valid(_modal)


## Configure the modal's action signals before presenting it. Panels emitting
## `closed` are dismissed automatically; self-closing dialogs are observed on
## tree exit. Repeated presentation cannot replace an unresolved decision.
func present(modal: Control, invoker: Control = null) -> bool:
	if is_open() or modal == null:
		return false
	_invoker = invoker if invoker != null else get_viewport().gui_get_focus_owner()
	_modal = modal
	modal.tree_exiting.connect(_on_modal_exiting.bind(modal), CONNECT_ONE_SHOT)
	if modal.has_signal(&"closed"):
		modal.connect(&"closed", dismiss)
	add_child(modal)
	_suspended = Focus.suspend_outside(modal)
	return true


func dismiss() -> void:
	if not is_open():
		return
	var modal := _modal
	_release(true)
	modal.queue_free()
	dismissed.emit(modal)


func _on_modal_exiting(modal: Control) -> void:
	if _modal != modal:
		return
	_release(not is_queued_for_deletion() and is_inside_tree())
	dismissed.emit(modal)


func _exit_tree() -> void:
	_release(false)


func _release(restore_invoker: bool) -> void:
	_modal = null
	Focus.restore(_suspended)
	if restore_invoker and is_instance_valid(_invoker) and _invoker.is_inside_tree():
		if not _invoker.is_queued_for_deletion() and _invoker.is_visible_in_tree():
			_invoker.grab_focus()
	_invoker = null
