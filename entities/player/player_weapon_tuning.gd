extends RefCounted
class_name PlayerWeaponTuning
## Spatially independent base-weapon tuning shared with the 2D reference.
## Pixel distances and speeds use the baseline viewport's coordinate system.

const BASE_FIRE_INTERVAL := 0.22
const BASE_DAMAGE := 1
# A deliberate defensive conversion should have a distinct offensive payoff.
const REFLECTED_DAMAGE := 2
const MIN_FIRE_INTERVAL := 0.05
const RAPID_FIRE_MULTIPLIER := 2.0
const OVERCLOCK_MULTIPLIER := 2.0
const MAX_TEMPORARY_FIRE_MULTIPLIER := 3.0
const PROJECTILE_SPEED := 800.0
const MUZZLE_CLEARANCE := 3.0


static func fire_interval(base_interval: float, frequency_bonus: float, rapid: bool, overclock: bool) -> float:
	var temporary_multiplier := 1.0
	if rapid:
		temporary_multiplier *= RAPID_FIRE_MULTIPLIER
	if overclock:
		temporary_multiplier *= OVERCLOCK_MULTIPLIER
	temporary_multiplier = minf(temporary_multiplier, MAX_TEMPORARY_FIRE_MULTIPLIER)
	return maxf(base_interval / (maxf(0.1, 1.0 + frequency_bonus) * temporary_multiplier), MIN_FIRE_INTERVAL)
