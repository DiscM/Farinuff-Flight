extends Node
class_name EnemyAbility
## Generation gate and explicit host binding shared by authored ability nodes.

@export var ability_id: StringName
@export_range(1, 4, 1) var minimum_generation: int = 1

var enemy_host: BaseEnemy
var enabled: bool = false


func bind(host: BaseEnemy, generation: int) -> void:
	enemy_host = host
	enabled = generation >= minimum_generation
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
