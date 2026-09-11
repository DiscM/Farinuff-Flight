extends Node
## Owns the Return Signal Expedition's route state, reachability, discovery and
## story flags, and durable persistence.
##
## This module is a deep seam: callers read mission state through get_snapshot()
## and record progress through the public methods. Discovery arrays, the current
## route, and the save payload stay behind these calls. Only durable
## campaign fields ever reach SaveManager.save_campaign; active-run state (route,
## wave, score, entities) intentionally never persists.

const CampaignCatalogResource := preload("res://systems/campaign_catalog.gd")
const CampaignDefinitionResource := preload("res://campaign/campaign_definition.gd")
const RouteNodeDefinitionResource := preload("res://campaign/route_node_definition.gd")
const SectorEncounterProfileResource := preload("res://campaign/sector_encounter_profile.gd")
const StoryBeatDefinitionResource := preload("res://campaign/story_beat_definition.gd")
const CampaignSnapshotResource := preload("res://campaign/campaign_snapshot.gd")
const CampaignTransitionResource := preload("res://campaign/campaign_transition.gd")
const RouteSelectionResource := preload("res://campaign/route_selection.gd")

const FINAL_ENDING_RETURN_HOME := &"return_home"
const FINAL_ENDING_FOLLOW_SIGNAL := &"follow_signal"
const VALID_ENDING_IDS: Array[StringName] = [FINAL_ENDING_RETURN_HOME, FINAL_ENDING_FOLLOW_SIGNAL]
## Dev surface: the four authored route profiles a debug panel may force.
const DEV_ROUTE_OVERRIDE_PROFILE_IDS: Array[StringName] = [
	&"profile_iron_wake",
	&"profile_ghost_lanes",
	&"profile_tempest_veil",
	&"profile_echo_field",
]

var _catalog: CampaignCatalogResource
var _campaign: CampaignDefinitionResource = null
var _campaign_ready := false

## Durable campaign state (survives process exit through SaveManager).
var _discovered_node_ids: Array[StringName] = []
var _seen_story_beat_ids: Array[StringName] = []
var _recovered_fragment_ids: Array[StringName] = []
var _expedition_clear_count := 0
var _last_ending_id: StringName = &""

## In-memory run state (resets with each start_new_expedition).
var _expedition_active := false
var _current_node_id: StringName = &""
var _cleared_in_run_node_ids: Array[StringName] = []
var _pending_route_choice := false
var _selected_route_id: StringName = &""
var _finale := false
var _route_override_profile_id: StringName = &""
var _abandon_sealed := false
var _sealed_transition: CampaignTransitionResource = null
var _completion_sealed := false


## Validates the authored campaign once and loads durable discovery/story state.
## The module stays inert (empty/false payloads) when the catalog is invalid
## rather than crashing. Runs after SaveManager, which owns the v3 save.
func _ready() -> void:
	_catalog = CampaignCatalogResource.new()
	_campaign = _catalog.get_campaign() as CampaignDefinitionResource
	if _campaign == null or not _catalog.is_valid(_campaign):
		push_error("ExpeditionManager: authored campaign is invalid; expedition module inactive.")
		return
	_campaign_ready = true
	_load_durable_state()


## Starts a fresh Expedition: resets all in-run route state, marks the start
## node discovered, and persists. Durable discovery, story, and clear data are
## preserved across runs. Returns the resulting snapshot.
func start_new_expedition() -> CampaignSnapshot:
	if not _campaign_ready:
		return CampaignSnapshotResource.new()
	_expedition_active = true
	_current_node_id = _campaign.start_node_id
	_cleared_in_run_node_ids.clear()
	_pending_route_choice = false
	_selected_route_id = &""
	_finale = false
	_abandon_sealed = false
	_sealed_transition = null
	_completion_sealed = false
	_ensure_nodes_discovered([_current_node_id])
	_persist()
	return get_snapshot()


## Applies a route selection for the next sector. Valid only when the node is
## one of the currently reachable nodes and lands in the sector immediately
## after the last cleared sector. Returns a RouteSelection with applied=false
## and no state change for any rejection.
func choose_route(node_id: StringName) -> RouteSelection:
	var rejected_selection := RouteSelectionResource.new()
	rejected_selection.node_id = node_id
	if not _campaign_ready or not _expedition_active:
		return rejected_selection
	var cleared_node := _get_last_cleared_node()
	if cleared_node == null:
		return rejected_selection
	var node := _get_node(node_id)
	if node == null:
		return rejected_selection
	if not cleared_node.outgoing_node_ids.has(node_id):
		return rejected_selection
	if node.sector_index != cleared_node.sector_index + 1:
		return rejected_selection
	if not _pending_route_choice and node_id != _campaign.final_node_id:
		return rejected_selection
	# The final node is fixed: selecting it only advances the run onto the final
	# sector. It is reported as not applied (no route choice exists) but stays
	# selectable as an explicit confirmation of the authored final route.
	if node_id == _campaign.final_node_id:
		_current_node_id = node_id
		_ensure_nodes_discovered([node_id])
		_persist()
		return rejected_selection
	_current_node_id = node_id
	_selected_route_id = node_id
	_pending_route_choice = false
	_ensure_nodes_discovered([node_id])
	_persist()
	var profile := _resolve_profile(node.encounter_profile_id)
	var selection := RouteSelectionResource.new()
	selection.node_id = node_id
	selection.profile_id = node.encounter_profile_id if profile != null else &""
	selection.profile = profile
	selection.applied = true
	return selection


## Records that the run cleared a five-wave milestone. Returns a CampaignTransition
## describing the cleared node, newly reachable nodes, and unseen story beats, or
## a no-op transition carrying the current state when the wave does not end an
## in-run sector. Wave 20 seals the run and deactivates the expedition.
func record_milestone(cleared_wave: int) -> CampaignTransition:
	if not _campaign_ready or not _expedition_active:
		return _noop_transition()
	var node := _resolve_cleared_node_for_wave(cleared_wave)
	if node == null:
		return _noop_transition()
	if _cleared_in_run_node_ids.has(node.id):
		return _noop_transition()
	_cleared_in_run_node_ids.append(node.id)
	if not node.fragment_beat_id.is_empty() and not _recovered_fragment_ids.has(node.fragment_beat_id):
		_recovered_fragment_ids.append(node.fragment_beat_id)
	_selected_route_id = &""
	_current_node_id = node.id
	var reachable: Array[StringName] = node.outgoing_node_ids.duplicate()
	_ensure_nodes_discovered(reachable)
	var transition := CampaignTransitionResource.new()
	transition.cleared_node_id = node.id
	transition.next_reachable_node_ids = reachable
	transition.story_beat_ids = _unseen_beats_on_node(node)
	if node.id == _campaign.final_node_id:
		_finale = true
		_expedition_active = false
		_pending_route_choice = false
		transition.finale = true
	else:
		_pending_route_choice = reachable.size() > 1
		transition.pending_route_choice = _pending_route_choice
		transition.route_choice_required = _pending_route_choice
	_persist()
	return transition


## Returns a fresh read-only projection of the campaign state with defensive
## copies of every array. Callers must never mutate the returned snapshot.
func get_snapshot() -> CampaignSnapshot:
	var snapshot := CampaignSnapshotResource.new()
	if not _campaign_ready:
		return snapshot
	snapshot.expedition_active = _expedition_active
	snapshot.current_node_id = _current_node_id
	snapshot.next_reachable_node_ids = _derive_reachable()
	snapshot.cleared_node_ids = _cleared_in_run_node_ids.duplicate()
	snapshot.discovered_node_ids = _discovered_node_ids.duplicate()
	snapshot.seen_story_beat_ids = _seen_story_beat_ids.duplicate()
	snapshot.recovered_fragment_ids = _recovered_fragment_ids.duplicate()
	snapshot.pending_route_choice = _pending_route_choice
	snapshot.selected_route_id = _selected_route_id
	snapshot.selected_route_profile_id = _selected_route_profile_id()
	snapshot.expedition_clear_count = _expedition_clear_count
	snapshot.last_ending_id = _last_ending_id
	snapshot.final_node_id = _campaign.final_node_id
	snapshot.finale = _finale
	return snapshot


## Finalizes an early-ending run exactly once. Clears in-memory route state,
## persists discovery and story flags, and returns the finalized transition.
## Durable clear count and ending record are intentionally not touched.
func abandon_expedition() -> CampaignTransition:
	if not _campaign_ready:
		return CampaignTransitionResource.new()
	if _abandon_sealed and _sealed_transition != null:
		return _copy_transition(_sealed_transition)
	_abandon_sealed = true
	_finale = false
	_expedition_active = false
	_reset_in_run_state()
	var transition := CampaignTransitionResource.new()
	transition.abandoned = true
	_persist()
	_sealed_transition = _copy_transition(transition)
	return _copy_transition(_sealed_transition)


## Marks a story beat as viewed for replay suppression and persists immediately.
## Unknown or already-viewed beats are ignored.
func record_story_viewed(beat_id: StringName) -> void:
	if not _campaign_ready:
		return
	if beat_id.is_empty() or _seen_story_beat_ids.has(beat_id):
		return
	if not _campaign_has_story_beat(beat_id):
		return
	_seen_story_beat_ids.append(beat_id)
	_persist()


## Banks a victory ending exactly once. Valid only immediately after the finale
## transition while the expedition is inactive. Only the two authored endings are
## accepted.
func complete_expedition(ending_id: StringName) -> void:
	if not _campaign_ready:
		return
	if not _finale or _expedition_active or _completion_sealed:
		return
	if not VALID_ENDING_IDS.has(ending_id):
		return
	_completion_sealed = true
	_expedition_clear_count += 1
	_last_ending_id = ending_id
	_persist()


## True while an Expedition is in progress (not abandoned, not finale-sealed).
func is_expedition_active() -> bool:
	return _expedition_active


## Returns the authored SectorEncounterProfile resource for the run's selected
## route, or the dev override when one is set. Null when the campaign is not
## active or no route has been selected.
func get_current_route_profile() -> Resource:
	if not _campaign_ready or not _expedition_active:
		return null
	if not _route_override_profile_id.is_empty():
		return _resolve_profile(_route_override_profile_id)
	if _selected_route_id.is_empty():
		return null
	var node := _get_node(_selected_route_id)
	if node == null:
		return null
	return _resolve_profile(node.encounter_profile_id)


## Debug/dev surface: forces get_current_route_profile() to the given authored
## profile even before a route is chosen. Returns false for unknown IDs.
func set_route_override(profile_id: StringName) -> bool:
	if not _campaign_ready or not DEV_ROUTE_OVERRIDE_PROFILE_IDS.has(profile_id):
		return false
	_route_override_profile_id = profile_id
	return true


## Reloads durable campaign fields from SaveManager. Test surface used
## by smoke scenes to force deterministic fixtures; production loads once in _ready().
func _load_durable_state() -> void:
	var state: Dictionary = SaveManager.get_campaign_state()
	_discovered_node_ids.clear()
	for entry: Variant in state.get("discovered_node_ids", []):
		if entry is String:
			_discovered_node_ids.append(StringName(entry))
	_seen_story_beat_ids.clear()
	for entry: Variant in state.get("seen_story_beat_ids", []):
		if entry is String:
			_seen_story_beat_ids.append(StringName(entry))
	_recovered_fragment_ids.clear()
	for entry: Variant in state.get("recovered_fragment_ids", []):
		if entry is String and entry.ends_with("_fragment") and _campaign_has_story_beat(StringName(entry)):
			_recovered_fragment_ids.append(StringName(entry))
	_expedition_clear_count = maxi(int(state.get("expedition_clear_count", 0)), 0)
	var ending_value: Variant = state.get("last_ending_id", "")
	_last_ending_id = StringName(ending_value) if ending_value is String and ending_value != "" else &""


## Persists campaign discoveries, fragment recovery, and ending history. Active-run state is never
## sent to the save layer.
func _persist() -> void:
	if not _campaign_ready:
		return
	var discovered: Array[String] = []
	for node_id in _discovered_node_ids:
		discovered.append(String(node_id))
	var seen: Array[String] = []
	for beat_id in _seen_story_beat_ids:
		seen.append(String(beat_id))
	var fragments: Array[String] = []
	for beat_id in _recovered_fragment_ids:
		fragments.append(String(beat_id))
	SaveManager.save_campaign({
		"discovered_node_ids": discovered,
		"seen_story_beat_ids": seen,
		"recovered_fragment_ids": fragments,
		"expedition_clear_count": _expedition_clear_count,
		"last_ending_id": String(_last_ending_id),
	})


## Resolves which in-run node the given milestone wave finishes: the selected
## route when one applies, else the current node, with the final node as the
## fallback so a fixed Wave-20 finale always resolves.
func _resolve_cleared_node_for_wave(wave: int) -> RouteNodeDefinitionResource:
	if not _selected_route_id.is_empty():
		var selected := _get_node(_selected_route_id)
		if selected != null and selected.last_wave == wave:
			return selected
	var current := _get_node(_current_node_id)
	if current != null and current.last_wave == wave:
		return current
	var final_node := _get_node(_campaign.final_node_id)
	if final_node != null and final_node.last_wave == wave:
		return final_node
	return null


## The most recently cleared node, or null before any sector is cleared.
func _get_last_cleared_node() -> RouteNodeDefinitionResource:
	if _cleared_in_run_node_ids.is_empty():
		return null
	return _get_node(_cleared_in_run_node_ids.back())


## Reachability contract for snapshots and no-op transitions: the last cleared
## node's outgoing connections, or the current node before the first clear.
func _derive_reachable() -> Array[StringName]:
	if not _cleared_in_run_node_ids.is_empty():
		var cleared_node := _get_last_cleared_node()
		if cleared_node != null:
			return cleared_node.outgoing_node_ids.duplicate()
	if not _current_node_id.is_empty():
		return [_current_node_id]
	return []


## Unseen debrief and fragment beats authored on a cleared node.
func _unseen_beats_on_node(node: RouteNodeDefinitionResource) -> Array[StringName]:
	var beats: Array[StringName] = []
	for beat_id in [node.debrief_beat_id, node.fragment_beat_id]:
		if beat_id.is_empty() or _seen_story_beat_ids.has(beat_id):
			continue
		beats.append(beat_id)
	return beats


## A transition reflecting current state with no clearing involved.
func _noop_transition() -> CampaignTransition:
	var transition := CampaignTransitionResource.new()
	transition.pending_route_choice = _pending_route_choice
	transition.route_choice_required = _pending_route_choice
	transition.next_reachable_node_ids = _derive_reachable()
	transition.finale = _finale
	return transition


func _selected_route_profile_id() -> StringName:
	if _selected_route_id.is_empty():
		return &""
	var node := _get_node(_selected_route_id)
	return node.encounter_profile_id if node != null else &""


## Appends nodes to discovery exactly once. Does not persist; callers persist.
func _ensure_nodes_discovered(node_ids: Array[StringName]) -> void:
	for node_id in node_ids:
		if not _discovered_node_ids.has(node_id):
			_discovered_node_ids.append(node_id)


func _campaign_has_story_beat(beat_id: StringName) -> bool:
	for raw_beat in _campaign.story_beats:
		var beat := raw_beat as StoryBeatDefinitionResource
		if beat != null and beat.id == beat_id:
			return true
	return false


func _get_node(node_id: StringName) -> RouteNodeDefinitionResource:
	if _campaign == null:
		return null
	for raw_node in _campaign.nodes:
		var node := raw_node as RouteNodeDefinitionResource
		if node != null and node.id == node_id:
			return node
	return null


func _resolve_profile(profile_id: StringName) -> SectorEncounterProfileResource:
	if _campaign == null or profile_id.is_empty():
		return null
	for raw_profile in _campaign.route_profiles:
		var profile := raw_profile as SectorEncounterProfileResource
		if profile != null and profile.id == profile_id:
			return profile
	return null


func _reset_in_run_state() -> void:
	_current_node_id = &""
	_cleared_in_run_node_ids.clear()
	_pending_route_choice = false
	_selected_route_id = &""
	_finale = false


func _copy_transition(transition: CampaignTransitionResource) -> CampaignTransitionResource:
	var copy := CampaignTransitionResource.new()
	copy.cleared_node_id = transition.cleared_node_id
	copy.next_reachable_node_ids = transition.next_reachable_node_ids.duplicate()
	copy.pending_route_choice = transition.pending_route_choice
	copy.route_choice_required = transition.route_choice_required
	copy.story_beat_ids = transition.story_beat_ids.duplicate()
	copy.ending_id = transition.ending_id
	copy.finale = transition.finale
	copy.abandoned = transition.abandoned
	return copy

func get_route_options() -> Array[Resource]:
	var options: Array[Resource] = []
	for node_id in get_snapshot().next_reachable_node_ids:
		var node := _get_node(node_id)
		if node != null:
			options.append(node)
	return options


func get_current_node() -> Resource:
	return _get_node(_current_node_id)


func get_story_beat(beat_id: StringName) -> Resource:
	if _campaign == null:
		return null
	for beat in _campaign.story_beats:
		if beat.id == beat_id:
			return beat
	return null


func get_route_description(node: Resource) -> String:
	var profile := _resolve_profile(node.encounter_profile_id)
	if profile == null:
		return "Basic and fast patrols · Learn boost reflection" if node.sector_index == 1 else "Final approach · Apex defenders · Tempest Core"
	return " · ".join(profile.threat_tags).replace("_", " ")


func get_chart_nodes() -> Array[Resource]:
	var nodes: Array[Resource] = []
	if _campaign != null:
		for node in _campaign.nodes:
			nodes.append(node)
	return nodes


func get_node_dossier(node_id: StringName) -> Dictionary:
	var node := _get_node(node_id)
	if node == null:
		return {}
	var boss_name := ""
	for boss in _campaign.boss_milestones:
		if boss.id == node.boss_variant_id:
			boss_name = str(boss.display_name)
	return {
		"title": node.display_name,
		"waves": "Waves %d–%d" % [node.first_wave, node.last_wave],
		"boss": boss_name,
		"threats": get_route_description(node),
		"discovered": _discovered_node_ids.has(node.id),
		"cleared": _cleared_in_run_node_ids.has(node.id),
	}


func get_recovered_fragments() -> Array[Resource]:
	var fragments: Array[Resource] = []
	if _campaign == null:
		return fragments
	for beat in _campaign.story_beats:
		if _recovered_fragment_ids.has(beat.id):
			fragments.append(beat)
	return fragments
