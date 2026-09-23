extends RefCounted
## Native capabilities offered by the shared elite-reward UI. Definitions remain
## in GameManager; this list prevents offering unimplemented combat abilities.

const SUPPORTED_IDS: Array[String] = [
	"twin_cannons", "spread_shot_elite", "rear_gunner",
	"afterburner", "hull_plating", "drone_escort",
	"auto_aim", "shield_burst", "magnet_field", "overclock",
	"orbitals", "piercing", "explosive_rounds",
]


static func available() -> Array[Dictionary]:
	var upgrades: Array[Dictionary] = []
	var owned := GameManager.get_owned_elite_ids()
	for upgrade in GameManager.get_upgrade_pool():
		var upgrade_id := str(upgrade["id"])
		if SUPPORTED_IDS.has(upgrade_id) and not owned.has(upgrade_id):
			upgrades.append(upgrade)
	return upgrades


static func draft(pool: Array[Dictionary], count: int = 3, owned: Array[String] = []) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = pool.duplicate()
	remaining.shuffle()
	var result: Array[Dictionary] = []
	var roles: Array[String] = []
	# Preserve an opportunity to extend the current build, then offer different roles.
	if count > 0:
		for index in remaining.size():
			if not connection_text(str(remaining[index].get("id", "")), owned).is_empty():
				var connected: Dictionary = remaining.pop_at(index)
				result.append(connected)
				roles.append(str(connected.get("role", "Utility")))
				break
	while not remaining.is_empty() and result.size() < count:
		var choice := 0
		for index in remaining.size():
			if not roles.has(str(remaining[index].get("role", "Utility"))):
				choice = index
				break
		var upgrade: Dictionary = remaining.pop_at(choice)
		roles.append(str(upgrade.get("role", "Utility")))
		result.append(upgrade)
	return result


# Connections describe existing projectile behavior; they do not grant hidden bonuses.
const CONNECTIONS := [
	{"ids": ["twin_cannons", "auto_aim"], "text": "Twin Cannons' side shots also track enemies."},
	{"ids": ["spread_shot_elite", "auto_aim"], "text": "Every shot in the central fan can track a target."},
	{"ids": ["rear_gunner", "auto_aim"], "text": "Rear fire can turn toward nearby enemies."},
	{"ids": ["twin_cannons", "piercing"], "text": "The extra cannon shots pierce enemy lines too."},
	{"ids": ["spread_shot_elite", "piercing"], "text": "Each ray of the fan can pierce an enemy line."},
	{"ids": ["rear_gunner", "piercing"], "text": "Piercing extends your rear fire through pursuing ships."},
	{"ids": ["twin_cannons", "explosive_rounds"], "text": "Side cannons carry the same explosive payload."},
	{"ids": ["spread_shot_elite", "explosive_rounds"], "text": "Spread the explosive payload across your central fan."},
	{"ids": ["rear_gunner", "explosive_rounds"], "text": "Rear fire carries explosive rounds into pursuing groups."},
]

static func connection_text(upgrade_id: String, owned: Array[String]) -> String:
	for connection: Dictionary in CONNECTIONS:
		var pair: Array = connection.ids
		if not pair.has(upgrade_id):
			continue
		var partner := str(pair[1] if pair[0] == upgrade_id else pair[0])
		if owned.has(partner):
			return str(connection.text)
	return ""
