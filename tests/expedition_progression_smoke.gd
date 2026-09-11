extends Node
## Deterministic headless coverage for the ExpeditionManager progression and
## persistence contract.
##
## Run with:
## godot --headless --path . res://tests/expedition_progression_smoke.tscn
## (Run the .tscn wrapper, not --script: --script mode skips the autoloads these
## tests depend on.)

const CLEAN_CAMPAIGN_STATE := {
	"discovered_node_ids": [],
	"seen_story_beat_ids": [],
	"expedition_clear_count": 0,
	"last_ending_id": "",
}

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path: String = SaveManager.SAVE_PATH
	var backup_path: String = SaveManager.SAVE_BACKUP_PATH
	var temp_path: String = SaveManager.SAVE_TEMP_PATH
	var had_save := FileAccess.file_exists(save_path)
	var original_bytes: PackedByteArray = []
	if had_save:
		original_bytes = FileAccess.get_file_as_bytes(save_path)
	var had_backup := FileAccess.file_exists(backup_path)
	var original_backup_bytes: PackedByteArray = []
	if had_backup:
		original_backup_bytes = FileAccess.get_file_as_bytes(backup_path)
	var had_temp := FileAccess.file_exists(temp_path)
	var original_temp_bytes: PackedByteArray = []
	if had_temp:
		original_temp_bytes = FileAccess.get_file_as_bytes(temp_path)
	var original_campaign_state: Dictionary = SaveManager.get_campaign_state()

	# Remove transactional leftovers for a deterministic fixture and force a
	# clean durable slate so assertions stay absolute. Restored below.
	if had_backup:
		DirAccess.remove_absolute(backup_path)
	if had_temp:
		DirAccess.remove_absolute(temp_path)
	SaveManager.campaign_state = CLEAN_CAMPAIGN_STATE.duplicate(true)
	ExpeditionManager._load_durable_state()

	_check_progression()
	_check_persistence_round_trip()

	# Restore the player's real save files and in-memory state. ExpeditionManager
	# reloads so the autoload stays consistent with the restored save.
	_restore_file(save_path, had_save, original_bytes)
	_restore_file(backup_path, had_backup, original_backup_bytes)
	_restore_file(temp_path, had_temp, original_temp_bytes)
	SaveManager.campaign_state = original_campaign_state
	ExpeditionManager._load_durable_state()
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	await get_tree().process_frame

	if _failures.is_empty():
		print("PASS: expedition progression smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_progression() -> void:
	var snapshot := ExpeditionManager.get_snapshot()
	_expect(snapshot.final_node_id == &"quiet_core", "Campaign final node must resolve")
	_expect(not ExpeditionManager.is_expedition_active(), "No expedition is active before start")
	_expect(ExpeditionManager.get_current_route_profile() == null, "No route profile before a route is chosen")

	# -- Expedition start ---------------------------------------------------
	snapshot = ExpeditionManager.start_new_expedition()
	_expect(snapshot.expedition_active, "start_new_expedition activates the expedition")
	_expect(snapshot.current_node_id == &"far_reach", "Expedition begins at The Far Reach")
	_expect(snapshot.next_reachable_node_ids == [&"far_reach"], "Only The Far Reach is reachable at start")
	_expect(_contains(snapshot.discovered_node_ids, &"far_reach"), "The start node is discovered immediately")
	_expect(snapshot.cleared_node_ids.is_empty(), "No sectors are cleared at start")
	_expect(not snapshot.pending_route_choice, "No route choice is pending at start")
	_expect(ExpeditionManager.is_expedition_active(), "is_expedition_active is true after start")

	# -- Wave 5 clears The Far Reach ---------------------------------------
	var transition := ExpeditionManager.record_milestone(5)
	_expect(transition.cleared_node_id == &"far_reach", "Wave 5 clears The Far Reach")
	_expect(
		transition.next_reachable_node_ids == [&"iron_wake", &"ghost_lanes"],
		"Wave 5 reveals both sector-2 routes"
	)
	_expect(transition.pending_route_choice, "Wave 5 requires a route choice")
	_expect(transition.route_choice_required, "Wave 5 reports the choice as required")
	_expect(transition.story_beat_ids == [&"far_reach_debrief"], "Wave 5 queues the far-reach debrief")
	_expect(not transition.finale, "Wave 5 is not the finale")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(snapshot.pending_route_choice, "Snapshot reports the pending Wave-5 choice")
	_expect(
		_contains(snapshot.discovered_node_ids, &"iron_wake")
		and _contains(snapshot.discovered_node_ids, &"ghost_lanes"),
		"Route branches enter discovery at Wave 5"
	)
	_expect(snapshot.cleared_node_ids == [&"far_reach"], "Snapshot reports far_reach as cleared")
	# Presenter marks the debrief viewed so replay suppression is testable later.
	ExpeditionManager.record_story_viewed(&"far_reach_debrief")

	# A stray milestone never finishes an in-run sector and changes nothing.
	var stray := ExpeditionManager.record_milestone(7)
	_expect(stray.cleared_node_id.is_empty(), "A stray wave must not clear a sector")
	_expect(stray.story_beat_ids.is_empty(), "A stray wave must not queue story beats")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(
		snapshot.pending_route_choice and snapshot.cleared_node_ids == [&"far_reach"],
		"A stray wave is inert"
	)

	# -- Iron Wake route choice ---------------------------------------------
	var selection := ExpeditionManager.choose_route(&"iron_wake")
	_expect(selection.applied, "Iron Wake selection applies")
	_expect(selection.node_id == &"iron_wake", "Selection reports the chosen node")
	_expect(selection.profile_id == &"profile_iron_wake", "Selection resolves the authored profile id")
	_expect(selection.profile != null, "Selection carries the resolved profile resource")
	var profile := ExpeditionManager.get_current_route_profile()
	_expect(profile != null, "A route profile is available after selection")
	if profile != null:
		_expect((profile as SectorEncounterProfile).id == &"profile_iron_wake", "Active profile matches the selected route")
	var rejected_alt := ExpeditionManager.choose_route(&"ghost_lanes")
	_expect(not rejected_alt.applied, "A second sector-2 route is rejected once a route is set")
	_expect(ExpeditionManager.get_snapshot().selected_route_id == &"iron_wake", "Selection is stored on the snapshot")

	# -- Wave 10 clears the chosen route ------------------------------------
	transition = ExpeditionManager.record_milestone(10)
	_expect(transition.cleared_node_id == &"iron_wake", "Wave 10 clears the chosen Iron Wake route")
	_expect(
		transition.next_reachable_node_ids == [&"tempest_veil", &"echo_field"],
		"Wave 10 reveals both sector-3 routes"
	)
	_expect(transition.pending_route_choice, "Wave 10 requires a route choice")
	_expect(
		transition.story_beat_ids == [&"broken_perimeter_debrief", &"iron_wake_fragment"],
		"Wave 10 queues the debrief and Iron Wake fragment"
	)
	ExpeditionManager.record_story_viewed(&"broken_perimeter_debrief")
	ExpeditionManager.record_story_viewed(&"iron_wake_fragment")
	ExpeditionManager.record_story_viewed(&"iron_wake_fragment")
	_expect(
		ExpeditionManager.get_snapshot().seen_story_beat_ids.count(&"iron_wake_fragment") == 1,
		"Marking an already-viewed beat must not duplicate it"
	)

	# -- Echo Field route choice --------------------------------------------
	selection = ExpeditionManager.choose_route(&"echo_field")
	_expect(selection.applied, "Echo Field selection applies")
	_expect(selection.profile_id == &"profile_echo_field", "Echo Field resolves its profile id")

	# -- Wave 15 clears the chosen route and fixes the final route ------------
	transition = ExpeditionManager.record_milestone(15)
	_expect(transition.cleared_node_id == &"echo_field", "Wave 15 clears Echo Field")
	_expect(transition.next_reachable_node_ids == [&"quiet_core"], "Wave 15 reveals only The Quiet Core")
	_expect(not transition.pending_route_choice, "The final route is fixed after Wave 15")
	_expect(
		transition.story_beat_ids == [&"tempest_reach_debrief", &"echo_field_fragment"],
		"Wave 15 queues the debrief and Echo Field fragment"
	)

	# The fixed final route stays selectable as a confirmation, never applied.
	selection = ExpeditionManager.choose_route(&"quiet_core")
	_expect(not selection.applied, "Quiet Core is not an applied route choice")
	_expect(selection.node_id == &"quiet_core", "The final-route confirmation is reported")
	_expect(ExpeditionManager.get_snapshot().current_node_id == &"quiet_core", "The run advances onto the final node")

	# -- Wave 20 seals the Expedition -----------------------------------------
	transition = ExpeditionManager.record_milestone(20)
	_expect(transition.finale, "Wave 20 is the finale")
	_expect(transition.cleared_node_id == &"quiet_core", "Wave 20 clears The Quiet Core")
	_expect(transition.story_beat_ids == [&"expedition_victory"], "Wave 20 queues the victory beat")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(snapshot.finale, "Snapshot reports the finale")
	_expect(not snapshot.expedition_active, "The expedition is inactive after the finale")
	_expect(snapshot.next_reachable_node_ids.is_empty(), "No routes follow the finale")

	# -- Ending completion -----------------------------------------------------
	ExpeditionManager.complete_expedition(&"return_home")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(snapshot.expedition_clear_count == 1, "A completed expedition banks one clear")
	_expect(snapshot.last_ending_id == &"return_home", "The return-home ending is recorded")
	ExpeditionManager.complete_expedition(&"follow_signal")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(snapshot.expedition_clear_count == 1, "Double completion must be ignored")
	_expect(snapshot.last_ending_id == &"return_home", "The first ending cannot be overwritten")

	# -- Abandon after the finale finalizes exactly once ------------------------
	var abandon := ExpeditionManager.abandon_expedition()
	_expect(abandon.abandoned, "Abandon after the finale finalizes the run")
	var abandon_again := ExpeditionManager.abandon_expedition()
	_expect(abandon_again.abandoned, "Abandon stays finalized on the second call")
	_expect(abandon_again.cleared_node_id == abandon.cleared_node_id, "Duplicate abandon repeats the same transition")
	snapshot = ExpeditionManager.get_snapshot()
	_expect(snapshot.expedition_clear_count == 1, "Abandon preserves the clear count")

	# -- A fresh expedition resets route state but keeps durable discovery --------
	snapshot = ExpeditionManager.start_new_expedition()
	_expect(snapshot.expedition_active, "A fresh expedition reactivates")
	_expect(snapshot.current_node_id == &"far_reach", "A fresh expedition restarts at The Far Reach")
	_expect(snapshot.cleared_node_ids.is_empty(), "A fresh expedition resets cleared sectors")
	_expect(snapshot.selected_route_id.is_empty(), "A fresh expedition resets the route choice")
	_expect(_contains(snapshot.discovered_node_ids, &"quiet_core"), "Discovery survives a fresh expedition")
	_expect(snapshot.expedition_clear_count == 1, "The clear count survives a fresh expedition")
	_expect(snapshot.last_ending_id == &"return_home", "The ending record survives a fresh expedition")

	# -- Replay suppresses already-seen prose -------------------------------------
	transition = ExpeditionManager.record_milestone(5)
	_expect(transition.cleared_node_id == &"far_reach", "Wave 5 still resolves on a replay")
	_expect(transition.story_beat_ids.is_empty(), "Already-seen beats are suppressed on replay")

	# -- Dev route override wins before a route choice -----------------------------
	_expect(ExpeditionManager.set_route_override(&"profile_ghost_lanes"), "Known profile override is accepted")
	var overridden := ExpeditionManager.get_current_route_profile()
	_expect(
		overridden != null and (overridden as SectorEncounterProfile).id == &"profile_ghost_lanes",
		"Override wins before a route is chosen"
	)
	_expect(not ExpeditionManager.set_route_override(&"not_a_profile"), "Unknown override id is rejected")


func _check_persistence_round_trip() -> void:
	# Only the four durable fields reach the save layer and they round-trip.
	var snapshot := ExpeditionManager.get_snapshot()
	var saved: Dictionary = SaveManager.get_campaign_state()
	_expect(
		Array(saved.get("discovered_node_ids", [])).has("quiet_core"),
		"Discovery persists into the save payload"
	)
	_expect(
		Array(saved.get("seen_story_beat_ids", [])).has("far_reach_debrief"),
		"Viewed story beats persist into the save payload"
	)
	_expect(
		int(saved.get("expedition_clear_count", -1)) == snapshot.expedition_clear_count,
		"The clear count round-trips through the save"
	)
	_expect(
		String(saved.get("last_ending_id", "")) == String(snapshot.last_ending_id),
		"The ending id round-trips through the save"
	)
	_expect(
		not saved.has("current_node_id") and not saved.has("selected_route_id"),
		"Active-run state must never reach the save layer"
	)


func _contains(values: Array[StringName], target: StringName) -> bool:
	return values.has(target)


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)