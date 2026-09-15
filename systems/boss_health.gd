extends Node
class_name BossHealth
## Owns HP and phase boundaries independently of movement and attack execution.
signal changed(current: int, maximum: int)
signal phase_changed(phase: int)
signal died
var maximum := 1
var current := 1
var phase := 0
var phase_two_threshold := 0.6
var phase_three_threshold := 0.3

func configure(hp: int, phase_two: float, phase_three: float) -> void:
	maximum = maxi(1, hp)
	current = maximum
	phase = 0
	phase_two_threshold = clampf(phase_two, 0.02, 0.99)
	phase_three_threshold = clampf(phase_three, 0.01, phase_two_threshold - 0.01)

func apply_damage(amount: int) -> int:
	if current <= 0 or amount <= 0:
		return 0
	var applied := mini(current, amount)
	current -= applied
	changed.emit(current, maximum)
	if current == 0:
		died.emit() # Death wins over a simultaneous phase crossing.
		return applied
	var fraction := float(current) / maximum
	var next := 2 if fraction < phase_three_threshold else 1 if fraction <= phase_two_threshold else 0
	if next > phase:
		phase = next
		phase_changed.emit(phase) # Large hits go directly to the final phase.
	return applied
