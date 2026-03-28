extends Node
## Manages global game state: score, lives, waves, combos, difficulty scaling, and stat allocation.

# --- State ---
var score: int = 0
var high_score: int = 0
var combo: int = 0
var lives: int = 3
var current_wave: int = 1
var is_game_active: bool = false
var boss_active: bool = false
var try_again_stocks: int = 3

# Upgrade IDs chosen so far this run — excluded from future pools.
var chosen_upgrade_ids: Array[String] = []

const ALL_UPGRADES: Array[Dictionary] = [
	# ── Original 5 ─────────────────────────────────────────────────────────────
	{
		"id": "twin_cannons",
		"name": "Twin Cannons",
		"icon": "🔫",
		"description": "Fire two parallel bullets\nwith every shot.",
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
		"description": "Reinforce the hull.\nGain +2 max lives.",
		"color": Color(0.8, 0.55, 1.0),
	},
	{
		"id": "afterburner",
		"name": "Afterburner",
		"icon": "🚀",
		"description": "+25% speed and snappier\nmaneuverability.",
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
		"description": "Every 8 s, emit a shockwave\nthat clears bullets & damages enemies.",
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
		"description": "Triple fire rate for 3 s\nevery 15 s. Stacks with Rapid Fire.",
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

# --- Difficulty scaling ---
var base_spawn_interval: float = 1.5
var min_spawn_interval: float = 0.3
var enemy_speed_multiplier: float = 1.0
var orbs_needed_this_wave: int = 10
var orbs_collected_this_wave: int = 0

# --- Point Allocation ---
var allocation_points_per_milestone: int = 3
var stat_fire_rate_level: int = 0
var stat_health_level: int = 0
var stat_speed_level: int = 0

# Computed bonuses (driven by stat levels)
var bonus_speed_pct: float = 0.0
var bonus_fire_rate_pct: float = 0.0
var bonus_damage: int = 0

# --- Orb Meter ---
var orbs_collected: int = 0
var orbs_per_heart: int = 10

func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.player_hit.connect(_on_player_hit)
	SignalBus.game_restarted.connect(_on_game_restarted)
	SignalBus.boss_died.connect(_on_boss_died)
	SignalBus.xp_orb_collected.connect(_on_orb_collected)

# --- Score & Combo ---

func _on_enemy_killed(points: int, _position: Vector2) -> void:
	combo += 1
	var multiplied_points := points * combo
	score += multiplied_points
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)

func _on_boss_died(_points: int) -> void:
	boss_active = false
	# Emit elite upgrade trigger FIRST so the game pauses before wave advances + spawning restarts.
	# But ONLY if we haven't already collected all possible elite upgrades.
	if current_wave % 10 == 0 and chosen_upgrade_ids.size() < ALL_UPGRADES.size():
		SignalBus.elite_upgrade_triggered.emit()
	_advance_wave()


# --- Orb Meter ---

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
func apply_stat_point(stat_name: String) -> void:
	match stat_name:
		"fire_rate":
			stat_fire_rate_level += 1
			bonus_fire_rate_pct += 0.05
		"health":
			stat_health_level += 1
			lives += 1
			SignalBus.lives_changed.emit(lives)
		"speed":
			stat_speed_level += 1
			bonus_speed_pct += 0.03

# --- Player hit ---

func _on_player_hit() -> void:
	combo = 0
	SignalBus.combo_changed.emit(combo)
	lives -= 1
	SignalBus.lives_changed.emit(lives)
	SignalBus.screen_shake.emit(8.0, 0.3)

	if lives <= 0:
		is_game_active = false
		if score > high_score:
			high_score = score
		SignalBus.game_over.emit(score)

# --- Waves ---

func _advance_wave() -> void:
	var cleared_wave := current_wave
	SignalBus.wave_cleared.emit(cleared_wave)
	current_wave += 1
	orbs_collected_this_wave = 0
	orbs_needed_this_wave = int(10.0 + float(current_wave) * 1.20)
	enemy_speed_multiplier = 1.0 + (current_wave - 1) * 0.06
	boss_active = (current_wave % 5 == 0)
	SignalBus.wave_started.emit(current_wave)

	# Trigger point allocation every 5 waves (after clearing wave 5, 10, 15…)
	if cleared_wave % 5 == 0:
		SignalBus.allocation_triggered.emit(allocation_points_per_milestone)

func get_spawn_interval() -> float:
	var interval := base_spawn_interval - (current_wave - 1) * 0.05
	return maxf(interval, min_spawn_interval)

# --- Restart ---

func _on_game_restarted() -> void:
	score = 0
	combo = 0
	lives = 3
	current_wave = 1
	orbs_collected_this_wave = 0
	orbs_needed_this_wave = 10
	enemy_speed_multiplier = 1.0

	# Reset allocation state
	stat_fire_rate_level = 0
	stat_health_level = 0
	stat_speed_level = 0
	bonus_speed_pct = 0.0
	bonus_fire_rate_pct = 0.0
	bonus_damage = 0
	orbs_collected = 0
	try_again_stocks = 3
	chosen_upgrade_ids = []

	is_game_active = true
	boss_active = false
	SignalBus.score_changed.emit(score)
	SignalBus.combo_changed.emit(combo)
	SignalBus.lives_changed.emit(lives)
	SignalBus.wave_started.emit(current_wave)

func start_game() -> void:
	_on_game_restarted()
