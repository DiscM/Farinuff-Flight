extends RefCounted
class_name EnemyProjectileTuning
## Authored speeds are baseline screen pixels per second. The enemy firing
## entry point applies the global multiplier once, preserving slow/fast ratios.

const DEFAULT_SPEED := 400.0
const SPEED_MULTIPLIER := 1.3
## Apply after an attack's warning; keeps authored slow/fast ratios intact.
const TELEGRAPH_SPEED_MULTIPLIER := 2.25
const SLOW_SPEED := 180.0
const FAST_SPEED := 380.0
const DEFLECT_SPEED_MULTIPLIER := 1.35
const DEFLECT_MIN_SPEED := 560.0
const DEFLECT_VELOCITY_BIAS := 0.32
