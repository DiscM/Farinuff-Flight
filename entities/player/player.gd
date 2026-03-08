extends Area2D
## Player ship — handles movement, shooting, power-ups, and taking damage.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

@export var speed: float = 450.0
@export var base_fire_rate: float = 0.22  # seconds between shots

# Power-up state (temporary)
var current_scale_level: int = 0  # 0 = normal, up to 3 (bullet size)
var bullet_scale_level: int = 0
var has_shield: bool = false
var has_rapid_fire: bool = false
var has_spread_shot: bool = false
var has_magnet: bool = false
var is_invincible: bool = false

# RPG permanent upgrades (persist for the run)
var has_rear_gun: bool = false
var has_piercing: bool = false
var has_orbitals: bool = false
var has_explosive_rounds: bool = false
var zigzag_stacks: int = 0  # 0 = off, 1-3+ = increasing amplitude
var orbital_angle: float = 0.0
var orbital_nodes: Array[Node2D] = []

@onready var shoot_timer: Timer = $ShootTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var rapid_fire_timer: Timer = $RapidFireTimer
@onready var spread_shot_timer: Timer = $SpreadShotTimer
@onready var magnet_timer: Timer = $MagnetTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var shield_sprite: Sprite2D = $ShieldSprite

var can_shoot: bool = true
var viewport_rect: Rect2
var velocity: Vector2 = Vector2.ZERO

# Movement feel
@export var acceleration: float = 12.0  # how fast we reach top speed
@export var drag: float = 8.0           # how fast we decelerate (lower = more slide)

func _ready() -> void:
	add_to_group("player")
	# viewport_rect will be refreshed each frame

	shoot_timer.wait_time = base_fire_rate
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	invincibility_timer.wait_time = 1.5
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_ended)

	rapid_fire_timer.wait_time = 8.0
	rapid_fire_timer.one_shot = true
	rapid_fire_timer.timeout.connect(_on_rapid_fire_ended)

	spread_shot_timer.wait_time = 8.0
	spread_shot_timer.one_shot = true
	spread_shot_timer.timeout.connect(_on_spread_shot_ended)

	magnet_timer.wait_time = 10.0
	magnet_timer.one_shot = true
	magnet_timer.timeout.connect(_on_magnet_ended)

	area_entered.connect(_on_area_entered)
	SignalBus.power_up_collected.connect(_on_power_up_collected)
	shield_sprite.visible = false

func _physics_process(delta: float) -> void:
	if not GameManager.is_game_active:
		return

	# --- Movement with dampening ---
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var effective_speed := speed * (1.0 + GameManager.bonus_speed_pct)

	if input_dir.length() > 0.0:
		# Accelerate toward target velocity
		var target_velocity := input_dir * effective_speed
		velocity = velocity.lerp(target_velocity, acceleration * delta)
	else:
		# Apply drag when no input (slide to stop)
		velocity = velocity.lerp(Vector2.ZERO, drag * delta)

	position += velocity * delta

	# Refresh bounds every frame so they match actual window size
	viewport_rect = get_viewport().get_visible_rect()

	# Clamp to viewport (account for scale)
	# Sprite image is 48px wide, 48px tall — half in each axis
	var half_w: float = 24.0 * scale.x
	var half_h: float = 24.0 * scale.y
	position.x = clampf(position.x, half_w, viewport_rect.size.x - half_w)
	position.y = clampf(position.y, half_h, viewport_rect.size.y - half_h)

	# --- Auto-fire ---
	if Input.is_action_pressed("shoot") and can_shoot:
		# Apply fire-rate bonus from leveling
		var effective_rate: float
		if has_rapid_fire:
			effective_rate = base_fire_rate * 0.4 * maxf(1.0 - GameManager.bonus_fire_rate_pct, 0.15)
		else:
			effective_rate = base_fire_rate * maxf(1.0 - GameManager.bonus_fire_rate_pct, 0.15)
		shoot_timer.wait_time = maxf(effective_rate, 0.05)
		_fire()

	# --- Magnet: attract power-ups ---
	if has_magnet:
		_attract_powerups(delta)

	# --- Orbitals ---
	if has_orbitals:
		_update_orbitals(delta)

func _fire() -> void:
	can_shoot = false
	shoot_timer.start()

	if has_spread_shot:
		_spawn_bullet(Vector2.UP)
		_spawn_bullet(Vector2(-0.3, -0.95).normalized())
		_spawn_bullet(Vector2(0.3, -0.95).normalized())
	else:
		_spawn_bullet(Vector2.UP)

	# Rear gun fires backward
	if has_rear_gun:
		_spawn_bullet(Vector2.DOWN)

func _spawn_bullet(dir: Vector2) -> void:
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.direction = dir
	var offset_y := -24.0 * scale.y if dir.y < 0 else 24.0 * scale.y
	bullet.global_position = global_position + Vector2(0, offset_y)
	# Apply bullet scale upgrade
	if bullet_scale_level > 0:
		var bs := 1.0 + bullet_scale_level * 0.5
		bullet.scale = Vector2(bs, bs)
	# Apply piercing
	if has_piercing:
		bullet.piercing = true
	# Apply explosive rounds
	if has_explosive_rounds:
		bullet.explosive = true
	# Apply zigzag
	if zigzag_stacks > 0:
		bullet.zigzag = true
		bullet.zigzag_stacks = zigzag_stacks
	get_tree().current_scene.add_child(bullet)

func _on_shoot_timer_timeout() -> void:
	can_shoot = true

# --- Taking damage ---

func _on_area_entered(area: Area2D) -> void:
	if not GameManager.is_game_active:
		return
	if is_invincible:
		return
	if area.is_in_group("enemies") or area.is_in_group("enemy_bullets"):
		_take_hit()

func _take_hit() -> void:
	if has_shield:
		has_shield = false
		shield_sprite.visible = false
		_start_invincibility()
		return

	SignalBus.player_hit.emit()
	if GameManager.lives > 0:
		_start_invincibility()

func _start_invincibility() -> void:
	is_invincible = true
	invincibility_timer.start()
	# Flash effect
	var tween := create_tween()
	tween.set_loops(6)
	tween.tween_property(sprite, "modulate:a", 0.2, 0.12)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.12)

func _on_invincibility_ended() -> void:
	is_invincible = false
	sprite.modulate.a = 1.0

# --- Power-ups ---
# Power-up types: 0=SCALE_UP, 1=RAPID_FIRE, 2=SHIELD, 3=SPREAD_SHOT, 4=MAGNET, 5=NUKE

func _on_power_up_collected(type: int, _pos: Vector2) -> void:
	match type:
		0:  # SCALE_UP
			_apply_scale_up()
		1:  # RAPID_FIRE
			_apply_rapid_fire()
		2:  # SHIELD
			_apply_shield()
		3:  # SPREAD_SHOT
			_apply_spread_shot()
		4:  # MAGNET
			_apply_magnet()
		5:  # NUKE
			_apply_nuke()

func _apply_scale_up() -> void:
	if bullet_scale_level < 3:
		bullet_scale_level += 1
		current_scale_level = bullet_scale_level
		# Brief flash on the player to indicate the upgrade
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.2, 0.8, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _apply_rapid_fire() -> void:
	has_rapid_fire = true
	shoot_timer.wait_time = base_fire_rate * 0.4
	rapid_fire_timer.start()

func _on_rapid_fire_ended() -> void:
	has_rapid_fire = false
	shoot_timer.wait_time = base_fire_rate

func _apply_shield() -> void:
	has_shield = true
	shield_sprite.visible = true

func _apply_spread_shot() -> void:
	has_spread_shot = true
	spread_shot_timer.start()

func _on_spread_shot_ended() -> void:
	has_spread_shot = false

func _apply_magnet() -> void:
	has_magnet = true
	magnet_timer.start()

func _on_magnet_ended() -> void:
	has_magnet = false

func _apply_nuke() -> void:
	SignalBus.screen_shake.emit(12.0, 0.5)
	get_tree().call_group("enemies", "take_damage", 9999)

func _attract_powerups(delta: float) -> void:
	var powerups := get_tree().get_nodes_in_group("powerups")
	for pu in powerups:
		if is_instance_valid(pu):
			var dir: Vector2 = (global_position - pu.global_position).normalized()
			pu.global_position += dir * 350.0 * delta
	# Also attract XP orbs
	var orbs := get_tree().get_nodes_in_group("xp_orbs")
	for orb in orbs:
		if is_instance_valid(orb):
			var dir: Vector2 = (global_position - orb.global_position).normalized()
			orb.global_position += dir * 350.0 * delta

func reset_state() -> void:
	current_scale_level = 0
	bullet_scale_level = 0
	has_shield = false
	has_rapid_fire = false
	has_spread_shot = false
	has_magnet = false
	is_invincible = false
	scale = Vector2.ONE
	shoot_timer.wait_time = base_fire_rate
	shield_sprite.visible = false
	sprite.modulate.a = 1.0
	# Reset RPG permanent upgrades
	has_rear_gun = false
	has_piercing = false
	has_explosive_rounds = false
	zigzag_stacks = 0
	_remove_orbitals()

## Called by level-up popup for shield upgrade
func grant_shield() -> void:
	_apply_shield()

## Called by level-up popup for extended magnet upgrade
func grant_magnet_extended() -> void:
	has_magnet = true
	magnet_timer.wait_time = 15.0
	magnet_timer.start()

# --- RPG Permanent Upgrades ---

func grant_rear_gun() -> void:
	has_rear_gun = true

func grant_piercing() -> void:
	has_piercing = true

func grant_explosive_rounds() -> void:
	has_explosive_rounds = true

func grant_zigzag() -> void:
	zigzag_stacks = mini(zigzag_stacks + 1, 10)

func grant_orbitals() -> void:
	if has_orbitals:
		return  # Already active
	has_orbitals = true
	_spawn_orbitals()

func _spawn_orbitals() -> void:
	for node in orbital_nodes:
		if is_instance_valid(node):
			node.queue_free()
	orbital_nodes.clear()
	var count := 3
	for i in range(count):
		var orb_node := Area2D.new()
		orb_node.collision_layer = 4  # player_bullets layer
		orb_node.collision_mask = 2   # enemies layer
		orb_node.add_to_group("player_orbitals")
		# Visual — small glowing circle
		var spr := Sprite2D.new()
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for y in range(12):
			for x in range(12):
				var dist := Vector2(float(x) - 6.0, float(y) - 6.0).length()
				if dist < 5.0:
					var t := dist / 5.0
					spr.modulate = Color(0.4, 1.0, 0.9)
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 - t * 0.4))
		spr.texture = ImageTexture.create_from_image(img)
		orb_node.add_child(spr)
		# Collision
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		orb_node.add_child(shape)
		# Damage on contact
		orb_node.area_entered.connect(_on_orbital_hit.bind(orb_node))
		get_tree().current_scene.add_child(orb_node)
		orbital_nodes.append(orb_node)

func _update_orbitals(delta: float) -> void:
	orbital_angle += delta * 3.0  # rotation speed
	var radius := 60.0
	var count := orbital_nodes.size()
	for i in range(count):
		if is_instance_valid(orbital_nodes[i]):
			var angle := orbital_angle + (TAU / count) * i
			orbital_nodes[i].global_position = global_position + Vector2(cos(angle), sin(angle)) * radius

func _on_orbital_hit(area: Area2D, _orb: Area2D) -> void:
	if area.is_in_group("enemies"):
		area.take_damage(1 + GameManager.bonus_damage)

func _remove_orbitals() -> void:
	has_orbitals = false
	orbital_angle = 0.0
	for node in orbital_nodes:
		if is_instance_valid(node):
			node.queue_free()
	orbital_nodes.clear()
