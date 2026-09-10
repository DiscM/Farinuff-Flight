extends Node
## Focused headless coverage for the authored Return Signal campaign contract.
##
## Run with:
## godot --headless --path . res://tests/campaign_catalog_smoke.tscn
##
## The test observes CampaignCatalog through its public validation seam. The
## catalog owns no expedition progress and the authored Resources are treated
## as immutable content after load.

const CampaignCatalogScript := preload("res://systems/campaign_catalog.gd")

const EXPECTED_SECTORS := [
	"The Far Reach",
	"The Broken Perimeter",
	"Tempest Reach",
	"The Quiet Core",
]
const EXPECTED_ROUTES := ["Iron Wake", "Ghost Lanes", "Tempest Veil", "Echo Field"]
const EXPECTED_BOSSES := {
	5: {"id": &"assault", "variant": 0, "name": "Assault Commander"},
	10: {"id": &"bulwark", "variant": 1, "name": "Iron Bulwark"},
	15: {"id": &"tempest", "variant": 2, "name": "Tempest"},
	20: {"id": &"core", "variant": 4, "name": "Tempest Core"},
	25: {"id": &"harbinger", "variant": 3, "name": "Void Harbinger"},
}

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = CampaignCatalogScript.new()
	var campaign = catalog.call("get_campaign")
	_expect(campaign != null, "CampaignCatalog must expose the authored campaign")
	if campaign == null:
		_finish()
		return

	var validation_errors: PackedStringArray = catalog.call("validate_campaign", campaign)
	_expect(validation_errors.is_empty(), "Authored campaign must validate: %s" % "; ".join(validation_errors))
	_expect(catalog.call("is_valid", campaign), "Public catalog validity seam must accept authored content")
	_expect(campaign.sector_names == PackedStringArray(EXPECTED_SECTORS), "Campaign must contain exactly the four approved sector names")

	var route_names: Array[String] = []
	for raw_profile in campaign.route_profiles:
		var profile := raw_profile as Resource
		_expect(profile != null, "Campaign route profiles must use Resource definitions")
		if profile == null:
			continue
		var route_name: Variant = profile.get("route_name")
		_expect(route_name is String, "Campaign route profiles must define route names")
		if route_name is String:
			route_names.append(route_name)
	route_names.sort()
	var expected_routes := EXPECTED_ROUTES.duplicate()
	expected_routes.sort()
	_expect(route_names == expected_routes, "Campaign must contain exactly the four approved route profiles")

	for wave in EXPECTED_BOSSES:
		var expected: Dictionary = EXPECTED_BOSSES[wave]
		var boss = catalog.call("resolve_boss_for_wave", campaign, wave)
		_expect(boss != null, "Wave %d must resolve an authored boss" % wave)
		if boss != null:
			_expect(boss.id == expected["id"], "Wave %d must resolve boss ID %s" % [wave, expected["id"]])
			_expect(boss.wave == wave, "Boss %s must retain its authored milestone wave" % boss.id)
			_expect(boss.production_variant_index == expected["variant"], "Boss %s must retain production variant %d" % [boss.id, expected["variant"]])
			_expect(boss.display_name == expected["name"], "Boss %s must retain its authored identity" % boss.id)

	var zero_weight_campaign = campaign.duplicate()
	zero_weight_campaign.route_profiles = campaign.route_profiles.duplicate()
	var zero_weight_profile = campaign.route_profiles[0].duplicate()
	zero_weight_profile.basic_weight = 0.0
	zero_weight_profile.fast_weight = 0.0
	zero_weight_profile.bomber_weight = 0.0
	zero_weight_profile.tank_weight = 0.0
	zero_weight_profile.sniper_weight = 0.0
	zero_weight_campaign.route_profiles[0] = zero_weight_profile
	_expect(
		_has_error(catalog.validate_campaign(zero_weight_campaign), "positive archetype weight"),
		"Catalog validation must reject a route profile that can produce zero enemies"
	)
	var unsafe_weight_campaign = campaign.duplicate()
	unsafe_weight_campaign.route_profiles = campaign.route_profiles.duplicate()
	var unsafe_weight_profile = campaign.route_profiles[0].duplicate()
	unsafe_weight_profile.basic_weight = 100.0
	unsafe_weight_campaign.route_profiles[0] = unsafe_weight_profile
	_expect(
		_has_error(catalog.validate_campaign(unsafe_weight_campaign), "bounded archetype weights"),
		"Catalog validation must reject unsafe archetype weight scaling"
	)
	var invalid_fragment_campaign = campaign.duplicate()
	invalid_fragment_campaign.nodes = campaign.nodes.duplicate()
	var invalid_fragment_node = campaign.nodes[0].duplicate()
	invalid_fragment_node.fragment_beat_id = &"far_reach_debrief"
	invalid_fragment_campaign.nodes[0] = invalid_fragment_node
	_expect(
		_has_error(catalog.validate_campaign(invalid_fragment_campaign), "fragment story beat"),
		"Catalog validation must reject a non-fragment story beat in fragment_beat_id"
	)

	# The ResourceCache autoload begins a threaded run-scene load at boot. Let
	# it complete before exiting so this fast smoke does not tear down a worker
	# mid-parse and emit misleading resource errors.
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: campaign catalog smoke tests")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
