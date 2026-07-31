extends Node
## Manages global game state: score, lives, waves, combos, difficulty scaling, and stat allocation.

# --- State ---
var score: int = 0
var high_score: int = 0
## True when the finished run beat the previous high score. Set once at
## game over and reset on the next start_game(); read by the game-over screen.
var last_run_was_record: bool = false
var combo: int = 0
var lives: int = 3
var current_wave: int = 1
var is_game_active: bool = false
var boss_active: bool = false
var try_again_stocks: int = 2
var dev_enemy_generation_override: int = 0

# Upgrade IDs chosen so far this run — excluded from future pools.
var chosen_upgrade_ids: Array[String] = []

const ALL_UPGRADES: Array[Dictionary] = [
	# ── Original 5 ─────────────────────────────────────────────────────────────
	{
		"id": "twin_cannons",
		"name": "Twin Cannons",
		"icon": "🔫",
		"description": "Fire two additional bullets\nwith every shot.",
		"color": Color(1.0, 0.8, 0.2),
	},
	{
		"id": "auto_aim",
		"name": "Auto-Aim Core",
		"icon": "🎯",
		"description": "Bullets home in on\nthe nearest enemy.",
		"color": Color(0.3, 1.0, 0.5),
	},
	{
		"id": "drone_escort",
		"name": "Drone Escort",
		"icon": "🤖",
		"description": "A combat drone joins you,\nauto-firing at enemies.",
		"color": Color(0.4, 0.85, 1.0),
	},
	{
		"id": "hull_plating",
		"name": "Hull Plating",
		"icon": "🛡️",
		"description": "Reinforce the hull.\nGain +1 life.",
		"color": Color(0.8, 0.55, 1.0),
	},
	{
		"id": "afterburner",
		"name": "Afterburner",
		"icon": "🚀",
		"description": "+20% speed and +15% acceleration.\nSnappier maneuverability.",
		"color": Color(1.0, 0.45, 0.15),
	},
	# ── New Wave-10 Upgrades ────────────────────────────────────────────────────
	{
		"id": "spread_shot_elite",
		"name": "Spread Shot",
		"icon": "✦",
		"description": "Fire a permanent 3-way fan.\nStacks with Twin Cannons → 5 bullets.",
		"color": Color(1.0, 0.55, 0.9),
	},
	{
		"id": "shield_burst",
		"name": "Shield Burst",
		"icon": "💥",
		"description": "Every 10 s, emit a shockwave\nthat clears bullets & damages enemies.",
		"color": Color(0.3, 0.8, 1.0),
	},
	{
		"id": "magnet_field",
		"name": "Orb Magnet",
		"icon": "🧲",
		"description": "Permanently attract XP orbs\nand power-ups (faster pull).",
		"color": Color(1.0, 0.75, 0.1),
	},
	{
		"id": "overclock",
		"name": "Overclock",
		"icon": "⚡",
		"description": "Triple fire rate for 2.5 s\nevery 16 s. Stacks with Rapid Fire.",
		"color": Color(0.9, 1.0, 0.2),
	},
	{
		"id": "rear_gunner",
		"name": "Rear Gunner",
		"icon": "🔺",
		"description": "A rear cannon fires backward\neach shot. Inherits all bullet mods.",
		"color": Color(1.0, 0.35, 0.35),
	},
]

# Elite upgrades that only enter the Wave-10 pool once the matching
# MetaProgression shop item ("meta_unlock" id) has been purchased.
const META_ELITE_UPGRADES: Array[Dictionary] = [
	{
		"id": "orbitals",
		"name": "Orbital Array",
		"icon": "🛰️",
		"description": "Three projectiles orbit your ship,\ndamaging enemies on contact.",
		"color": Color(0.4, 0.85, 1.0),
		"meta_unlock": "meta_orbitals",
	},
	{
		"id": "piercing",
		"name": "Piercing Rounds",
		"icon": "🗡️",
		"description": "Bullets pass through enemies\ninstead of stopping on impact.",
		"color": Color(1.0, 0.75, 0.1),
		"meta_unlock": "meta_piercing",
	},
	{
		"id": "explosive_rounds",
		"name": "Explosive Rounds",
		"icon": "💣",
		"description": "Bullets deal area damage\non impact.",
		"color": Color(1.0, 0.35, 0.35),
		"meta_unlock": "meta_explosive",
	},
]

## Returns the elite upgrade pool for this run: the base catalog plus any
## meta-unlockable upgrades whose blueprint has been purchased.
func get_upgrade_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = ALL_UPGRADES.duplicate()
	for upgrade in META_ELITE_UPGRADES:
		if MetaProgression.is_unlocked(str(upgrade["meta_unlock"])):
			pool.append(upgrade)
	return pool

# --- Difficulty scaling ---
var base_spawn_interval: float = 1.55
var min_spawn_interval: float = 0.48
var orbs_needed_this_wave: int = 10
var orbs_collected_this_wave: int = 0

# --- Point Allocation ---
const STAT_BONUS_STEP: float = 0.045
const STAT_BONUS_CAP: float = 0.45

var allocation_points_per_milestone: int = 3
var stat_fire_rate_level: int = 0
var stat_health_level: int = 0
var stat_speed_level: int = 0

# Computed bonuses (driven by stat levels)
var bonus_speed_pct: float = 0.0
var bonus_fire_rate_pct: float = 0.0
var bonus_damage: int = 0

# Meta-progression bonuses (driven by purchased unlocks), applied every run.
# Kept separate from the allocation bonuses so the allocation cap stays intact.
var meta_speed_pct: float = 0.0
var meta_fire_rate_pct: float = 0.0
# Ship-variant bonuses (driven by the launch-bay selection), applied every run.
var ship_speed_pct: float = 0.0
var ship_fire_rate_pct: float = 0.0

# --- Meta-Progression ---
## Salvage banked during the current run (boss kills + end-of-run bonus).
## Displayed on the game-over screen; the wallet lives in MetaProgression.
var run_salvage: int = 0
# Run-summary breakdown, shown on the game-over screen.
var run_salvage_boss: int = 0
var run_salvage_score_bonus: int = 0
var run_salvage_wave_bonus: int = 0
## Salvage multiplier snapshot from the launch-bay modifiers, fixed for the run.
var run_salvage_multiplier: float = 1.0
## Guards against banking the end-of-run salvage bonus more than once per run.
var _run_finalized: bool = false

# --- Damage Feedback ---
const DAMAGE_SHAKE_WINDOW: float = 5.0
const DAMAGE_SHAKE_THRESHOLD: int = 2
var recent_player_damage_times: Array[float] = []

# --- Orb Meter ---
var orbs_collected: int = 0
var orbs_per_heart: int = 12

## Initializes the game manager: seeds the RNG, loads the persisted high score,
## and connects to all relevant signals from the SignalBus.
func _ready() -> void:
	randomize()
	high_score = SaveManager.high_score
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.player_hit.connect(_on_player_hit)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.xp_orb_collected.connect(_on_orb_collected)

# --- Score & Combo ---

## Called when an enemy is killed. Increments the combo counter,
## multiplies the kill points by the current combo, adds the result
## to the score, and emits score/combo change signals.
func _on_enemy_killed(points: int, _position: Vector2) -> void:
	combo += 1
	var multiplied_points := points * combo
	score += multiplied_points
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)

## Called when the boss dies. Clears the boss_active flag, triggers
## an elite upgrade selection if this was a Wave-10 boss and upgrades
## are still available, then advances to the next wave.
func _on_boss_died(_points: int) -> void:
	boss_active = false
	# Bosses are the primary salvage source during a run: elite bosses pay double.
	var base_reward := MetaProgression.SALVAGE_PER_ELITE_BOSS if current_wave % 10 == 0 else MetaProgression.SALVAGE_PER_BOSS
	var salvage_reward := roundi(float(base_reward) * run_salvage_multiplier)
	run_salvage += salvage_reward
	run_salvage_boss += salvage_reward
	MetaProgression.earn_salvage(salvage_reward)
	# Emit elite upgrade trigger FIRST so the game pauses before wave advances + spawning restarts.
	# But ONLY if we haven't already collected all possible elite upgrades.
	if current_wave % 10 == 0 and chosen_upgrade_ids.size() < get_upgrade_pool().size():
		SignalBus.elite_upgrade_triggered.emit()
	_advance_wave()


# --- Orb Meter ---

## Called when an XP orb is collected. Accumulates orb value into the
## meter; each time the meter fills, the player gains +1 life and the
## remainder carries over. Also tracks per-wave orb progress and
## triggers a wave advance when the threshold is met (unless a boss is active).
func _on_orb_collected(value: int) -> void:
	orbs_collected += value
	# If we gained more than enough for a heart, carry over the remainder
	while orbs_collected >= orbs_per_heart:
		orbs_collected -= orbs_per_heart
		lives += 1
		SignalBus.lives_changed.emit(lives)
	SignalBus.orb_meter_changed.emit(orbs_collected, orbs_per_heart)

	orbs_collected_this_wave += value
	if orbs_collected_this_wave >= orbs_needed_this_wave and not boss_active:
		_advance_wave()

# --- Point Allocation ---

## Called by the allocation popup when the player invests a point.
## Increments the chosen stat level and applies the corresponding bonus.
## [param stat_name]: One of "fire_rate", "health", or "speed".
func apply_stat_point(stat_name: String) -> void:
	match stat_name:
		"fire_rate":
			stat_fire_rate_level += 1
			bonus_fire_rate_pct = minf(bonus_fire_rate_pct + STAT_BONUS_STEP, STAT_BONUS_CAP)
		"health":
			stat_health_level += 1
			lives += 1
			SignalBus.lives_changed.emit(lives)
		"speed":
			stat_speed_level += 1
			bonus_speed_pct = minf(bonus_speed_pct + STAT_BONUS_STEP, STAT_BONUS_CAP)

# --- Player hit ---

## Called when the player takes a hit. Resets the combo to 0, deducts
## a life, records the damage timestamp for screen-shake logic, and
## triggers game over if lives reach 0 (saving a new high score if earned).
func _on_player_hit() -> void:
	combo = 0
	SignalBus.combo_changed.emit(combo)
	lives -= 1
	SignalBus.lives_changed.emit(lives)
	_record_player_damage_for_shake()

	if lives <= 0:
		is_game_active = false
		if score > high_score:
			high_score = score
			last_run_was_record = true
			SaveManager.record_high_score(high_score)
		SignalBus.game_over.emit(score)

## Tracks recent damage timestamps and triggers a screen shake when
## the player takes multiple hits within a short window. Clears the
## timestamp buffer after a shake fires to avoid continuous shaking.
func _record_player_damage_for_shake() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(recent_player_damage_times.size() - 1, -1, -1):
		if now - recent_player_damage_times[i] > DAMAGE_SHAKE_WINDOW:
			recent_player_damage_times.remove_at(i)
	recent_player_damage_times.append(now)
	if recent_player_damage_times.size() >= DAMAGE_SHAKE_THRESHOLD:
		SignalBus.screen_shake.emit(4.0, 0.18)
		recent_player_damage_times.clear()

# --- Waves ---

## Advances the game to the next wave. Emits a wave_cleared signal for
## the just-finished wave, increments the wave counter, recalculates
## orb thresholds and enemy speed scaling, sets boss_active for every
## 5th wave, and triggers a stat point allocation every 5 waves.
func _advance_wave() -> void:
	var cleared_wave := current_wave
	SignalBus.wave_cleared.emit(cleared_wave)
	current_wave += 1
	# Carry surplus orb progress into the next wave instead of silently
	# discarding it — this includes orbs farmed during boss waves, which
	# used to vanish at this reset.
	var needed_for_cleared_wave := orbs_needed_this_wave
	orbs_collected_this_wave = maxi(0, orbs_collected_this_wave - needed_for_cleared_wave)
	orbs_needed_this_wave = get_orb_threshold_for_wave(current_wave)
	# Regular enemy stats are fixed by generation; only spawn cadence scales by wave.
	boss_active = (current_wave % 5 == 0)
	SignalBus.wave_started.emit(current_wave)

	# Trigger point allocation every 5 waves (after clearing wave 5, 10, 15…)
	if cleared_wave % 5 == 0:
		SignalBus.allocation_triggered.emit(allocation_points_per_milestone)
	if current_wave == 6 or current_wave == 11 or current_wave == 16:
		SignalBus.evolution_transition_pending.emit(
			get_enemy_generation(),
			get_enemy_generation_name(get_enemy_generation())
		)


func get_enemy_generation(wave_number: int = current_wave) -> int:
	if dev_enemy_generation_override > 0:
		return clampi(dev_enemy_generation_override, 1, 4)
	return clampi(1 + floori(float(maxi(0, wave_number - 1)) / 5.0), 1, 4)


func get_enemy_generation_name(generation: int) -> String:
	return ["Standard", "Augmented", "Warform", "Apex"][clampi(generation, 1, 4) - 1]

## Returns the orb target for the given wave. The Energy Drought challenge
## modifier raises every target by 50%.
func get_orb_threshold_for_wave(wave_number: int) -> int:
	var threshold := 10.0 + float(wave_number) * 1.30
	if is_modifier_active("mod_orb_drought"):
		threshold *= 1.5
	return int(threshold)

## Returns the current enemy spawn interval in seconds, decreasing as
## waves progress but clamped to a minimum floor for playability. The Rapid
## Assault challenge modifier shortens the interval by 20%.
func get_spawn_interval() -> float:
	var interval := base_spawn_interval - float(current_wave - 1) * 0.045
	if is_modifier_active("mod_fast_spawns"):
		interval *= 0.8
	return maxf(interval, min_spawn_interval)

## Health multiplier applied to regular enemies by BaseEnemy. The Armored
## Fleet challenge modifier grants +30% HP.
func get_enemy_health_multiplier() -> float:
	return 1.3 if is_modifier_active("mod_tough_enemies") else 1.0

## True when the given challenge modifier was toggled on in the launch bay
## (and is owned). Effects read this at their source system.
func is_modifier_active(modifier_id: String) -> bool:
	return MetaProgression.is_modifier_active(modifier_id)

# --- Run Finalization ---

## Called once per run when the final game-over screen is shown (after the
## try-again flow resolves). Banks the end-of-run salvage bonus — score
## conversion plus a per-wave-cleared reward — on top of any boss salvage
## already banked during the run.
func finalize_run() -> void:
	if _run_finalized:
		return
	_run_finalized = true
	var waves_cleared := maxi(current_wave - 1, 0)
	run_salvage_score_bonus = roundi(float(score / MetaProgression.SALVAGE_SCORE_DIVISOR) * run_salvage_multiplier)
	run_salvage_wave_bonus = roundi(float(waves_cleared * MetaProgression.SALVAGE_PER_WAVE_CLEARED) * run_salvage_multiplier)
	var bonus := run_salvage_score_bonus + run_salvage_wave_bonus
	if bonus > 0:
		run_salvage += bonus
		MetaProgression.earn_salvage(bonus)

# --- Restart ---

## Entry point for starting a new game. Resets all game state to initial
## values for a new run — clears score, combo, lives, waves, stat
## allocations, orb meter, damage history, try-again stocks, and chosen
## upgrades — then emits signals to refresh the HUD.
func start_game() -> void:
	score = 0
	combo = 0
	lives = 3
	current_wave = 1
	orbs_collected_this_wave = 0
	orbs_needed_this_wave = get_orb_threshold_for_wave(current_wave)
	last_run_was_record = false

	# Reset allocation state
	stat_fire_rate_level = 0
	stat_health_level = 0
	stat_speed_level = 0
	bonus_speed_pct = 0.0
	bonus_fire_rate_pct = 0.0
	bonus_damage = 0
	orbs_collected = 0
	recent_player_damage_times.clear()
	try_again_stocks = 2
	chosen_upgrade_ids = []
	dev_enemy_generation_override = 0

	# Apply purchased meta-progression unlocks for the new run.
	run_salvage = 0
	run_salvage_boss = 0
	run_salvage_score_bonus = 0
	run_salvage_wave_bonus = 0
	run_salvage_multiplier = MetaProgression.get_salvage_multiplier()
	_run_finalized = false
	meta_speed_pct = MetaProgression.META_SPEED_BONUS * MetaProgression.get_level("meta_thrusters")
	meta_fire_rate_pct = MetaProgression.META_FIRE_RATE_BONUS * MetaProgression.get_level("meta_cannons")
	lives += MetaProgression.get_level("meta_hull")
	try_again_stocks += MetaProgression.get_level("meta_reserves")

	# Apply the launch-bay loadout: ship-variant profile and Damaged Hull.
	var profile := MetaProgression.get_selected_ship_profile()
	lives += int(profile.get("lives_delta", 0))
	ship_speed_pct = float(profile.get("speed_pct", 0.0))
	ship_fire_rate_pct = float(profile.get("fire_rate_pct", 0.0))
	if is_modifier_active("mod_frail"):
		lives -= 1
	lives = maxi(lives, 1)

	is_game_active = true
	boss_active = false
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)
	SignalBus.lives_changed.emit(lives)
	SignalBus.wave_started.emit(current_wave)
	SignalBus.orb_meter_changed.emit(orbs_collected, orbs_per_heart)
