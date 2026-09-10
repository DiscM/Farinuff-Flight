extends RefCounted
class_name CampaignCatalog
## Stateless public seam for validating the authored Return Signal catalog.
##
## Runtime progression belongs to the future ExpeditionManager. This module
## only resolves stable IDs and validates immutable authored content.

const CampaignDefinitionResource := preload("res://campaign/campaign_definition.gd")
const RouteNodeDefinitionResource := preload("res://campaign/route_node_definition.gd")
const SectorEncounterProfileResource := preload("res://campaign/sector_encounter_profile.gd")
const BossMilestoneDefinitionResource := preload("res://campaign/boss_milestone_definition.gd")
const StoryBeatDefinitionResource := preload("res://campaign/story_beat_definition.gd")
const AUTHORED_CAMPAIGN = preload("res://campaign/data/return_signal_expedition.tres")
const APPROVED_SECTOR_NAMES := [
	"The Far Reach",
	"The Broken Perimeter",
	"Tempest Reach",
	"The Quiet Core",
]
const APPROVED_ROUTE_NAMES := ["Iron Wake", "Ghost Lanes", "Tempest Veil", "Echo Field"]
const EXPECTED_BOSS_MILESTONES := {
	5: {"id": &"assault", "variant": 0, "name": "Assault Commander"},
	10: {"id": &"bulwark", "variant": 1, "name": "Iron Bulwark"},
	15: {"id": &"tempest", "variant": 2, "name": "Tempest"},
	20: {"id": &"core", "variant": 4, "name": "Tempest Core"},
	25: {"id": &"harbinger", "variant": 3, "name": "Void Harbinger"},
}


func get_campaign() -> CampaignDefinitionResource:
	return AUTHORED_CAMPAIGN


func validate_campaign(
	campaign: CampaignDefinitionResource = AUTHORED_CAMPAIGN
) -> PackedStringArray:
	var errors := PackedStringArray()
	if campaign == null:
		errors.append("campaign definition is null")
		return errors

	_validate_identity(campaign, errors)
	_validate_global_ids(campaign, errors)
	_validate_bosses(campaign, errors)
	_validate_profiles(campaign, errors)
	_validate_story(campaign, errors)
	_validate_nodes(campaign, errors)
	_validate_graph(campaign, errors)
	return errors


func is_valid(campaign: CampaignDefinitionResource = AUTHORED_CAMPAIGN) -> bool:
	return validate_campaign(campaign).is_empty()


func resolve_boss_for_wave(
	campaign: CampaignDefinitionResource,
	wave: int
) -> BossMilestoneDefinitionResource:
	if campaign == null:
		return null
	for raw_boss in campaign.boss_milestones:
		var boss := raw_boss as BossMilestoneDefinitionResource
		if boss != null and boss.wave == wave:
			return boss
	return null


func _validate_global_ids(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	var seen_ids := {}
	for collection in [campaign.nodes, campaign.route_profiles, campaign.boss_milestones, campaign.story_beats]:
		for raw_resource in collection:
			var resource := raw_resource as Resource
			if resource == null:
				continue
			var stable_id_value: Variant = resource.get("id")
			if stable_id_value == null or (not stable_id_value is StringName and not stable_id_value is String):
				continue
			var stable_id := StringName(stable_id_value)
			if stable_id.is_empty():
				continue
			if seen_ids.has(stable_id):
				errors.append("duplicate stable ID across campaign content: %s" % stable_id)
			else:
				seen_ids[stable_id] = true


func _validate_identity(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	if campaign.id.is_empty():
		errors.append("campaign ID must not be empty")
	if campaign.sector_names != PackedStringArray(APPROVED_SECTOR_NAMES):
		errors.append("campaign must contain exactly the four approved sector names")
	if campaign.start_node_id.is_empty() or campaign.final_node_id.is_empty():
		errors.append("campaign must define start and final node IDs")


func _validate_bosses(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	if campaign.boss_milestones.size() != EXPECTED_BOSS_MILESTONES.size():
		errors.append("campaign must contain exactly five boss milestones")
	var seen_ids := {}
	var seen_waves := {}
	for raw_boss in campaign.boss_milestones:
		var boss := raw_boss as BossMilestoneDefinitionResource
		if boss == null:
			errors.append("boss milestone collection contains a non-BossMilestoneDefinition resource")
			continue
		if boss.id.is_empty():
			errors.append("boss milestone ID must not be empty")
		elif seen_ids.has(boss.id):
			errors.append("duplicate boss milestone ID: %s" % boss.id)
		else:
			seen_ids[boss.id] = true
		if seen_waves.has(boss.wave):
			errors.append("duplicate boss milestone wave: %d" % boss.wave)
		else:
			seen_waves[boss.wave] = true
	for wave in EXPECTED_BOSS_MILESTONES:
		var expected: Dictionary = EXPECTED_BOSS_MILESTONES[wave]
		var boss := resolve_boss_for_wave(campaign, wave)
		if boss == null:
			errors.append("missing boss milestone at Wave %d" % wave)
			continue
		if boss.id != expected["id"]:
			errors.append("Wave %d must resolve boss ID %s" % [wave, expected["id"]])
		if boss.display_name != expected["name"]:
			errors.append("boss %s has the wrong authored identity" % boss.id)
		if boss.production_variant_index != expected["variant"]:
			errors.append("boss %s has the wrong production variant" % boss.id)


func _validate_profiles(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	if campaign.route_profiles.size() != APPROVED_ROUTE_NAMES.size():
		errors.append("campaign must contain exactly four route profiles")
	var seen_ids := {}
	var route_names := []
	for raw_profile in campaign.route_profiles:
		var profile := raw_profile as SectorEncounterProfileResource
		if profile == null:
			errors.append("route profile collection contains a non-SectorEncounterProfile resource")
			continue
		if profile.id.is_empty():
			errors.append("route profile ID must not be empty")
		elif seen_ids.has(profile.id):
			errors.append("duplicate route profile ID: %s" % profile.id)
		else:
			seen_ids[profile.id] = true
		if profile.route_name not in APPROVED_ROUTE_NAMES:
			errors.append("route profile has an unapproved route name: %s" % profile.route_name)
		elif profile.route_name in route_names:
			errors.append("duplicate route profile name: %s" % profile.route_name)
		else:
			route_names.append(profile.route_name)
		if not profile.multipliers_are_neutral():
			errors.append("route profile %s must keep neutral MVP multipliers" % profile.id)
		var archetype_weights := [
			profile.basic_weight,
			profile.fast_weight,
			profile.bomber_weight,
			profile.tank_weight,
			profile.sniper_weight,
		]
		var total_archetype_weight := 0.0
		for weight: float in archetype_weights:
			total_archetype_weight += weight
			if (
				weight < SectorEncounterProfileResource.MIN_ARCHETYPE_WEIGHT
				or weight > SectorEncounterProfileResource.MAX_ARCHETYPE_WEIGHT
			):
				errors.append("route profile %s must use bounded archetype weights" % profile.id)
				break
		if total_archetype_weight <= 0.0:
			errors.append("route profile %s must define a positive archetype weight" % profile.id)
		for multiplier in [profile.spawn_multiplier, profile.orb_multiplier, profile.pickup_multiplier, profile.threat_budget_multiplier]:
			if multiplier < SectorEncounterProfileResource.MIN_MULTIPLIER or multiplier > SectorEncounterProfileResource.MAX_MULTIPLIER:
				errors.append("route profile %s has an out-of-bounds multiplier" % profile.id)
	if route_names.size() != APPROVED_ROUTE_NAMES.size():
		errors.append("campaign must contain exactly the four approved route names")


func _validate_story(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	var seen_ids := {}
	for raw_beat in campaign.story_beats:
		var beat := raw_beat as StoryBeatDefinitionResource
		if beat == null:
			errors.append("story collection contains a non-StoryBeatDefinition resource")
			continue
		if beat.id.is_empty():
			errors.append("story beat ID must not be empty")
		elif seen_ids.has(beat.id):
			errors.append("duplicate story beat ID: %s" % beat.id)
		else:
			seen_ids[beat.id] = true
		if beat.text_key.is_empty():
			errors.append("story beat %s must define a text key" % beat.id)


func _validate_nodes(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	var seen_ids := {}
	var nodes_by_id := {}
	var profiles_by_id := _index_profiles(campaign)
	var bosses_by_id := _index_bosses(campaign)
	var story_by_id := _index_story(campaign)
	for raw_node in campaign.nodes:
		var node := raw_node as RouteNodeDefinitionResource
		if node == null:
			errors.append("node collection contains a non-RouteNodeDefinition resource")
			continue
		if node.id.is_empty():
			errors.append("route node ID must not be empty")
		elif seen_ids.has(node.id):
			errors.append("duplicate route node ID: %s" % node.id)
		else:
			seen_ids[node.id] = true
			nodes_by_id[node.id] = node
		if node.sector_index < 1 or node.sector_index > APPROVED_SECTOR_NAMES.size():
			errors.append("route node %s has an invalid sector index" % node.id)
		var expected_first_wave := (node.sector_index - 1) * 5 + 1
		var expected_last_wave := node.sector_index * 5
		if node.first_wave != expected_first_wave or node.last_wave != expected_last_wave:
			errors.append("route node %s must cover its authored five-wave sector" % node.id)
		if node.last_wave < node.first_wave:
			errors.append("route node %s has an inverted wave range" % node.id)
		if node.boss_variant_id.is_empty():
			errors.append("route node %s must define a boss milestone ID" % node.id)
		elif not bosses_by_id.has(node.boss_variant_id):
			errors.append("route node %s references missing boss %s" % [node.id, node.boss_variant_id])
		if not node.encounter_profile_id.is_empty() and not profiles_by_id.has(node.encounter_profile_id):
			errors.append("route node %s references missing encounter profile %s" % [node.id, node.encounter_profile_id])
		for required_beat_id in [node.briefing_beat_id, node.debrief_beat_id]:
			if required_beat_id.is_empty():
				errors.append("route node %s must define briefing and debrief story IDs" % node.id)
		for beat_id in [node.briefing_beat_id, node.debrief_beat_id, node.fragment_beat_id]:
			if not beat_id.is_empty() and not story_by_id.has(beat_id):
				errors.append("route node %s references missing story beat %s" % [node.id, beat_id])
		if not node.fragment_beat_id.is_empty() and story_by_id.has(node.fragment_beat_id):
			var fragment := story_by_id[node.fragment_beat_id] as StoryBeatDefinitionResource
			if fragment.trigger_type != &"fragment":
				errors.append("route node %s must reference a fragment story beat" % node.id)
	for raw_node in campaign.nodes:
		var node := raw_node as RouteNodeDefinitionResource
		if node == null:
			continue
		for target_id in node.outgoing_node_ids:
			if not nodes_by_id.has(target_id):
				errors.append("route node %s references missing connection %s" % [node.id, target_id])


func _validate_graph(
	campaign: CampaignDefinitionResource,
	errors: PackedStringArray
) -> void:
	var nodes_by_id := _index_nodes(campaign)
	if not nodes_by_id.has(campaign.start_node_id):
		errors.append("campaign start node is unresolved: %s" % campaign.start_node_id)
		return
	if not nodes_by_id.has(campaign.final_node_id):
		errors.append("campaign final node is unresolved: %s" % campaign.final_node_id)
		return
	var final_node := nodes_by_id[campaign.final_node_id] as RouteNodeDefinitionResource
	if not final_node.outgoing_node_ids.is_empty():
		errors.append("final node must not have outgoing connections")
	var visited := {}
	var pending := [campaign.start_node_id]
	while not pending.is_empty():
		var node_id: StringName = pending.pop_front()
		if visited.has(node_id) or not nodes_by_id.has(node_id):
			continue
		visited[node_id] = true
		var node := nodes_by_id[node_id] as RouteNodeDefinitionResource
		if node_id != campaign.final_node_id and node.outgoing_node_ids.is_empty():
			errors.append("non-final node %s is a dead end" % node_id)
		for target_id in node.outgoing_node_ids:
			if nodes_by_id.has(target_id):
				var target := nodes_by_id[target_id] as RouteNodeDefinitionResource
				if target.sector_index != node.sector_index + 1:
					errors.append("connection %s -> %s bypasses a sector" % [node_id, target_id])
				pending.append(target_id)
	if visited.size() != nodes_by_id.size():
		errors.append("every route node must be reachable from the campaign start")
	var can_reach_final := _nodes_that_reach_final(final_node, nodes_by_id)
	if can_reach_final.size() != nodes_by_id.size():
		errors.append("every route node must lead to the campaign final node")


func _nodes_that_reach_final(
	final_node: RouteNodeDefinitionResource,
	nodes_by_id: Dictionary
) -> Dictionary:
	var reachable := {final_node.id: true}
	var changed := true
	while changed:
		changed = false
		for raw_node in nodes_by_id.values():
			var node := raw_node as RouteNodeDefinitionResource
			if reachable.has(node.id):
				continue
			for target_id in node.outgoing_node_ids:
				if reachable.has(target_id):
					reachable[node.id] = true
					changed = true
					break
	return reachable


func _index_nodes(campaign: CampaignDefinitionResource) -> Dictionary:
	var indexed := {}
	for raw_node in campaign.nodes:
		var node := raw_node as RouteNodeDefinitionResource
		if node != null:
			indexed[node.id] = node
	return indexed


func _index_profiles(campaign: CampaignDefinitionResource) -> Dictionary:
	var indexed := {}
	for raw_profile in campaign.route_profiles:
		var profile := raw_profile as SectorEncounterProfileResource
		if profile != null:
			indexed[profile.id] = profile
	return indexed


func _index_bosses(campaign: CampaignDefinitionResource) -> Dictionary:
	var indexed := {}
	for raw_boss in campaign.boss_milestones:
		var boss := raw_boss as BossMilestoneDefinitionResource
		if boss != null:
			indexed[boss.id] = boss
	return indexed


func _index_story(campaign: CampaignDefinitionResource) -> Dictionary:
	var indexed := {}
	for raw_beat in campaign.story_beats:
		var beat := raw_beat as StoryBeatDefinitionResource
		if beat != null:
			indexed[beat.id] = beat
	return indexed
