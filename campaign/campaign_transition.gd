extends RefCounted
class_name CampaignTransition
## Outcome of one milestone record or abandonment, produced by ExpeditionManager.
##
## Carries only presentational data (which story beats to show, which nodes just
## opened, whether a route choice is pending). Callers never feed this payload
## back into the manager; they only render from it.

var cleared_node_id: StringName = &""
var next_reachable_node_ids: Array[StringName] = []
var pending_route_choice: bool = false
var route_choice_required: bool = false
var story_beat_ids: Array[StringName] = []
var ending_id: StringName = &""
var finale: bool = false
var abandoned: bool = false