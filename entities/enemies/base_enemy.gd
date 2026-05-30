extends Area2D
class_name BaseEnemy
## Base class for all enemies. Handles health, movement, and death.

@export var max_health: int = 1
@export var speed: float = 150.0
@export var points: int = 100
@export var orb_value: int = 1
@export var guaranteed_orb: bool = false
var health_scale_multiplier: float = 1.0

const HEALTH_SCALE_PER_WAVE: float = 0.045

const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb.tscn")

var health: int
## The normalized direction this enemy travels. Set by the spawner before adding to scene.
var spawn_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("enemies")
	# Scale from the full accumulated percentage so low-HP ships do not gain 1 HP every wave.
	var wave_bonus := ceili(float(max_health) * float(GameManager.current_wave - 1) * HEALTH_SCALE_PER_WAVE * health_scale_multiplier)
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
	position += spawn_direction * speed * GameManager.enemy_speed_multiplier * delta

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
	# Free once the enemy has moved past the edge it's heading toward
	var vp := get_viewport_rect()
	var pos := global_position
	var past_edge := false
	if spawn_direction.y > 0.3 and pos.y > vp.size.y + 60:
		past_edge = true
	elif spawn_direction.y < -0.3 and pos.y < -60:
		past_edge = true
	elif spawn_direction.x > 0.3 and pos.x > vp.size.x + 60:
		past_edge = true
	elif spawn_direction.x < -0.3 and pos.x < -60:
		past_edge = true
	if past_edge:
		queue_free()
