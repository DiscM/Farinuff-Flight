extends Node
## Headless navigation smoke tests for the FrontendShell.
##
## Proves, deterministically, the page registry contract: unknown ids are
## rejected, opening a page focuses its primary safe action, back() returns to
## the Command Deck, modals are exclusive and restore the exact invoking
## control, ui_cancel closes a modal before navigating back, and placeholder
## pages render with ids that match the registry.
##
## Run with:
## godot --headless --path . res://tests/frontend_navigation_smoke.tscn
## (Run the .tscn wrapper, not --script: the wrapper keeps the project
## autoloads and the render loop that delivers parsed input events.)

const SHELL_SCENE := preload("res://ui/frontend/frontend_shell.tscn")
const CONFIRMATION_DIALOG_SCENE := preload("res://ui/shared/confirmation_dialog.tscn")

const PLACEHOLDER_PAGES: Array[StringName] = [
	&"expedition_map",
	&"launch_bay",
	&"hangar",
	&"flight_school",
	&"settings",
	&"archives",
]

var _failures: Array[String] = []
var _shell: FrontendShell


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_shell = SHELL_SCENE.instantiate() as FrontendShell
	add_child(_shell)
	await _wait_frames(2)

	await _check_unknown_page_rejected()
	await check_page_focuses_primary()
	await _check_placeholder_pages()
	await _check_back_returns_to_command_deck()
	await _check_modal_exclusive_and_blocking()
	await _check_modal_restores_exact_invoker()
	await _check_modal_signal_close_restores_invoker()
	await _check_ui_cancel_closes_modal_before_back()
	await _check_shell_signals()
	await _wait_frames(1)

	if _failures.is_empty():
		print("PASS: frontend navigation smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# --- Page registry ------------------------------------------------------------

func _check_unknown_page_rejected() -> void:
	var before := _shell.get_current_page_id()
	var before_page := _shell.get_current_page()
	_shell.show_page(&"profile")
	await _wait_frames(1)
	_expect(
		_shell.get_current_page_id() == before,
		"show_page with an unknown id must leave the current page unchanged"
	)
	_expect(
		is_instance_valid(before_page) and _shell.get_current_page() == before_page,
		"show_page with an unknown id must not free or replace the current page"
	)


func _check_placeholder_pages() -> void:
	for page_id in PLACEHOLDER_PAGES:
		_shell.show_page(page_id)
		await _wait_frames(1)
		var page := _shell.get_current_page()
		_expect(
			page != null and str(page.get_meta(&"frontend_page_id", &"")) == str(page_id),
			"Placeholder page id must match the registry entry for %s" % page_id
		)
		_expect(page != null and _page_title_matches(page, page_id), "Placeholder %s must render its title" % page_id)
		_expect(_shell.get_current_page_id() == page_id, "get_current_page_id must track the shown page")
		_expect(_shell.back() == true, "back() from %s must report that it navigated" % page_id)


func _page_title_matches(page: Control, page_id: StringName) -> bool:
	for label in page.find_children("*", "Label", true, false):
		if label is Label:
			if str(label.text).to_upper().contains(str(
				FrontendShell.PAGE_DISPLAY_NAMES.get(page_id, page_id)
			).to_upper()):
				return true
	return false


# --- Focus --------------------------------------------------------------------

func check_page_focuses_primary() -> void:
	_shell.show_page(&"command_deck")
	await _wait_frames(1)
	var deck := _shell.get_current_page()
	_expect(deck != null, "Command Deck must be the default first page")
	_expect(
		_focused() == deck.call("get_primary_safe_action"),
		"Opening the Command Deck must focus the primary safe action (Launch)"
	)


func _check_back_returns_to_command_deck() -> void:
	_shell.show_page(&"hangar")
	await _wait_frames(1)
	_expect(_shell.back() == true, "back() from Hangar must report navigation")
	await _wait_frames(1)
	_expect(
		_shell.get_current_page_id() == &"command_deck",
		"back() from a non-command page must return to the Command Deck"
	)
	_expect(
		_focused() == _shell.get_current_page().call("get_primary_safe_action"),
		"Returning to the Command Deck must re-focus its primary safe action"
	)


# --- Modals ---------------------------------------------------------------------

func _check_modal_exclusive_and_blocking() -> void:
	_shell.show_page(&"command_deck")
	await _wait_frames(1)
	var first := _open_dialog("Title", "Body")
	await _wait_frames(1)
	_expect(_shell.has_open_modal(), "show_modal must open a modal")
	_expect(_focused() == first.call("get_cancel_button"), "Opening a modal must focus its safe action")
	var page_before := _shell.get_current_page()
	_shell.show_page(&"hangar")
	_expect(
		_shell.get_current_page() == page_before,
		"A modal must block page changes while open"
	)
	_shell.show_modal(CONFIRMATION_DIALOG_SCENE, {})
	_expect(_shell.get_open_modal() == first, "A second modal must be refused (modals are exclusive)")
	_expect(_shell.has_open_modal(), "Modal exclusivity must not drop the first modal")
	_shell.back()
	await _wait_frames(1)
	_expect(not _shell.has_open_modal(), "back() must close the open modal")


func _check_modal_restores_exact_invoker() -> void:
	_shell.show_page(&"command_deck")
	await _wait_frames(1)
	var deck := _shell.get_current_page()
	var invoker := deck.get_node("%MapButton") as Button
	invoker.grab_focus()
	await _wait_frames(1)
	_expect(
		_focused() == invoker,
		"Test setup: the invoking control (MapButton) must hold focus before the modal opens"
	)
	_open_dialog("Title", "Body")
	await _wait_frames(1)
	_expect(_shell.back() == true, "back() with a modal open must close it")
	await _wait_frames(1)
	_expect(
		_focused() == invoker,
		"Closing a modal must restore the exact invoking control, not merely the first button"
	)


func _check_modal_signal_close_restores_invoker() -> void:
	_shell.show_page(&"command_deck")
	await _wait_frames(1)
	var deck := _shell.get_current_page()
	var invoker := deck.get_node("%MapButton") as Button
	invoker.grab_focus()
	await _wait_frames(1)
	var dialog := _open_dialog("Title", "Body")
	await _wait_frames(1)
	var confirm_button := dialog.get_node("%ConfirmButton") as Button
	confirm_button.pressed.emit()
	await _wait_frames(2)
	_expect(not _shell.has_open_modal(), "A modal's own return signal must close it")
	_expect(
		_focused() == invoker,
		"A signal-driven modal close must restore the exact invoking control"
	)


func _check_ui_cancel_closes_modal_before_back() -> void:
	_shell.show_page(&"hangar")
	await _wait_frames(1)
	_open_dialog("Title", "Body")
	await _wait_frames(1)
	_press_action(&"ui_cancel")
	await _wait_frames(2)
	_expect(not _shell.has_open_modal(), "ui_cancel must close the open modal")
	_expect(
		_shell.get_current_page_id() == &"hangar",
		"ui_cancel must consume its level by closing the modal, not navigate underneath"
	)
	_press_action(&"ui_cancel")
	await _wait_frames(2)
	_expect(
		_shell.get_current_page_id() == &"command_deck",
		"A second ui_cancel with no modal must navigate back to the Command Deck"
	)


func _check_shell_signals() -> void:
	var signals_received := {
		"expedition": false,
		"section": &"",
	}
	_shell.expedition_requested.connect(func() -> void: signals_received["expedition"] = true)
	_shell.open_section.connect(func(page_id: StringName) -> void: signals_received["section"] = page_id)
	_shell.show_page(&"command_deck")
	await _wait_frames(1)
	var deck := _shell.get_current_page()
	(deck.get_node("%LaunchButton") as Button).pressed.emit()
	await _wait_frames(1)
	_expect(signals_received["expedition"], "The deck's expedition_requested must be re-emitted by the shell")
	(deck.get_node("%MapButton") as Button).pressed.emit()
	await _wait_frames(1)
	_expect(signals_received["section"] == &"expedition_map", "open_section must be re-emitted by the shell")
	_expect(
		_shell.get_current_page_id() == &"expedition_map",
		"The shell must route a page's open_section to the matching page"
	)


# --- Helpers -------------------------------------------------------------------

func _open_dialog(p_title: String, p_body: String) -> Control:
	_shell.show_modal(CONFIRMATION_DIALOG_SCENE, {})
	var modal := _shell.get_open_modal()
	if modal.has_method("display"):
		modal.call("display", p_title, p_body)
	return modal as Control


func _press_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)