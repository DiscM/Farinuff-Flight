extends RefCounted
class_name CampaignSnapshot
## Immutable read-only projection of campaign state returned by ExpeditionManager.
##
## Callers read these fields and must never mutate the returned instance or its
## arrays. ExpeditionManager rebuilds a fresh snapshot on every call so the
## internals (discovery arrays, route choice, milestones) stay behind the seam.

var expedition_active: bool = false
var current_node_id: StringName = &""
var next_reachable_node_ids: Array[StringName] = []
var cleared_node_ids: Array[StringName] = []
var discovered_node_ids: Array[StringName] = []
var seen_story_beat_ids: Array[StringName] = []
var recovered_fragment_ids: Array[StringName] = []
var pending_route_choice: bool = false
var selected_route_id: StringName = &""
var selected_route_profile_id: StringName = &""
var expedition_clear_count: int = 0
var last_ending_id: StringName = &""
var final_node_id: StringName = &""
var finale: bool = false