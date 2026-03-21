extends Area2D
class_name BaseEnemy
## Base class for all enemies. Handles health, movement, and death.

@export var max_health: int = 1
@export var speed: float = 150.0
@export var points: int = 100
@export var orb_value: int = 1
@export var guaranteed_orb: bool = false

const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb.tscn")

var health: int

func _ready() -> void:
	add_to_group("enemies")
	# Scale health with wave: each wave adds 10% of base HP (rounded up)
	var wave_bonus := (GameManager.current_wave - 1) * ceili(max_health * 0.1)
	health = max_health + wave_bonus
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

	# Dynamic procedural tween animation for "breathing" or wobble
	var sprite := get_node_or_null("Sprite2D")
	if sprite:
		var tw := create_tween().set_loops()
		# Slight squash and stretch
		tw.tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sprite, "scale", Vector2(0.95, 1.05), 0.6).set_trans(Tween.TRANS_SINE)

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
	if is_queued_for_deletion():
		return
	SignalBus.enemy_killed.emit(points, global_position)
	# Spawn XP orb (60% chance, but guaranteed if guaranteed_orb is true)
	if guaranteed_orb or randf() < 0.6:
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position
		orb.orb_value = orb_value
		get_tree().current_scene.call_deferred("add_child", orb)
	# Spawn explosion effect
	var explosion_scene := preload("res://effects/explosion.tscn")
	var explosion := explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", explosion)
	call_deferred("queue_free")

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
