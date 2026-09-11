extends RefCounted
class_name RouteSelection
## Result of ExpeditionManager.choose_route. A rejected selection carries
## `applied == false` so callers can keep the map on the confirming node.

var node_id: StringName = &""
var profile_id: StringName = &""
var profile: Resource = null
var applied: bool = false