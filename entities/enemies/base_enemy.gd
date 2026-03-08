extends Area2D
class_name BaseEnemy
## Base class for all enemies. Handles health, movement, and death.

@export var max_health: int = 1
@export var speed: float = 150.0
@export var points: int = 100
@export var xp_value: int = -1  # -1 means "use points value"

const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb.tscn")

var health: int

func _ready() -> void:
	add_to_group("enemies")
	# Scale health with player level: each level adds 30% of base HP (rounded up)
	var level_bonus := (GameManager.level - 1) * ceili(max_health * 0.3)
	health = max_health + level_bonus
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	if not GameManager.is_game_active:
		return
	_move(delta)

func _move(delta: float) -> void:
	position.y += speed * GameManager.enemy_speed_multiplier * delta

func take_damage(amount: int) -> void:
	health -= amount
	# Flash white on hit
	if health > 0:
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.05)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	else:
		_die()

func _die() -> void:
	SignalBus.enemy_killed.emit(points, global_position)
	# Spawn XP orb (60% chance, but guaranteed if xp_value was explicitly set)
	var guaranteed_drop := xp_value >= 0
	if guaranteed_drop or randf() < 0.6:
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position
		orb.xp_value = points if xp_value < 0 else xp_value
		get_tree().current_scene.add_child(orb)
	# Spawn explosion effect
	var explosion_scene := preload("res://effects/explosion.tscn")
	var explosion := explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	if area.is_in_group("player"):
		# Ram into player — self-destruct without emitting kill points
		_die()
	elif area.collision_layer & 4:  # layer 3 = player_bullets (bitmask 4)
		# Bullet hit — take 1 damage; the bullet handles its own queue_free
		take_damage(1)

func _on_screen_exited() -> void:
	# Only free if past the bottom of the screen
	if global_position.y > 0:
		queue_free()
