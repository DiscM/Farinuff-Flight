extends RefCounted
## One validated loadout snapshot for recovery, debrief, and victory screens.
const Catalog := preload("res://entities/player/native_player_upgrades.gd")
const FALLBACK_NAME := "YOUR SHIP"

static func snapshot(player: Node) -> Dictionary:
	var hull_id := MetaProgression.selected_ship
	var ship: Dictionary = {}
	for definition: Dictionary in MetaProgression.SHIP_VARIANTS:
		if str(definition.id) == hull_id:
			ship = definition
			break
	if ship.is_empty():
		hull_id = MetaProgression.DEFAULT_SHIP
		for definition: Dictionary in MetaProgression.SHIP_VARIANTS:
			if str(definition.id) == hull_id:
				ship = definition
				break
	var hull_name := _text(ship, "name", FALLBACK_NAME).to_upper()
	var ids: Array[String] = []
	if is_instance_valid(player) and player.has_method("get_active_elite_upgrade_ids"):
		for raw: Variant in player.get_active_elite_upgrade_ids():
			var id := str(raw)
			if Catalog.SUPPORTED_IDS.has(id) and not ids.has(id):
				ids.append(id)
	var definitions := {}
	for definition: Dictionary in GameManager.ALL_UPGRADES + GameManager.META_ELITE_UPGRADES:
		definitions[str(definition.id)] = definition
	var names := PackedStringArray()
	for id in ids:
		names.append(_text(definitions.get(id, {}), "name", id.replace("_", " ").to_upper()))
	var modules := "NONE INSTALLED" if names.is_empty() else " · ".join(names)
	return {
		"hull_id": hull_id,
		"hull_name": hull_name,
		"upgrade_ids": ids,
		"text": "SHIP  ·  %s\nUPGRADES  %d/%d  ·  %s" % [hull_name, ids.size(), Catalog.SUPPORTED_IDS.size(), modules],
	}

static func _text(data: Dictionary, key: String, fallback: String) -> String:
	var text := str(data.get(key, "")).strip_edges()
	return text if not text.is_empty() else fallback
