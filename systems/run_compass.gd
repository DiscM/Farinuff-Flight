extends RefCounted
## One milestone vocabulary shared by the combat header and pause briefing.
const BOSS_NAMES := {5: "COMMANDER", 10: "IRON BULWARK", 15: "TEMPEST", 20: "TEMPEST CORE", 25: "VOID HARBINGER"}

static func snapshot(wave: int, practice: bool = false) -> Dictionary:
	if practice:
		return {"mode": "PRACTICE", "wave": wave, "boss_wave": 0, "heading": "PRACTICE · MOVE / REFLECT / CHAIN", "reward": "No salvage or progression is consumed.", "compact": "PRACTICE · MOVE / REFLECT / CHAIN"}
	var target := ceili(float(maxi(wave, 1)) / 5.0) * 5
	var boss := str(BOSS_NAMES.get(target, "SECTOR BOSS"))
	var points := "%d SYSTEM POINTS" % GameManager.allocation_points_per_milestone
	var module_reward := "BONUS SUPPLIES" if GameManager.has_all_available_elites() else "MODULE"
	var reward := module_reward + " + " + points if GameManager.offers_elite_reward(target) else points
	if target == GameManager.FINAL_EXPEDITION_WAVE:
		reward = "EXPEDITION FINALE"
	var heading := "%s · WAVE %02d" % [boss, target]
	return {"mode": "ENDLESS" if wave > GameManager.FINAL_EXPEDITION_WAVE else "EXPEDITION", "wave": wave, "boss_wave": target, "heading": heading, "reward": reward, "compact": "%s · %s · %s" % ["CLEAR" if wave == target else "NEXT", heading, reward]}
