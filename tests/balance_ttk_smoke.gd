extends Node
## Headless balance lock: asserts every enemy generation and boss variant
## dies in the intended number of standard bullet hits (1 + bonus_damage,
## bonus 0). Guards the 2026-07 retune, which halved all base HP to
## preserve the original hits-to-kill after the double-damage fix.
##
## Run with:
## godot --headless --path . res://tests/balance_ttk_smoke.tscn
## (Run the .tscn wrapper, not --script: --script mode skips the autoloads
## these tests depend on and never exits.)

const ENEMY_SCENES: Dictionary = {
	&"basic": preload("res://entities/enemies/basic_enemy.tscn"),
	&"fast": preload("res://entities/enemies/fast_enemy.tscn"),
	&"bomber": preload("res://entities/enemies/bomber_enemy.tscn"),
	&"sniper": preload("res://entities/enemies/sniper_enemy.tscn"),
	&"tank": preload("res://entities/enemies/tank_enemy.tscn"),
}
const BOSS_SCENE := preload("res://entities/enemies/boss_enemy.tscn")

## Expected hits-to-kill per generation (waves 1–5, 6–10, 11–15, 16+).
const EXPECTED_TTK: Dictionary = {
	&"basic": [1, 1, 2, 2],
	&"fast": [1, 1, 1, 1],
	&"bomber": [1, 2, 2, 3],
	&"sniper": [2, 2, 3, 3],
	&"tank": [8, 9, 11, 13],
}

## Expected boss hits-to-kill at wave 1: regular variants, elite, tempest core.
const EXPECTED_BOSS_TTK := [23, 31, 26, 63, 150]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_wave: int = GameManager.current_wave
	var original_override: int = GameManager.dev_enemy_generation_override
	GameManager.current_wave = 1
	GameManager.dev_enemy_generation_override = 0

	_check_regular_enemies()
	await get_tree().process_frame
	_check_boss_variants()
	await get_tree().process_frame

	GameManager.current_wave = original_wave
	GameManager.dev_enemy_generation_override = original_override

	if _failures.is_empty():
		print("PASS: balance TTK smoke tests")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_regular_enemies() -> void:
	for archetype in ENEMY_SCENES:
		for generation in range(1, 5):
			var enemy: Node = (ENEMY_SCENES[archetype] as PackedScene).instantiate()
			enemy.generation = generation
			add_child(enemy)
			var expected: int = EXPECTED_TTK[archetype][generation - 1]
			var label := "%s Gen %d" % [archetype, generation]
			_expect(
				enemy.max_health == expected,
				"%s: max_health %d != expected %d" % [label, enemy.max_health, expected]
			)
			_expect(
				_hits_to_kill(enemy.health) == expected,
				"%s: dies in %d hits, expected %d" % [label, _hits_to_kill(enemy.health), expected]
			)
			enemy.queue_free()


func _check_boss_variants() -> void:
	# forced_variant values: 0 = ASSAULT, 1 = BULWARK, 2 = TEMPEST (BossEnemy.BossVariant)
	var configs := [
		{"forced_variant": 0, "is_elite": false, "is_tempest_core": false, "name": "Assault Wing"},
		{"forced_variant": 1, "is_elite": false, "is_tempest_core": false, "name": "Bulwark Array"},
		{"forced_variant": 2, "is_elite": false, "is_tempest_core": false, "name": "Tempest Fork"},
		{"forced_variant": -1, "is_elite": true, "is_tempest_core": false, "name": "Elite Void Harbinger"},
		{"forced_variant": -1, "is_elite": false, "is_tempest_core": true, "name": "Tempest Core"},
	]
	for i in range(configs.size()):
		var cfg: Dictionary = configs[i]
		var boss: BossEnemy = BOSS_SCENE.instantiate()
		if int(cfg["forced_variant"]) >= 0:
			boss.forced_variant = int(cfg["forced_variant"])
		boss.is_elite = bool(cfg["is_elite"])
		boss.is_tempest_core = bool(cfg["is_tempest_core"])
		add_child(boss)
		var expected: int = EXPECTED_BOSS_TTK[i]
		_expect(
			_hits_to_kill(boss.health) == expected,
			"%s: dies in %d hits, expected %d" % [cfg["name"], _hits_to_kill(boss.health), expected]
		)
		boss.queue_free()


## Simulated hits to kill with a standard bullet (1 + bonus_damage, bonus 0).
func _hits_to_kill(hp: int) -> int:
	var damage := 1 + GameManager.bonus_damage
	return ceili(float(hp) / float(damage))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
