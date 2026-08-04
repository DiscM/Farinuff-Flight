extends Node
## Meta-progression: persistent salvage currency and permanent unlocks that
## carry across runs. The wallet, unlock levels, and ship/modifier selections
## are persisted through SaveManager; this autoload owns the catalogs,
## purchase logic, and run-loadout selections.

@warning_ignore("unused_signal")
## Emitted whenever the salvage balance changes. Carries the new total.
signal salvage_changed(new_total: int)
@warning_ignore("unused_signal")
## Emitted when an unlock is purchased. Carries the item id and new level.
signal unlock_purchased(unlock_id: String, new_level: int)

# --- Hangar systems (tiered) and elite blueprints (single level) ---
const SHOP_ITEMS: Array[Dictionary] = [
	{
		"id": "meta_hull",
		"name": "Hull Reinforcement",
		"icon": "🛡️",
		"description": "Start every run with +1 life per level.",
		"costs": [150, 300, 600],
		"category": "system",
		"color": Color(0.8, 0.55, 1.0),
	},
	{
		"id": "meta_thrusters",
		"name": "Tuned Thrusters",
		"icon": "🚀",
		"description": "+8% movement speed per level.",
		"costs": [150, 300, 600],
		"category": "system",
		"color": Color(1.0, 0.45, 0.15),
	},
	{
		"id": "meta_cannons",
		"name": "Overcharged Cannons",
		"icon": "⚡",
		"description": "+8% fire rate per level.",
		"costs": [150, 300, 600],
		"category": "system",
		"color": Color(0.9, 1.0, 0.2),
	},
	{
		"id": "meta_reserves",
		"name": "Emergency Reserves",
		"icon": "🔄",
		"description": "+1 try-again stock per level.",
		"costs": [200, 400],
		"category": "system",
		"color": Color(0.3, 1.0, 0.5),
	},
	{
		"id": "meta_orbitals",
		"name": "Blueprint: Orbital Array",
		"icon": "🛰️",
		"description": "Adds Orbital Array to the\nelite upgrade pool.",
		"costs": [250],
		"category": "blueprint",
		"color": Color(0.4, 0.85, 1.0),
	},
	{
		"id": "meta_piercing",
		"name": "Blueprint: Piercing Rounds",
		"icon": "🗡️",
		"description": "Adds Piercing Rounds to the\nelite upgrade pool.",
		"costs": [250],
		"category": "blueprint",
		"color": Color(1.0, 0.75, 0.1),
	},
	{
		"id": "meta_explosive",
		"name": "Blueprint: Explosive Rounds",
		"icon": "💣",
		"description": "Adds Explosive Rounds to the\nelite upgrade pool.",
		"costs": [250],
		"category": "blueprint",
		"color": Color(1.0, 0.35, 0.35),
	},
]

# --- Ship variants (sidegrade stat profiles, selected in the launch bay) ---
const SHIP_VARIANTS: Array[Dictionary] = [
	{
		"id": "ship_swallowtail",
		"name": "Swallowtail",
		"icon": "🦋",
		"description": "The standard frame.\nBalanced across all systems.",
		"cost": 0,
		"color": Color(0.14, 0.93, 1.0),
		"profile": {"lives_delta": 0, "speed_pct": 0.0, "fire_rate_pct": 0.0},
	},
	{
		"id": "ship_interceptor",
		"name": "Interceptor",
		"icon": "🗡️",
		"description": "+15% speed, +10% fire rate.\n-1 starting life.",
		"cost": 400,
		"color": Color(1.0, 0.45, 0.15),
		"profile": {"lives_delta": -1, "speed_pct": 0.15, "fire_rate_pct": 0.10},
	},
	{
		"id": "ship_bulwark",
		"name": "Bulwark",
		"icon": "🛡️",
		"description": "+2 starting lives.\n-10% speed, -10% fire rate.",
		"cost": 400,
		"color": Color(0.8, 0.55, 1.0),
		"profile": {"lives_delta": 2, "speed_pct": -0.10, "fire_rate_pct": -0.10},
	},
]

# --- Consumables (repeatable purchases, consumed at the next run's start) ---
const CONSUMABLE_ITEMS: Array[Dictionary] = [
	{
		"id": "consumable_stock",
		"name": "Reserve Stock",
		"icon": "⭐",
		"description": "+1 try-again stock for your\nnext run. Stockpile up to 3.",
		"cost": 120,
		"category": "consumable",
		"color": Color(1.0, 0.85, 0.2),
	},
	{
		"id": "consumable_powerup",
		"name": "Pre-Loaded Drop Pod",
		"icon": "🎁",
		"description": "Start your next run with a random\npower-up already installed.",
		"cost": 100,
		"category": "consumable",
		"color": Color(0.4, 0.85, 1.0),
	},
]

# --- Challenge modifiers (toggled in the launch bay for bonus salvage) ---
const CHALLENGE_MODIFIERS: Array[Dictionary] = [
	{
		"id": "mod_fast_spawns",
		"name": "Rapid Assault",
		"icon": "⏩",
		"description": "Enemies spawn 20% faster.",
		"bonus_pct": 0.20,
		"cost": 300,
		"color": Color(1.0, 0.35, 0.35),
	},
	{
		"id": "mod_tough_enemies",
		"name": "Armored Fleet",
		"icon": "🔩",
		"description": "Regular enemies have +30% HP.",
		"bonus_pct": 0.30,
		"cost": 300,
		"color": Color(0.7, 0.75, 0.85),
	},
	{
		"id": "mod_frail",
		"name": "Damaged Hull",
		"icon": "💔",
		"description": "Start with -1 life.",
		"bonus_pct": 0.15,
		"cost": 300,
		"color": Color(1.0, 0.16, 0.55),
	},
	{
		"id": "mod_no_powerups",
		"name": "Supply Blockade",
		"icon": "🚫",
		"description": "No power-up drops.",
		"bonus_pct": 0.25,
		"cost": 300,
		"color": Color(0.55, 0.65, 0.8),
	},
	{
		"id": "mod_orb_drought",
		"name": "Energy Drought",
		"icon": "🌑",
		"description": "Waves need 50% more orbs.",
		"bonus_pct": 0.25,
		"cost": 300,
		"color": Color(0.4, 0.5, 1.0),
	},
]

# System magnitudes per unlock level, applied by GameManager.start_game().
const META_SPEED_BONUS: float = 0.08
const META_FIRE_RATE_BONUS: float = 0.08

# Salvage rewards. Bosses are the primary source; the score conversion uses
# diminishing returns (square root) so combo-inflated scores can't dwarf them.
const SALVAGE_PER_BOSS: int = 30
const SALVAGE_PER_ELITE_BOSS: int = 60
const SALVAGE_PER_WAVE_CLEARED: int = 3
## End-of-run score conversion: salvage = sqrt(score / N).
const SALVAGE_SCORE_SQRT_DIVISOR: float = 10.0

## One-time flat salvage awards for first-time wave clears (wave → bonus).
## Not affected by the modifier multiplier.
const FIRST_CLEAR_MILESTONES: Dictionary = {
	5: 50,
	10: 100,
	15: 150,
	20: 250,
	25: 400,
	30: 600,
}

## How many Reserve Stock consumables can be stockpiled at once.
const MAX_STOCKPILED_STOCKS: int = 3

const DEFAULT_SHIP := "ship_swallowtail"

var salvage: int = 0
## Unlock state for every purchasable id: item id -> owned level (0 = locked).
var unlock_levels: Dictionary = {}
var selected_ship: String = DEFAULT_SHIP
var active_modifiers: Array[String] = []

# Consumable state (persisted).
var consumable_stocks: int = 0
var consumable_powerup_armed: bool = false

## First-clear milestone waves already awarded (persisted).
var claimed_milestones: Array[int] = []

# Lifetime stats (persisted).
var stat_total_runs: int = 0
var stat_total_kills: int = 0
var stat_best_wave: int = 0
## True when the last finalized run set a new best-wave record. Read by the
## game-over screen; not persisted.
var last_run_set_best_wave: bool = false

## Loads the persisted meta state from SaveManager.
func _ready() -> void:
	salvage = SaveManager.salvage
	unlock_levels = SaveManager.unlock_levels.duplicate()
	selected_ship = SaveManager.selected_ship
	active_modifiers = SaveManager.active_modifiers.duplicate()
	consumable_stocks = clampi(SaveManager.consumable_stocks, 0, MAX_STOCKPILED_STOCKS)
	consumable_powerup_armed = SaveManager.consumable_powerup
	claimed_milestones = SaveManager.claimed_milestones.duplicate()
	stat_total_runs = SaveManager.stat_total_runs
	stat_total_kills = SaveManager.stat_total_kills
	stat_best_wave = SaveManager.stat_best_wave
	_sanitize_selections()

# --- Wallet ---

## Adds salvage to the wallet, persists it, and notifies listeners.
func earn_salvage(amount: int) -> void:
	if amount <= 0:
		return
	salvage += amount
	_persist()
	salvage_changed.emit(salvage)

# --- Catalog lookup ---

## Returns the item definition for the given id from any catalog
## (systems/blueprints, consumables, ships, modifiers), or an empty Dictionary.
func get_item(item_id: String) -> Dictionary:
	for item in SHOP_ITEMS:
		if item["id"] == item_id:
			return item
	for item in CONSUMABLE_ITEMS:
		if item["id"] == item_id:
			return item
	for ship in SHIP_VARIANTS:
		if ship["id"] == item_id:
			return ship
	for modifier in CHALLENGE_MODIFIERS:
		if modifier["id"] == item_id:
			return modifier
	return {}

func get_max_level(item_id: String) -> int:
	var item := get_item(item_id)
	if item.is_empty():
		return 0
	if item.has("costs"):
		return (item["costs"] as Array).size()
	if item.get("category") == "consumable":
		return MAX_STOCKPILED_STOCKS if item_id == "consumable_stock" else 1
	return 1

## Owned level for an id (0 = locked). The base ship is always owned.
## Consumables report their stockpiled count instead of an unlock level.
func get_level(item_id: String) -> int:
	if item_id == DEFAULT_SHIP:
		return 1
	if item_id == "consumable_stock":
		return consumable_stocks
	if item_id == "consumable_powerup":
		return 1 if consumable_powerup_armed else 0
	return int(unlock_levels.get(item_id, 0))

func is_unlocked(item_id: String) -> bool:
	return get_level(item_id) > 0

## Salvage cost of the next level, or -1 when maxed / unknown.
func get_next_cost(item_id: String) -> int:
	var item := get_item(item_id)
	if item.is_empty():
		return -1
	var level := get_level(item_id)
	if item.has("costs"):
		var costs: Array = item["costs"]
		if level >= costs.size():
			return -1
		return int(costs[level])
	if level >= get_max_level(item_id):
		return -1
	return int(item.get("cost", -1))

# --- Purchases ---

## True when the item exists, has a level left to buy, and the wallet covers it.
func can_purchase(item_id: String) -> bool:
	var cost := get_next_cost(item_id)
	return cost >= 0 and salvage >= cost

## Buys the next level of an item: deducts the cost, records the new level,
## persists, and emits unlock_purchased. Consumables increment their
## stockpile instead of unlock_levels. Returns false if not allowed.
func purchase(item_id: String) -> bool:
	if not can_purchase(item_id):
		return false
	var new_level := get_level(item_id) + 1
	salvage -= get_next_cost(item_id)
	match item_id:
		"consumable_stock":
			consumable_stocks = mini(consumable_stocks + 1, MAX_STOCKPILED_STOCKS)
		"consumable_powerup":
			consumable_powerup_armed = true
		_:
			unlock_levels[item_id] = new_level
	_persist()
	salvage_changed.emit(salvage)
	unlock_purchased.emit(item_id, new_level)
	return true

# --- Consumables (consumed by GameManager.start_game()) ---

## Returns the stockpiled try-again stocks and zeroes the stockpile.
func consume_stockpile() -> int:
	var count := consumable_stocks
	if count > 0:
		consumable_stocks = 0
		_persist()
	return count

## Returns true (once) when a pre-loaded drop pod was armed for this run.
func consume_powerup_pod() -> bool:
	var armed := consumable_powerup_armed
	if armed:
		consumable_powerup_armed = false
		_persist()
	return armed

# --- First-clear milestones ---

## Awards every unclaimed first-clear milestone up to waves_cleared, marks
## them claimed, persists, and returns the total bonus (0 when nothing new).
## Flat awards — intentionally not affected by the run's modifier multiplier.
func claim_first_clear_milestones(waves_cleared: int) -> int:
	var total := 0
	for wave: Variant in FIRST_CLEAR_MILESTONES:
		var milestone_wave := int(wave)
		if waves_cleared >= milestone_wave and not claimed_milestones.has(milestone_wave):
			claimed_milestones.append(milestone_wave)
			total += int(FIRST_CLEAR_MILESTONES[wave])
	if total > 0:
		_persist()
	return total

# --- Lifetime stats ---

## Records one finished run: bumps run/kill totals and the best-wave record.
## Sets last_run_set_best_wave for the game-over screen.
func record_run_stats(wave_reached: int, kills: int) -> void:
	stat_total_runs += 1
	stat_total_kills += maxi(kills, 0)
	last_run_set_best_wave = wave_reached > stat_best_wave
	stat_best_wave = maxi(stat_best_wave, wave_reached)
	_persist()

# --- Salvage conversion ---

## Converts an end-of-run score into salvage with diminishing returns, so
## deep combo runs earn more but bosses stay the primary salvage source.
func score_to_salvage(run_score: int) -> int:
	return roundi(sqrt(float(maxi(run_score, 0)) / SALVAGE_SCORE_SQRT_DIVISOR))

# --- Run loadout (ship variant + challenge modifiers) ---

## Selects the ship variant used for future runs. Locked ships are ignored.
func select_ship(ship_id: String) -> void:
	if not is_unlocked(ship_id):
		return
	selected_ship = ship_id
	_persist()

## Returns the stat profile of the currently selected ship.
func get_selected_ship_profile() -> Dictionary:
	for ship in SHIP_VARIANTS:
		if ship["id"] == selected_ship:
			return ship["profile"]
	return SHIP_VARIANTS[0]["profile"]

## Toggles a challenge modifier for future runs. Locked modifiers are ignored.
func set_modifier_active(modifier_id: String, active: bool) -> void:
	if active and not is_unlocked(modifier_id):
		return
	if active and not active_modifiers.has(modifier_id):
		active_modifiers.append(modifier_id)
	elif not active:
		active_modifiers.erase(modifier_id)
	else:
		return
	_persist()

func is_modifier_active(modifier_id: String) -> bool:
	return active_modifiers.has(modifier_id) and is_unlocked(modifier_id)

## Total salvage multiplier from active modifiers (1.0 = no bonus).
func get_salvage_multiplier() -> float:
	var multiplier := 1.0
	for modifier in CHALLENGE_MODIFIERS:
		if is_modifier_active(str(modifier["id"])):
			multiplier += float(modifier["bonus_pct"])
	return multiplier

## Drops selections that reference locked or unknown ids (e.g. after a
## hand-edited save or a catalog change).
func _sanitize_selections() -> void:
	if not is_unlocked(selected_ship):
		selected_ship = DEFAULT_SHIP
	for i in range(active_modifiers.size() - 1, -1, -1):
		if not is_unlocked(active_modifiers[i]):
			active_modifiers.remove_at(i)
	for i in range(claimed_milestones.size() - 1, -1, -1):
		if not FIRST_CLEAR_MILESTONES.has(claimed_milestones[i]):
			claimed_milestones.remove_at(i)

func _persist() -> void:
	SaveManager.save_meta({
		"salvage": salvage,
		"unlock_levels": unlock_levels,
		"selected_ship": selected_ship,
		"active_modifiers": active_modifiers,
		"consumable_stocks": consumable_stocks,
		"consumable_powerup": consumable_powerup_armed,
		"claimed_milestones": claimed_milestones,
		"stat_total_runs": stat_total_runs,
		"stat_total_kills": stat_total_kills,
		"stat_best_wave": stat_best_wave,
	})
