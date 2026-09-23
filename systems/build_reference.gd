extends RefCounted
## Read-only build copy shared by pause and reward selection.
const Catalog := preload("res://entities/player/native_player_upgrades.gd")

static func modules(owned: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in GameManager.ALL_UPGRADES + GameManager.META_ELITE_UPGRADES:
		if owned.has(str(definition.id)):
			result.append(definition.duplicate())
	return result

static func connections(owned: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for connection: Dictionary in Catalog.CONNECTIONS:
		if owned.has(str(connection.ids[0])) and owned.has(str(connection.ids[1])):
			result.append(str(connection.text))
	return result

static func compact(owned: Array[String]) -> String:
	var names := PackedStringArray()
	var installed := modules(owned)
	for index in mini(installed.size(), 3):
		names.append(str(installed[index].name))
	if installed.size() > 3:
		names.append("+%d more" % (installed.size() - 3))
	return "INSTALLED · " + (" · ".join(names) if not names.is_empty() else "No modules yet")

static func systems_text() -> String:
	return "SYSTEM ALLOCATIONS\nShot delay −%.1f%% · Thrust +%.1f%% · Extra lives granted %d\nThese bonuses last this run. Hull, hangar and module effects apply separately." % [GameManager.bonus_fire_rate_pct * 100.0, GameManager.bonus_speed_pct * 100.0, GameManager.stat_health_level]
