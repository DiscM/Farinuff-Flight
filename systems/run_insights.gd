extends RefCounted
## Run-local evidence. No save writes, rewards, grades, or inferred accuracy.
var active_seconds := 0.0
var boosts := 0
var reflections := 0
var counter_hits := 0
var chains := 0
var hits_taken := 0
var armor_saves := 0
var best_combo := 0
var last_damage_source := -1

func advance(delta: float) -> void:
	active_seconds += maxf(delta, 0.0)

func record_damage(source: int) -> void:
	hits_taken += 1
	last_damage_source = source

func summary() -> String:
	var seconds := int(active_seconds)
	var copy := "%d:%02d IN FLIGHT  ·  %d REFLECTED  ·  %d CHAINS\n%d COUNTER HITS  ·  BEST STREAK %d  ·  %d HITS TAKEN" % [floori(seconds / 60.0), seconds % 60, reflections, chains, counter_hits, best_combo, hits_taken]
	return copy + ("\nARMOR SAVES %d" % armor_saves if armor_saves > 0 else "")

func next_attempt_tip() -> String:
	match last_damage_source:
		0:
			return "LAST HIT · COLLISION\nKeep a turning lane open; boost reflects shots but does not protect you from ships."
		1:
			return "LAST HIT · ENEMY FIRE\nBoost through reflectable fire. Cyan shots must be dodged."
		2:
			return "LAST HIT · MINE / PLASMA\nLeave marked blast zones early; keep clear of lingering plasma."
	if reflections == 0:
		return "NEXT FLIGHT · TRY A COUNTERATTACK\nBoost through reflectable shots to send them back at double base-shot damage."
	if chains == 0:
		return "NEXT FLIGHT · LINK A BOOST\nReflect three shots in one boost, then press Boost again while the chain cue is lit."
	return "NEXT FLIGHT · SHAPE YOUR BUILD\nLook for module connections that extend your installed weapons."


func counters() -> Dictionary:
	return {"boosts": boosts, "reflections": reflections, "counter_hits": counter_hits,
		"chains": chains, "hits_taken": hits_taken, "armor_saves": armor_saves}
