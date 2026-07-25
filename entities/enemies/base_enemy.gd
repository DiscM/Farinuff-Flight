extends Area2D
class_name BaseEnemy
## Base class for all enemies. Handles health, movement, and death.

@export var max_health: int = 1
@export var speed: float = 150.0
@export var points: int = 100
@export var orb_value: int = 1
@export var guaranteed_orb: bool = false
var health_scale_multiplier: float = 1.0
var uses_wave_health_scaling: bool = false
var rewards_enabled: bool = true
var is_regular_enemy: bool = true
var suppress_death_effects: bool = false
var generation: int = 0
var archetype_id: StringName = &"basic"
var visible_time: float = 0.0
var special_attack_coordinator: SpecialAttackCoordinator
var evolution_stage: EnemyEvolutionStage
var _dying: bool = false

const HEALTH_SCALE_PER_WAVE: float = 0.045
const SCORE_MULTIPLIERS := [1.0, 1.5, 2.25, 3.25]

const XP_ORB_SCENE := preload("res://entities/collectibles/xp_orb.tscn")
const EXPLOSION_SCENE := preload("res://effects/explosion.tscn")

var health: int
## The normalized direction this enemy travels. Set by the spawner before adding to scene.
var spawn_direction: Vector2 = Vector2.DOWN
@onready var visual_root: Node2D = get_node_or_null("VisualRoot") as Node2D
@onready var sprite: Sprite2D = get_node_or_null("VisualRoot/Sprite2D") as Sprite2D
@onready var evolution: EnemyEvolutionController = get_node_or_null("VisualRoot/Evolution") as EnemyEvolutionController
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

## Initializes the enemy: adds to the "enemies" group, scales max_health by
## wave progression, sets current health, connects collision handling, attaches
## a screen-exit notifier, and starts a looping squash-and-stretch tween on the sprite.
func _ready() -> void:
	add_to_group("enemies")
	if is_regular_enemy:
		add_to_group("regular_enemies")
	if generation <= 0:
		generation = GameManager.get_enemy_generation()
	generation = clampi(generation, 1, 4)
	if is_regular_enemy and evolution != null:
		evolution_stage = evolution.apply_generation(self, generation)
	if is_regular_enemy:
		points = roundi(float(points) * SCORE_MULTIPLIERS[generation - 1])
	if special_attack_coordinator == null:
		special_attack_coordinator = SpecialAttackCoordinator.new()
		special_attack_coordinator.name = "LocalSpecialAttackCoordinator"
		add_child(special_attack_coordinator)
	if is_regular_enemy:
		for child in get_node_or_null("Abilities").get_children() if get_node_or_null("Abilities") != null else []:
			if child is EnemyAbility:
				(child as EnemyAbility).bind(self, generation)
	# Scale from the full accumulated percentage so low-HP ships do not gain 1 HP every wave.
	var wave_bonus := 0
	if uses_wave_health_scaling:
		wave_bonus = ceili(float(max_health) * float(GameManager.current_wave - 1) * HEALTH_SCALE_PER_WAVE * health_scale_multiplier)
	health = max_health + wave_bonus
	area_entered.connect(_on_area_entered)

	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)

	# Dynamic procedural tween animation for "breathing" or wobble
	if visual_root:
		var tw := create_tween().set_loops()
		# Slight squash and stretch
		tw.tween_property(visual_root, "scale", Vector2(1.05, 0.95), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(visual_root, "scale", Vector2(0.95, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
	rotation = spawn_direction.angle() + PI * 0.5

## Called every physics frame. Delegates to _move() if the game is active.
func _physics_process(delta: float) -> void:
	if not GameManager.is_game_active:
		return
	if visible_time >= 0.0 and get_viewport_rect().has_point(global_position):
		visible_time += delta
	_move(delta)

## Default movement: moves straight along spawn_direction at speed,
## scaled by the global enemy_speed_multiplier. Override in subclasses
## for custom movement patterns.
func _move(delta: float) -> void:
	position += spawn_direction * speed * delta

## Reduces health by the given amount. Plays a white flash hit effect
## if the enemy survives; calls _die() if health drops to 0 or below.
func take_damage(amount: int) -> void:
	if _dying:
		return
	health -= amount
	# Flash white on hit
	if health > 0:
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.05)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	else:
		_die()

## Handles enemy death: emits the kill signal with points and position,
## spawns an XP orb (60% chance, or guaranteed), spawns an explosion
## effect, and frees the node (all deferred to avoid mid-signal issues).
func _die(award_rewards: bool = true) -> void:
	if _dying or is_queued_for_deletion():
		return
	_dying = true
	special_attack_coordinator.release_major(self)
	var scene_root := get_tree().current_scene
	if award_rewards and rewards_enabled:
		SignalBus.enemy_killed.emit(points, global_position)
	# Spawn XP orb (60% chance, but guaranteed if guaranteed_orb is true).
	if award_rewards and rewards_enabled and (guaranteed_orb or randf() < 0.6):
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position
		orb.orb_value = orb_value
		scene_root.call_deferred("add_child", orb)
	# Spawn explosion effect
	var explosion = ObjectPool.acquire(EXPLOSION_SCENE, scene_root)
	if explosion != null and explosion.has_method("play_at"):
		explosion.scale = Vector2.ONE * (0.86 + float(generation) * 0.14)
		explosion.modulate = [
			Color(1.0, 0.88, 0.55),
			Color(1.0, 0.66, 0.22),
			Color(1.0, 0.28, 0.22),
			Color(1.0, 0.12, 0.8),
		][generation - 1]
		explosion.play_at(global_position)
	call_deferred("_finish_death")


func _finish_death() -> void:
	queue_free()

## Handles collisions with other Area2D nodes. If the collider is the
## player, the enemy self-destructs via _die(). If it's a player bullet
## (collision layer 4), takes 1 damage.
func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	if area.is_in_group("player"):
		# Ram into player — self-destruct without emitting kill points
		_die(false)
	elif area.collision_layer & 4 != 0:  # layer 3 = player_bullets (bitmask 4)
		# Bullet hit — take 1 damage; the bullet handles its own queue_free
		take_damage(1)

## Called when the enemy leaves the visible screen. Only frees the enemy
## if it has moved past the edge it was heading toward (prevents premature
## cleanup when enemies spawn just off-screen).
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


func can_begin_special() -> bool:
	return visible_time >= 0.35 and get_viewport_rect().has_point(global_position) and not _dying


func get_origin(origin_name: StringName) -> Vector2:
	if evolution == null:
		return global_position
	var marker := evolution.get_active_origin(origin_name)
	return marker.global_position if marker != null else global_position


func make_line_warning(direction: Vector2, length: float, color: Color, width: float = 3.0) -> Line2D:
	var line := Line2D.new()
	line.name = "AttackWarning"
	line.width = width
	line.default_color = color
	var local_direction := direction.normalized().rotated(-global_rotation)
	line.points = PackedVector2Array([Vector2.ZERO, local_direction * length])
	line.z_index = 20
	add_child(line)
	return line


func make_ring_warning(radius: float, color: Color, width: float = 3.0) -> Line2D:
	var ring := Line2D.new()
	ring.name = "AttackWarning"
	ring.width = width
	ring.default_color = color
	ring.closed = true
	var ring_points := PackedVector2Array()
	for i in range(33):
		var angle := TAU * float(i) / 32.0
		ring_points.append(Vector2.from_angle(angle) * radius)
	ring.points = ring_points
	ring.z_index = 20
	add_child(ring)
	return ring


func _on_screen_entered() -> void:
	if visible_time < 0.0:
		visible_time = 0.0


func dev_trigger_ability() -> void:
	pass
