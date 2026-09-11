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
	for upgrade in GameManager.get_upgrade_pool():
		var upgrade_id := str(upgrade["id"])
		if SUPPORTED_IDS.has(upgrade_id) and not GameManager.chosen_upgrade_ids.has(upgrade_id):
			upgrades.append(upgrade)
	return upgrades


static func draft(pool: Array[Dictionary], count: int = 3) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = pool.duplicate()
	remaining.shuffle()
	var result: Array[Dictionary] = []
	var roles: Array[String] = []
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
