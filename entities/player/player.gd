extends Area2D
## Player ship — handles movement, shooting, power-ups, and taking damage.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")

@export var speed: float = 280.0
@export var base_fire_rate: float = 0.22  # seconds between shots

# Power-up state (temporary)
var current_scale_level: int = 0  # 0 = normal, up to 3 (bullet size)
var bullet_scale_level: int = 0
var has_shield: bool = false
var has_rapid_fire: bool = false
var has_spread_shot: bool = false
var has_magnet: bool = false
var is_invincible: bool = false
var dev_god_mode: bool = false

# RPG permanent upgrades (persist for the run)
var has_rear_gun: bool = false
var has_piercing: bool = false
var has_orbitals: bool = false
var has_explosive_rounds: bool = false
var zigzag_stacks: int = 0  # 0 = off, 1-3+ = increasing amplitude
var orbital_angle: float = 0.0
var orbital_nodes: Array[Node2D] = []

# Elite (wave-10 boss) upgrades
var has_twin_cannons: bool = false
var has_auto_aim: bool = false
var has_drone: bool = false
var has_afterburner: bool = false
var drone_node: Area2D = null
var drone_shoot_timer: float = 0.0
const DRONE_FIRE_RATE: float = 0.65

# New elite upgrades
var has_spread_shot_elite: bool = false   # Permanent 3-way spread (stacks with twin_cannons → 5 shots)
var has_shield_burst: bool = false         # Periodic bullet-clearing shockwave
var has_magnet_field: bool = false         # Permanent orb/powerup magnet (faster pull than temp)
var has_overclock: bool = false            # Active: triple fire rate for 2.5 s, 16 s cooldown
var has_rear_gunner: bool = false          # Permanent rear-facing cannon (inherits all _spawn_bullet modifiers)

var shield_burst_cooldown: float = 0.0
const SHIELD_BURST_PERIOD: float = 10.0

var overclock_cooldown: float = 0.0
var overclock_active: bool = false
var overclock_timer: float = 0.0
const OVERCLOCK_DURATION: float = 2.5
const OVERCLOCK_COOLDOWN: float = 16.0

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

# --- Free Aim ---
var last_aim_direction: Vector2 = Vector2.UP
var is_using_free_aim: bool = false
@onready var reticle: Node2D = null

# --- Boost ---
var is_boosting: bool = false
var boost_cooldown_timer: float = 0.0
var boost_duration_timer: float = 0.0
var boost_reflected_projectiles: int = 0
var afterimage_spawn_timer: float = 0.0
const AF_SPAWN_LIMIT: float = 0.04
const BOOST_MULTIPLIER: float = 3.5
const BOOST_DURATION: float = 0.68
const BOOST_COOLDOWN: float = 0.85
const BOOST_REFLECT_COOLDOWN: float = 0.35
const BOOST_REFLECT_COOLDOWN_STEP: float = 0.08
const BOOST_REFLECT_COOLDOWN_MIN: float = 0.10
const BOOST_DEFLECT_RADIUS: float = 74.0
const POST_BOOST_SLIDE_DURATION: float = 0.4
const DRIFT_STEER_INFLUENCE: float = 0.65

# --- Drift Params ---
var drift_speed_bonus: float = 1.0
var post_boost_slide_timer: float = 0.0
const DRIFT_BONUS_MAX: float = 2.0
const DRIFT_BONUS_RATE: float = 0.45
const DRIFT_DECAY_RATE: float = 0.8
const DRIFT_DRAG_BASE: float = 1.6
const DRIFT_ACCEL_BASE: float = 2.4

# Movement feel
@export var acceleration: float = 12.0   # how fast we reach top speed
@export var drag: float = 14.0          # how fast we decelerate (higher = tighter/snappier stop)

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

	# Initialize reticle
	_setup_reticle()

func _setup_reticle() -> void:
	reticle = Node2D.new()
	add_child(reticle)

	# Crosshair reticle using the themed cursor asset
	var dot := Sprite2D.new()
	dot.texture = load("res://assets/ui/cursor_crosshair.png")
	dot.scale = Vector2(0.375, 0.375)  # scale 64px asset down to ~24px
	dot.modulate = Color(0.38, 0.88, 1.0, 0.9)  # neon cyan tint to match HUD
	reticle.add_child(dot)
	dot.position = Vector2(0, -60) # distance from player
	reticle.visible = false # hide until free aim is used


func _get_sprite_frame_size() -> Vector2:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return Vector2(48.0, 48.0)
	var frame_w := sprite.texture.get_size().x / float(max(sprite.hframes, 1))
	var frame_h := sprite.texture.get_size().y / float(max(sprite.vframes, 1))
	return Vector2(frame_w, frame_h)

func _physics_process(delta: float) -> void:
	if not GameManager.is_game_active:
		return

	# --- Movement with dampening ---
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var effective_speed := speed * (1.0 + GameManager.bonus_speed_pct) * drift_speed_bonus
	var current_accel := acceleration
	var current_drag := drag
	
	if is_boosting or post_boost_slide_timer > 0.0:
		if is_boosting:
			effective_speed *= BOOST_MULTIPLIER
		
		# Curvature: Blend movement input with aim direction
		if input_dir.length() > 0.0:
			input_dir = input_dir.lerp(last_aim_direction, DRIFT_STEER_INFLUENCE).normalized()
		elif is_boosting:
			# If no movement input, drift slightly in aim direction anyway
			input_dir = last_aim_direction * 0.4
		
		# Reduced friction window (boosting OR post-boost slide)
		current_accel = DRIFT_ACCEL_BASE
		current_drag = DRIFT_DRAG_BASE
		
		# Scale based on current speed ratio
		var speed_ratio = clampf(velocity.length() / (speed * 2.5), 0.0, 1.0)
		current_drag *= lerpf(1.0, 0.15, speed_ratio)
		current_accel *= lerpf(1.0, 0.4, speed_ratio)
		
		# Handle slide timer
		if not is_boosting:
			post_boost_slide_timer -= delta
		
		# --- Braking Logic ---
		if input_dir.length() > 0.1 and velocity.length() > 100.0:
			var dot = input_dir.dot(velocity.normalized())
			if dot < -0.7:
				# Opposite input! Apply heavy braking
				current_drag = 22.0
				current_accel = 2.0 # Heavy to reverse
				drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, 5.0 * delta)
				# Visual feedback: flash red/orange — only write RGB so alpha (invincibility blink) is preserved
				sprite.modulate.r = 1.8
				sprite.modulate.g = 0.7
				sprite.modulate.b = 0.5

	if input_dir.length() > 0.0:
		# Accelerate toward target velocity
		var target_velocity := input_dir * effective_speed
		velocity = velocity.lerp(target_velocity, current_accel * delta)
	else:
		# Apply drag when no input (slide to stop)
		velocity = velocity.lerp(Vector2.ZERO, current_drag * delta)

	position += velocity * delta

	# Refresh bounds every frame so they match actual window size
	viewport_rect = get_viewport().get_visible_rect()

	# Clamp to viewport using the displayed frame size, not the full strip texture.
	var sprite_frame_size := _get_sprite_frame_size()
	var half_w: float = 0.5 * sprite_frame_size.x * scale.x * sprite.scale.x
	var half_h: float = 0.5 * sprite_frame_size.y * scale.y * sprite.scale.y
	position.x = clampf(position.x, half_w, viewport_rect.size.x - half_w)
	position.y = clampf(position.y, half_h, viewport_rect.size.y - half_h)

	# --- Boost Logic ---
	_update_boost(delta)

	# --- Aiming ---
	_update_aiming(delta)

	# --- Auto-fire ---
	if Input.is_action_pressed("shoot") and can_shoot:
		# Apply fire-rate bonus from leveling
		var effective_rate: float
		if has_rapid_fire or overclock_active:
			var rate_factor := 0.4
			if has_rapid_fire and overclock_active:
				rate_factor = 0.15  # stacking: rapid fire + overclock = ultra fast
			effective_rate = base_fire_rate * rate_factor * maxf(1.0 - GameManager.bonus_fire_rate_pct, 0.15)
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

	# --- Drone ---
	if has_drone:
		_update_drone(delta)

	# --- Shield Burst cooldown ---
	if has_shield_burst:
		shield_burst_cooldown -= delta
		if shield_burst_cooldown <= 0.0:
			shield_burst_cooldown = SHIELD_BURST_PERIOD
			_trigger_shield_burst()

	# --- Overclock cooldown / active timer ---
	if has_overclock:
		if overclock_active:
			overclock_timer -= delta
			if overclock_timer <= 0.0:
				overclock_active = false
				overclock_cooldown = OVERCLOCK_COOLDOWN
		else:
			overclock_cooldown -= delta
			if overclock_cooldown <= 0.0:
				overclock_active = true
				overclock_timer = OVERCLOCK_DURATION
				_flash_overclock()

	# --- Permanent magnet field ---
	if has_magnet_field and not has_magnet:
		_attract_powerups_fast(delta)

func _update_boost(delta: float) -> void:
	if is_boosting:
		boost_duration_timer -= delta
		_deflect_nearby_projectiles()
		
		# --- Speed Gain while drifting ---
		drift_speed_bonus = move_toward(drift_speed_bonus, DRIFT_BONUS_MAX, DRIFT_BONUS_RATE * delta)
		# Visual tint for high speed
		if drift_speed_bonus > 1.2:
			var t = (drift_speed_bonus - 1.0) / (DRIFT_BONUS_MAX - 1.0)
			# Only write RGB — leave alpha alone so invincibility blink isn't interrupted
			sprite.modulate.r = 1.0 + t * 0.5
			sprite.modulate.g = 1.0 + t * 0.5
			sprite.modulate.b = 1.0 + t * 1.5

		# --- Afterimages ---
		afterimage_spawn_timer -= delta
		if afterimage_spawn_timer <= 0.0:
			afterimage_spawn_timer = AF_SPAWN_LIMIT
			_spawn_afterimage()

		if boost_duration_timer <= 0.0:
			is_boosting = false
			boost_cooldown_timer = _get_boost_cooldown()
			post_boost_slide_timer = POST_BOOST_SLIDE_DURATION
	else:
		# Decay bonus when not boosting/drifting
		drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, DRIFT_DECAY_RATE * delta)
		if drift_speed_bonus <= 1.05 and not dev_god_mode:
			# Only reset RGB — leave alpha alone so invincibility blink isn't interrupted
			sprite.modulate.r = 1.0
			sprite.modulate.g = 1.0
			sprite.modulate.b = 1.0

		if boost_cooldown_timer > 0.0:
			boost_cooldown_timer -= delta
		
		if Input.is_action_just_pressed("boost") and boost_cooldown_timer <= 0.0:
			is_boosting = true
			boost_duration_timer = BOOST_DURATION
			boost_reflected_projectiles = 0
			afterimage_spawn_timer = 0.0 # spawn immediately
			# Visual feedback


func _deflect_nearby_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(projectile):
			continue
		if global_position.distance_squared_to(projectile.global_position) > BOOST_DEFLECT_RADIUS * BOOST_DEFLECT_RADIUS:
			continue
		_try_deflect_projectile(projectile)


func _try_deflect_projectile(projectile: Area2D) -> void:
	if projectile.has_method("deflect") and projectile.deflect(global_position, velocity):
		register_boost_reflection()


func register_boost_reflection() -> void:
	if is_boosting:
		boost_reflected_projectiles += 1


func _get_boost_cooldown() -> float:
	if boost_reflected_projectiles <= 0:
		return BOOST_COOLDOWN
	var additional_reflects := boost_reflected_projectiles - 1
	return maxf(
		BOOST_REFLECT_COOLDOWN - float(additional_reflects) * BOOST_REFLECT_COOLDOWN_STEP,
		BOOST_REFLECT_COOLDOWN_MIN
	)


func _spawn_afterimage() -> void:
	var af := Sprite2D.new()
	# Use current sprite configuration
	af.texture = sprite.texture
	af.hframes = sprite.hframes
	af.vframes = sprite.vframes
	af.frame = sprite.frame
	af.global_position = global_position
	af.rotation = rotation
	af.scale = scale * sprite.scale
	af.modulate = Color(0.4, 0.7, 1.0, 0.6) # blue ghost tint
	af.z_index = -1 # Draw behind player

	# Parent into the dedicated AfterimageContainer so adding/removing these sprites
	# doesn't mutate the root scene tree and invalidate star-field draw calls (flicker fix).
	var containers := get_tree().get_nodes_in_group("afterimage_container")
	var parent: Node = containers[0] if not containers.is_empty() else get_tree().current_scene
	parent.add_child(af)

	var tween := af.create_tween()
	tween.tween_property(af, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(af, "scale", scale * sprite.scale * 0.8, 0.35)
	tween.tween_callback(af.queue_free)

func _update_aiming(_delta: float) -> void:
	# 1. Controller Right Stick
	var joy_dir := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if joy_dir.length() > 0.4:
		last_aim_direction = joy_dir.normalized()
		is_using_free_aim = true
	
	# 2. Mouse (if moved or button pressed)
	var mouse_pos := get_global_mouse_position()
	var to_mouse := (mouse_pos - global_position).normalized()
	# Only use mouse if it's far enough away or moving, to avoid jitter
	if (mouse_pos - global_position).length() > 30.0:
		if Input.get_last_mouse_velocity().length() > 10.0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			last_aim_direction = to_mouse
			is_using_free_aim = true
			
	if is_using_free_aim:
		reticle.visible = true
		rotation = last_aim_direction.angle() + PI/2.0

func _fire() -> void:
	can_shoot = false
	shoot_timer.start()

	# Main fire direction
	var aim_dir = last_aim_direction
	var side_offset = aim_dir.rotated(PI/2.0) # perpendicular vector for parallel bullets

	if has_spread_shot or has_spread_shot_elite:
		_spawn_bullet(aim_dir)
		_spawn_bullet(aim_dir.rotated(deg_to_rad(-25)))
		_spawn_bullet(aim_dir.rotated(deg_to_rad(25)))
		if has_twin_cannons:
			# Twin cannons add 2 parallel bullets
			_spawn_bullet(aim_dir.rotated(deg_to_rad(-12)), side_offset * -18)
			_spawn_bullet(aim_dir.rotated(deg_to_rad(12)), side_offset * 18)
	else:
		_spawn_bullet(aim_dir)
		if has_twin_cannons:
			_spawn_bullet(aim_dir, side_offset * -14)
			_spawn_bullet(aim_dir, side_offset * 14)

	# Rear gunner logic
	if has_rear_gun or has_rear_gunner:
		var back_dir = -aim_dir
		if has_spread_shot or has_spread_shot_elite:
			_spawn_bullet(back_dir, Vector2.ZERO, true)
			_spawn_bullet(back_dir.rotated(deg_to_rad(-25)), Vector2.ZERO, true)
			_spawn_bullet(back_dir.rotated(deg_to_rad(25)), Vector2.ZERO, true)
			if has_twin_cannons:
				_spawn_bullet(back_dir.rotated(deg_to_rad(-12)), side_offset * 18, true)
				_spawn_bullet(back_dir.rotated(deg_to_rad(12)), side_offset * -18, true)
		else:
			_spawn_bullet(back_dir, Vector2.ZERO, true)
			if has_twin_cannons:
				_spawn_bullet(back_dir, side_offset * 14, true)
				_spawn_bullet(back_dir, side_offset * -14, true)

func _spawn_bullet(dir: Vector2, offset: Vector2 = Vector2.ZERO, skip_auto_aim: bool = false) -> void:
	var bullet: Area2D = BULLET_SCENE.instantiate()
	# Auto-aim: nudge direction toward nearest enemy (skipped for rear-facing bullets)
	if has_auto_aim and not skip_auto_aim:
		var enemies := get_tree().get_nodes_in_group("enemies")
		var best_dist := INF
		var best_enemy: Node2D = null
		for e in enemies:
			if is_instance_valid(e):
				var d: float = global_position.distance_to(e.global_position)
				if d < best_dist:
					best_dist = d
					best_enemy = e
		if best_enemy and best_dist < 500.0:
			var aim_dir := (best_enemy.global_position - global_position).normalized()
			dir = dir.lerp(aim_dir, 0.35).normalized()
	bullet.direction = dir
	# Offset along the barrel/direction
	var sprite_frame_size := _get_sprite_frame_size()
	var dist_offset = dir * 0.5 * sprite_frame_size.y * scale.y * sprite.scale.y
	bullet.global_position = global_position + dist_offset + offset
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

var respawn_invincibility: float = 3.0

func _on_area_entered(area: Area2D) -> void:
	if not GameManager.is_game_active:
		return
	if is_invincible or dev_god_mode:
		return
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		respawn_invincibility = 3.0
		_take_hit()
	elif area.is_in_group("enemy_bullets"):
		if is_boosting:
			_try_deflect_projectile(area)
			return
		respawn_invincibility = 2.0
		_take_hit()

func _take_hit() -> void:
	if has_shield:
		has_shield = false
		shield_sprite.visible = false
		_start_invincibility(1.5)
		return

	SignalBus.player_hit.emit()
	# Only grant invincibility if the player still has lives left after the hit
	if GameManager.lives > 0:
		_start_invincibility(1.5)

func _start_invincibility(duration: float = 1.5) -> void:
	is_invincible = true
	invincibility_timer.wait_time = duration
	invincibility_timer.start()
	# Flash effect
	var loops = int(duration / 0.24)
	var tween := create_tween()
	tween.set_loops(loops)
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
	get_tree().call_group("enemies", "take_damage", 9999)
	get_tree().call_group("tempest_sections", "take_damage", 9999)

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
	# Reset elite upgrades
	has_twin_cannons = false
	has_auto_aim = false
	has_afterburner = false
	_remove_drone()
	# Reset new elite upgrades
	has_spread_shot_elite = false
	has_shield_burst = false
	shield_burst_cooldown = 0.0
	has_magnet_field = false
	has_overclock = false
	overclock_active = false
	overclock_cooldown = 0.0
	overclock_timer = 0.0
	has_rear_gunner = false

	# Reset free aim
	last_aim_direction = Vector2.UP
	is_using_free_aim = false
	if is_instance_valid(reticle):
		reticle.visible = false

	# Reset boost
	is_boosting = false
	boost_cooldown_timer = 0.0
	boost_duration_timer = 0.0
	boost_reflected_projectiles = 0
	drift_speed_bonus = 1.0
	post_boost_slide_timer = 0.0
	sprite.modulate = Color.WHITE

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
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		area.take_damage(1 + GameManager.bonus_damage)

func _remove_orbitals() -> void:
	has_orbitals = false
	orbital_angle = 0.0
	for node in orbital_nodes:
		if is_instance_valid(node):
			node.queue_free()
	orbital_nodes.clear()

# --- Elite Upgrades ---

func grant_twin_cannons() -> void:
	has_twin_cannons = true

func grant_auto_aim() -> void:
	has_auto_aim = true

func grant_afterburner() -> void:
	has_afterburner = true
	speed = speed * 1.20
	acceleration = acceleration * 1.15

func grant_hull_plating() -> void:
	GameManager.lives += 1
	SignalBus.lives_changed.emit(GameManager.lives)

# --- New Elite Upgrades ---

func grant_spread_shot_elite() -> void:
	## Permanent 3-way spread. Stacks with twin_cannons (→ 5 bullets), auto_aim, piercing, explosive, zigzag.
	has_spread_shot_elite = true

func grant_shield_burst() -> void:
	## Periodic bullet-clearing shockwave every 10 s. Independent of all fire upgrades.
	has_shield_burst = true
	shield_burst_cooldown = SHIELD_BURST_PERIOD  # first burst after first full cycle

func grant_magnet_field() -> void:
	## Permanent magnetic pull on orbs/powerups — faster than the temp powerup.
	has_magnet_field = true

func grant_overclock() -> void:
	## Triple fire rate for 2.5 s every 16 s. Stacks with rapid-fire powerups.
	## Also stacks with twin_cannons and spread_shot (more bullets per burst).
	has_overclock = true
	overclock_cooldown = 3.0  # first overclock triggers soon after upgrade

func grant_rear_gunner() -> void:
	## Backward-facing cannon. Inherits piercing, explosive, zigzag from _spawn_bullet.
	## Auto-aim is intentionally skipped so it doesn't curve bullets away from threats above.
	has_rear_gunner = true

# --- Shield Burst implementation ---

func _trigger_shield_burst() -> void:
	## Destroy all enemy bullets within a large radius; deal 1 damage to nearby enemies.
	var burst_radius := 160.0
	# Destroy nearby enemy bullets
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b) and global_position.distance_to(b.global_position) < burst_radius:
			b.queue_free()
	# Damage enemies and exposed boss systems caught in the burst.
	var targets := get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("tempest_sections")
	for e in targets:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) < burst_radius:
			e.take_damage(1 + GameManager.bonus_damage)
	# Visual flash ring
	_spawn_burst_ring(burst_radius)

func _spawn_burst_ring(radius: float) -> void:
	var ring := Node2D.new()
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(radius / 40.0, radius / 40.0), 0.35)\
		.from(Vector2.ONE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(ring.queue_free)
	# Draw a simple ring using a canvas draw pass on a custom node
	var spr := Sprite2D.new()
	var img := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(80):
			var d := Vector2(float(x) - 40.0, float(y) - 40.0).length()
			if d >= 36.0 and d <= 40.0:
				img.set_pixel(x, y, Color(0.4, 0.9, 1.0, 0.85))
	spr.texture = ImageTexture.create_from_image(img)
	ring.add_child(spr)

func _flash_overclock() -> void:
	## Brief visual cue when Overclock activates.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.7, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _attract_powerups_fast(delta: float) -> void:
	## Faster pull than the temp magnet powerup (500 px/s vs 350 px/s).
	var powerups := get_tree().get_nodes_in_group("powerups")
	for pu in powerups:
		if is_instance_valid(pu):
			var dir: Vector2 = (global_position - pu.global_position).normalized()
			pu.global_position += dir * 500.0 * delta
	var orbs := get_tree().get_nodes_in_group("xp_orbs")
	for orb in orbs:
		if is_instance_valid(orb):
			var dir: Vector2 = (global_position - orb.global_position).normalized()
			orb.global_position += dir * 500.0 * delta


func grant_drone_escort() -> void:
	if has_drone:
		return
	has_drone = true
	_spawn_drone()

func _spawn_drone() -> void:
	if is_instance_valid(drone_node):
		drone_node.queue_free()
	drone_node = Area2D.new()
	drone_node.collision_layer = 4   # player_bullets
	drone_node.collision_mask = 2    # enemies
	drone_node.add_to_group("player_orbitals")
	# Sprite
	var spr := Sprite2D.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBAF)
	img.fill(Color.TRANSPARENT)
	for py in range(16):
		for px in range(16):
			var d := Vector2(float(px) - 7.5, float(py) - 7.5).length()
			if d < 7.5:
				var t := d / 7.5
				img.set_pixel(px, py, Color(0.3, 1.0, 0.6, 1.0 - t * 0.5))
	spr.texture = ImageTexture.create_from_image(img)
	drone_node.add_child(spr)
	# Label
	var lbl := Label.new()
	lbl.text = "▶"
	lbl.position = Vector2(-6, -8)
	lbl.add_theme_font_size_override("font_size", 10)
	drone_node.add_child(lbl)
	# Collision
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 7.0
	col.shape = circ
	drone_node.add_child(col)
	drone_node.area_entered.connect(_on_drone_hit)
	get_tree().current_scene.add_child(drone_node)

func _update_drone(delta: float) -> void:

	if not is_instance_valid(drone_node):
		return
	# Hover to the right of the player
	var target_pos := global_position + Vector2(50, -20)
	drone_node.global_position = drone_node.global_position.lerp(target_pos, delta * 6.0)
	# Auto-fire at nearest enemy
	drone_shoot_timer -= delta
	if drone_shoot_timer <= 0.0:
		drone_shoot_timer = DRONE_FIRE_RATE
		_drone_fire()

func _drone_fire() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_dist := INF
	var best_enemy: Node2D = null
	for e in enemies:
		if is_instance_valid(e):
			var d: float = drone_node.global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best_enemy = e
	var dir := Vector2.UP
	if best_enemy:
		dir = (best_enemy.global_position - drone_node.global_position).normalized()
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.direction = dir
	bullet.global_position = drone_node.global_position
	if has_piercing:
		bullet.piercing = true
	get_tree().current_scene.add_child(bullet)

func _on_drone_hit(area: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		area.take_damage(1 + GameManager.bonus_damage)

func _remove_drone() -> void:
	has_drone = false
	drone_shoot_timer = 0.0
	if is_instance_valid(drone_node):
		drone_node.queue_free()
	drone_node = null
