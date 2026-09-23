extends CanvasLayer
class_name HomeBaseServices
## Station-local menus. The home port owns pausing and restoring flight;
## this layer owns service navigation and recoverable flight preparation.

signal closed

const FRONTEND := preload("res://ui/frontend/frontend_shell.tscn")
const RUN_PATH := "res://scenes/native_3d_run.tscn"
const PRACTICE_PATH := "res://scenes/flight_practice.tscn"

class ServiceLaunchTransition extends "res://ui/frontend/launch_transition.gd":
	func _ready() -> void:
		super._ready()
		_back.text = "RETURN TO SERVICE"

	func show_failure() -> void:
		super.show_failure()
		_status.text = "Couldn't prepare your flight.\nReturn to the service and try again."

var frontend: FrontendShell
var _launch_layer: CanvasLayer
var _launching := false
var _resume_page: StringName = &"launch_bay"
var _preparation_generation := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func open_service(page_id: StringName, payload: Dictionary = {}) -> void:
	if _launching:
		return
	if page_id == &"command_deck" or not FrontendShell.PAGE_REGISTRY.has(page_id):
		push_warning("HomeBaseServices: unknown station service '%s'" % page_id)
		return
	show()
	_mount_frontend(page_id, payload)


func is_open() -> bool:
	return visible and is_instance_valid(frontend)


func get_current_page_id() -> StringName:
	return frontend.get_current_page_id() if is_open() else &""


func close_service() -> void:
	if _launching or not is_open():
		return
	_discard_frontend()
	hide()
	closed.emit()


## Stops only this launch intent. ResourceCache may finish warming the scene,
## but its result cannot replace the station after the pilot cancels or quits.
func cancel_preparation() -> bool:
	if not _launching:
		return false
	_recover_launch()
	return true


func _mount_frontend(page_id: StringName, payload: Dictionary = {}) -> void:
	_discard_frontend()
	frontend = FRONTEND.instantiate() as FrontendShell
	frontend.name = "StationService"
	frontend.service_mode = true
	frontend.initial_page = page_id
	frontend.initial_payload = payload.duplicate()
	frontend.service_closed.connect(close_service)
	frontend.home_base_requested.connect(close_service)
	frontend.expedition_requested.connect(_launch_expedition)
	frontend.practice_requested.connect(_launch_practice)
	add_child(frontend)


func _discard_frontend() -> void:
	if is_instance_valid(frontend):
		frontend.hide()
		frontend.process_mode = Node.PROCESS_MODE_DISABLED
		frontend.queue_free()
	frontend = null


func _launch_expedition() -> void:
	_prepare_flight(RUN_PATH)


func _launch_practice(wave: int) -> void:
	if _launching:
		return
	GameManager.practice_boss_wave = wave
	_prepare_flight(PRACTICE_PATH)


func _prepare_flight(path: String) -> void:
	if _launching or not is_open():
		return
	_launching = true
	_preparation_generation += 1
	var generation := _preparation_generation
	_resume_page = frontend.get_current_page_id()
	frontend.set_navigation_locked(true)
	_launch_layer = CanvasLayer.new()
	_launch_layer.layer = 70
	_launch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_launch_layer)
	var transition := ServiceLaunchTransition.new()
	transition.scene_path = path
	transition.returned.connect(_recover_launch)
	_launch_layer.add_child(transition)
	var scene := await ResourceCache.wait_for_scene(path)
	if not is_inside_tree() or generation != _preparation_generation or not _launching:
		return
	var tree := get_tree()
	if scene != null:
		tree.paused = false
		if tree.change_scene_to_packed(scene) == OK:
			return
		tree.paused = true
	transition.show_failure()


func _recover_launch() -> void:
	_preparation_generation += 1
	if is_instance_valid(_launch_layer):
		_launch_layer.hide()
		# Disable the transition's input immediately: a quit dialog may be
		# mounted in this same frame, before deferred deletion has completed.
		for transition: Node in _launch_layer.get_children():
			transition.process_mode = Node.PROCESS_MODE_DISABLED
			transition.set_process_input(false)
		_launch_layer.queue_free()
	_launch_layer = null
	_launching = false
	# Hosted menus guard launch callbacks after emitting. Recreate the page so
	# retry, back, and loadout changes all work after a failed preparation.
	_mount_frontend(_resume_page)
