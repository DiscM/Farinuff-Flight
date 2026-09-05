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
