extends Area2D
## Player ship — handles movement, shooting, power-ups, and taking damage.

const BULLET_SCENE := preload("res://entities/bullets/bullet.tscn")
const ShipCatalog := preload("res://effects/rendering/ship_render_catalog_3d.gd")
const PIXEL_ORBITAL_PROJECTILE_SHADER: Shader = preload("res://effects/shaders/projectiles/player_orbital.gdshader")
const VOXEL_ORBITAL_PROJECTILE_SHADER: Shader = preload("res://effects/shaders/projectiles/voxel_player_orbital.gdshader")
const ORBITAL_PROJECTILE_SHADER: Shader = PIXEL_ORBITAL_PROJECTILE_SHADER
const RETICLE_TEXTURE := preload("res://assets/ui/cursor_crosshair.png")
const PIXEL_EFFECT_SCENE := preload("res://effects/pixel_sprite_effect.tscn")
const FlightTuning := preload("res://entities/player/player_flight_tuning.gd")
const WeaponTuning := preload("res://entities/player/player_weapon_tuning.gd")

@export var speed: float = FlightTuning.SPEED
@export var base_fire_rate: float = WeaponTuning.BASE_FIRE_INTERVAL

# Power-up state (temporary)
var bullet_scale_level: int = 0  # 0 = normal, up to 3 (bullet size)
var has_shield: bool = false
var has_rapid_fire: bool = false
var has_spread_shot: bool = false
var has_magnet: bool = false
var is_invincible: bool = false
var dev_god_mode: bool = false
var dev_rapid_fire: bool = false
var dev_spread_shot: bool = false
var dev_orbitals: bool = false
var dev_piercing: bool = false
var dev_explosive_rounds: bool = false

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
var has_hull_plating: bool = false
var has_afterburner: bool = false
var active_elite_upgrade_ids: Array[String] = []
var drone_node: ShipDrone = null

static var _orbital_texture: Texture2D
static var _burst_ring_texture: Texture2D

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
@onready var upgrade_visuals_back: ShipUpgradeVisuals = $UpgradeVisualsBack
@onready var upgrade_visuals_front: ShipUpgradeVisuals = $UpgradeVisualsFront
@onready var afterimage_cache: ShipAfterimageCache = $AfterimageCache

var can_shoot: bool = true
var viewport_rect: Rect2
var sprite_frame_size: Vector2 = Vector2(48.0, 48.0)
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
var boost_direction: Vector2 = Vector2.UP
var boost_distance_remaining: float = 0.0
var boost_chain_window_timer: float = 0.0
var afterimage_spawn_timer: float = 0.0
const AF_SPAWN_LIMIT: float = 0.04
const BOOST_DURATION: float = FlightTuning.BOOST_DURATION
const BOOST_DISTANCE: float = FlightTuning.BOOST_DISTANCE
const BOOST_STEER_RATE: float = FlightTuning.BOOST_STEER_RATE
const BOOST_COOLDOWN: float = FlightTuning.BOOST_COOLDOWN
const BOOST_REFLECT_COOLDOWN: float = 0.35
const BOOST_REFLECT_COOLDOWN_STEP: float = 0.08
const BOOST_REFLECT_COOLDOWN_MIN: float = 0.10
const BOOST_CHAIN_REFLECT_THRESHOLD: int = 3
const BOOST_CHAIN_WINDOW: float = 0.18
const BOOST_DEFLECT_RADIUS: float = FlightTuning.BOOST_DEFLECT_RADIUS
const BOOST_DEFLECT_RADIUS_SQ: float = BOOST_DEFLECT_RADIUS * BOOST_DEFLECT_RADIUS
const POST_BOOST_SLIDE_DURATION: float = FlightTuning.POST_BOOST_SLIDE_DURATION

# --- Drift Params ---
var drift_speed_bonus: float = 1.0
var post_boost_slide_timer: float = 0.0
const DRIFT_BONUS_MAX: float = FlightTuning.DRIFT_BONUS_MAX
const DRIFT_BONUS_RATE: float = FlightTuning.DRIFT_BONUS_RATE
const DRIFT_DECAY_RATE: float = FlightTuning.DRIFT_DECAY_RATE
const DRIFT_DRAG_BASE: float = FlightTuning.DRIFT_DRAG_BASE
const DRIFT_ACCEL_BASE: float = FlightTuning.DRIFT_ACCEL_BASE

# Movement feel
@export var acceleration: float = FlightTuning.ACCELERATION   # how fast we reach top speed
@export var drag: float = FlightTuning.DRAG          # how fast we decelerate (higher = tighter/snappier stop)
var _base_speed_without_afterburner: float
var _base_acceleration_without_afterburner: float

## Initializes the player: adds to the "player" group, configures all
## timers (shoot, invincibility, rapid fire, spread shot, magnet) as
## one-shot timers with appropriate callbacks, connects collision and
## power-up signals, and sets up the aim reticle.
func _ready() -> void:
	add_to_group("player")
	# viewport_rect will be refreshed each frame
	_base_speed_without_afterburner = speed
	_base_acceleration_without_afterburner = acceleration

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
	sprite_frame_size = _get_sprite_frame_size()
	_sync_upgrade_visuals()

	# Initialize reticle
	_setup_reticle()

## Creates the aim reticle node with a crosshair sprite, positioned
## 60px above the player. Hidden by default until free-aim input is used.
func _setup_reticle() -> void:
	reticle = Node2D.new()
	add_child(reticle)

	# Crosshair reticle using the themed cursor asset
	var dot := Sprite2D.new()
	dot.texture = RETICLE_TEXTURE
	dot.scale = Vector2(0.375, 0.375)  # scale 64px asset down to ~24px
	dot.modulate = Color(0.38, 0.88, 1.0, 0.9)  # neon cyan tint to match HUD
	reticle.add_child(dot)
	dot.position = Vector2(0, -FlightTuning.AIM_RETICLE_DISTANCE)
	reticle.visible = false # hide until free aim is used


## Returns the size of a single animation frame from the sprite sheet,
## accounting for hframes/vframes. Falls back to 48×48 if no texture is set.
func _get_sprite_frame_size() -> Vector2:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return Vector2(48.0, 48.0)
	var frame_w := sprite.texture.get_size().x / float(max(sprite.hframes, 1))
	var frame_h := sprite.texture.get_size().y / float(max(sprite.vframes, 1))
	return Vector2(frame_w, frame_h)

## Main per-frame update. Handles: directional input with momentum-based
## movement (lerp acceleration/drag), boost dashing, post-boost drift with
## braking logic, viewport clamping, free-aim targeting (controller stick
## and mouse), auto-fire with rate modifiers, magnet attraction, orbital
## weapon rotation, drone escort updates, shield burst cooldowns, and
## overclock timing.
func _physics_process(delta: float) -> void:
	if not GameManager.is_game_active:
		return

	# --- Movement with dampening ---
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var effective_speed := speed * (1.0 + GameManager.bonus_speed_pct + GameManager.meta_speed_pct + GameManager.ship_speed_pct) * drift_speed_bonus
	var current_accel := acceleration
	var current_drag := drag
	
	if is_boosting:
		_steer_boost(input_dir, delta)
		var boost_speed := BOOST_DISTANCE / BOOST_DURATION
		var step_distance := minf(boost_speed * delta, boost_distance_remaining)
		velocity = boost_direction * boost_speed
		position += boost_direction * step_distance
		boost_distance_remaining -= step_distance
	elif post_boost_slide_timer > 0.0:
		# Preserve momentum briefly after the dash while returning full steering control.
		current_accel = DRIFT_ACCEL_BASE
		current_drag = DRIFT_DRAG_BASE
		
		# Scale based on current speed ratio
		var speed_ratio = clampf(velocity.length() / (speed * FlightTuning.DRIFT_SPEED_RATIO), 0.0, 1.0)
		current_drag *= lerpf(1.0, FlightTuning.DRIFT_MIN_DRAG_FACTOR, speed_ratio)
		current_accel *= lerpf(1.0, FlightTuning.DRIFT_MIN_ACCEL_FACTOR, speed_ratio)
		
		post_boost_slide_timer -= delta
		
		# --- Braking Logic ---
		if input_dir.length() > FlightTuning.BRAKE_INPUT_THRESHOLD and velocity.length() > FlightTuning.BRAKE_MIN_SPEED:
			var dot = input_dir.dot(velocity.normalized())
			if dot < FlightTuning.BRAKE_OPPOSITION_DOT:
				# Opposite input! Apply heavy braking
				current_drag = FlightTuning.BRAKE_DRAG
				current_accel = FlightTuning.BRAKE_ACCELERATION # Heavy to reverse
				drift_speed_bonus = move_toward(drift_speed_bonus, 1.0, FlightTuning.BRAKE_BONUS_DECAY * delta)
				# Visual feedback: flash red/orange — only write RGB so alpha (invincibility blink) is preserved
				sprite.modulate.r = 1.8
				sprite.modulate.g = 0.7
				sprite.modulate.b = 0.5

	if not is_boosting:
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
		if _rapid_fire_active() or overclock_active:
			var rate_factor := 0.4
			if _rapid_fire_active() and overclock_active:
				rate_factor = 0.15  # stacking: rapid fire + overclock = ultra fast
			effective_rate = base_fire_rate * rate_factor * maxf(1.0 - GameManager.bonus_fire_rate_pct - GameManager.meta_fire_rate_pct - GameManager.ship_fire_rate_pct, WeaponTuning.MIN_FIRE_RATE_MULTIPLIER)
		else:
			effective_rate = base_fire_rate * maxf(1.0 - GameManager.bonus_fire_rate_pct - GameManager.meta_fire_rate_pct - GameManager.ship_fire_rate_pct, WeaponTuning.MIN_FIRE_RATE_MULTIPLIER)
		shoot_timer.wait_time = maxf(effective_rate, WeaponTuning.MIN_FIRE_INTERVAL)
		_fire()

	# --- Magnet: attract power-ups ---
	if has_magnet:
		_attract_powerups(delta)

	# --- Orbitals ---
	if _orbitals_active():
		_update_orbitals(delta)

	# (The drone updates itself — see ShipDrone._physics_process.)

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
		_attract_powerups(delta, 500.0)

	_update_upgrade_visual_runtime(delta)

## Manages the boost state machine: during a boost, decrements the duration
## timer, deflects nearby projectiles, checks for chain boost triggers,
## accumulates drift speed bonus, spawns afterimages, and ends the boost
## when duration/distance expires. After boosting, handles the chain window
## and drift speed decay.
func _update_boost(delta: float) -> void:
	if is_boosting:
		boost_duration_timer -= delta
		_deflect_nearby_projectiles()
		if Input.is_action_just_pressed("boost") and _has_boost_chain():
			_begin_boost()
			return
		
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

		if boost_duration_timer <= 0.0 or boost_distance_remaining <= 0.0:
			is_boosting = false
			boost_distance_remaining = 0.0
			if _has_boost_chain():
				boost_chain_window_timer = BOOST_CHAIN_WINDOW
				boost_cooldown_timer = 0.0
			else:
				boost_cooldown_timer = _get_boost_cooldown()
			post_boost_slide_timer = POST_BOOST_SLIDE_DURATION
	else:
		if boost_chain_window_timer > 0.0:
			boost_chain_window_timer = maxf(boost_chain_window_timer - delta, 0.0)
			_deflect_nearby_projectiles()

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
			_begin_boost()


## Initiates a boost dash: sets the boost direction from current velocity
## (or UP if stationary), resets the distance budget and reflected count,
## and clears the chain window timer.
func _begin_boost() -> void:
	is_boosting = true
	boost_duration_timer = BOOST_DURATION
	boost_reflected_projectiles = 0
	boost_chain_window_timer = 0.0
	boost_direction = velocity.normalized() if velocity.length() > FlightTuning.BOOST_HEADING_MIN_SPEED else Vector2.UP
	boost_distance_remaining = BOOST_DISTANCE
	afterimage_spawn_timer = 0.0 # spawn immediately
	_spawn_warp_effect(global_position, boost_direction)
	AudioManager.play_boost()


## Adjusts the boost direction toward the player's input direction,
## allowing mid-boost steering. The steering weight is frame-rate
## independent via delta multiplication.
func _steer_boost(input_dir: Vector2, delta: float) -> void:
	if input_dir.is_zero_approx():
		return
	var steering_weight := clampf(BOOST_STEER_RATE * delta, 0.0, 1.0)
	boost_direction = boost_direction.lerp(input_dir.normalized(), steering_weight).normalized()


## Scans all enemy bullets within BOOST_DEFLECT_RADIUS and attempts to
## deflect each one. Called every frame during an active boost.
func _deflect_nearby_projectiles() -> void:
	var tree := get_tree()
	for projectile in tree.get_nodes_in_group("enemy_bullets"):
		if not is_instance_valid(projectile):
			continue
		if global_position.distance_squared_to(projectile.global_position) > BOOST_DEFLECT_RADIUS_SQ:
			continue
		_try_deflect_projectile(projectile)


## Attempts to deflect a single enemy bullet by calling its deflect()
## method, passing the player's position and velocity. If successful,
## registers the reflection for chain boost tracking.
func _try_deflect_projectile(projectile: Area2D) -> void:
	if projectile.has_method("deflect") and projectile.deflect(global_position, velocity):
		register_boost_reflection()


## Increments the boost reflection counter (only tracked while actively
## boosting). Used to determine chain boost eligibility.
func register_boost_reflection() -> void:
	if is_boosting:
		boost_reflected_projectiles += 1


## Returns true if the player has deflected enough projectiles during
## the current boost to earn a chain boost (instant follow-up dash).
func _has_boost_chain() -> bool:
	return boost_reflected_projectiles >= BOOST_CHAIN_REFLECT_THRESHOLD


## Returns true if the player is currently able to deflect incoming
## projectiles — either during an active boost or within the chain window.
func can_deflect_projectiles() -> bool:
	return is_boosting or boost_chain_window_timer > 0.0


## Calculates the boost cooldown based on how many projectiles were
## reflected. Base cooldown is reduced per reflection, with a minimum
## floor to prevent zero cooldowns.
func _get_boost_cooldown() -> float:
	if boost_reflected_projectiles <= 0:
		return BOOST_COOLDOWN
	var additional_reflects := boost_reflected_projectiles - 1
	return maxf(
		BOOST_REFLECT_COOLDOWN - float(additional_reflects) * BOOST_REFLECT_COOLDOWN_STEP,
		BOOST_REFLECT_COOLDOWN_MIN
	)


## Creates one translucent composite ghost containing the base sprite and
## every installed ship-mounted elite module. Transient flashes and the
## independent drone are intentionally omitted.
func _spawn_afterimage() -> void:
	var ship_renderer := get_tree().get_first_node_in_group(&"ship_render_layer_3d")
	if (
		ship_renderer != null
		and ship_renderer.has_method(&"get_visual_for")
		and ship_renderer.call(&"get_visual_for", self) != null
	):
		# The shared 3D renderer supplies continuous engine trails. Do not place
		# a baked legacy sprite over the 3D ship while boosting.
		return
	if afterimage_cache.texture == null:
		return
	var af := Sprite2D.new()
	af.texture = afterimage_cache.texture
	af.hframes = 4
	af.frame = clampi(sprite.frame, 0, 3)
	af.global_position = global_position
	af.rotation = rotation
	af.scale = scale * sprite.scale
	af.modulate = Color(0.4, 0.7, 1.0, 0.6) # blue ghost tint
	af.z_index = -1 # Draw behind player

	# Parent into the dedicated AfterimageContainer so adding/removing these sprites
	# doesn't mutate the root scene tree and invalidate star-field draw calls (flicker fix).
	var parent: Node = get_tree().get_first_node_in_group("afterimage_container")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(af)

	var tween := af.create_tween()
	tween.tween_property(af, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(af, "scale", scale * sprite.scale * 0.8, 0.35)
	tween.tween_callback(af.queue_free)

## Returns a direction vector toward the nearest enemy within the optional
## max_distance. Returns Vector2.ZERO when no valid target is found.
func _get_nearest_enemy_direction(origin: Vector2, max_distance: float = INF) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_dist := max_distance
	var best_enemy: Node2D = null
	for e in enemies:
		if is_instance_valid(e):
			var d: float = origin.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best_enemy = e
	if best_enemy:
		return (best_enemy.global_position - origin).normalized()
	return Vector2.ZERO

## Updates the aim direction based on controller right stick or mouse
## position. The reticle becomes visible and the ship rotates to face
## the aim direction once free-aim input is detected.
func _update_aiming(_delta: float) -> void:
	# 1. Controller Right Stick
	var joy_dir := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if joy_dir.length() > FlightTuning.AIM_STICK_DEADZONE:
		last_aim_direction = joy_dir.normalized()
		is_using_free_aim = true
	
	# 2. Mouse (if moved or button pressed)
	var mouse_pos := get_global_mouse_position()
	var to_mouse := (mouse_pos - global_position).normalized()
	# Only use mouse if it's far enough away or moving, to avoid jitter
	if (mouse_pos - global_position).length() > FlightTuning.AIM_MOUSE_MIN_DISTANCE:
		if Input.get_last_mouse_velocity().length() > FlightTuning.AIM_MOUSE_MIN_SPEED or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			last_aim_direction = to_mouse
			is_using_free_aim = true
			
	if is_using_free_aim:
		reticle.visible = true
		rotation = last_aim_direction.angle() + PI/2.0

## Fires bullets in the current aim direction. Handles spread shot (3-way
## fan), twin cannons (+2 parallel bullets), and rear gunner (mirror of
## forward pattern aimed backward). Starts the shoot cooldown timer.
func _fire() -> void:
	can_shoot = false
	shoot_timer.start()

	var aim_dir := last_aim_direction
	var auto_aim_dir := _get_nearest_enemy_direction(global_position, 500.0) if has_auto_aim else Vector2.ZERO
	var center_anchor := upgrade_visuals_front.get_player_local_muzzle("center")
	var spread_active := _spread_shot_active()

	if spread_active:
		var left_spread_anchor := upgrade_visuals_front.get_player_local_muzzle("spread_left") if has_spread_shot_elite else center_anchor
		var right_spread_anchor := upgrade_visuals_front.get_player_local_muzzle("spread_right") if has_spread_shot_elite else center_anchor
		_spawn_bullet(aim_dir, center_anchor, false, auto_aim_dir)
		_spawn_bullet(aim_dir.rotated(deg_to_rad(-25)), left_spread_anchor, false, auto_aim_dir)
		_spawn_bullet(aim_dir.rotated(deg_to_rad(25)), right_spread_anchor, false, auto_aim_dir)
		if has_twin_cannons:
			_spawn_bullet(
				aim_dir.rotated(deg_to_rad(-12)),
				upgrade_visuals_front.get_player_local_muzzle("twin_left"),
				false,
				auto_aim_dir
			)
			_spawn_bullet(
				aim_dir.rotated(deg_to_rad(12)),
				upgrade_visuals_front.get_player_local_muzzle("twin_right"),
				false,
				auto_aim_dir
			)
	else:
		_spawn_bullet(aim_dir, center_anchor, false, auto_aim_dir)
		if has_twin_cannons:
			_spawn_bullet(aim_dir, upgrade_visuals_front.get_player_local_muzzle("twin_left"), false, auto_aim_dir)
			_spawn_bullet(aim_dir, upgrade_visuals_front.get_player_local_muzzle("twin_right"), false, auto_aim_dir)

	# Rear gunner logic
	if has_rear_gun or has_rear_gunner:
		var back_dir := -aim_dir
		var rear_anchor := upgrade_visuals_front.get_player_local_muzzle("rear")
		if spread_active:
			_spawn_bullet(back_dir, rear_anchor, true, auto_aim_dir)
			_spawn_bullet(back_dir.rotated(deg_to_rad(-25)), rear_anchor, true, auto_aim_dir)
			_spawn_bullet(back_dir.rotated(deg_to_rad(25)), rear_anchor, true, auto_aim_dir)
			if has_twin_cannons:
				_spawn_bullet(back_dir.rotated(deg_to_rad(-12)), rear_anchor, true, auto_aim_dir)
				_spawn_bullet(back_dir.rotated(deg_to_rad(12)), rear_anchor, true, auto_aim_dir)
		else:
			_spawn_bullet(back_dir, rear_anchor, true, auto_aim_dir)
			if has_twin_cannons:
				_spawn_bullet(back_dir, rear_anchor, true, auto_aim_dir)
				_spawn_bullet(back_dir, rear_anchor, true, auto_aim_dir)

	if has_twin_cannons:
		upgrade_visuals_front.trigger_muzzle("twin_cannons")
	if has_spread_shot_elite:
		upgrade_visuals_front.trigger_muzzle("spread_shot_elite")
	if has_rear_gunner:
		upgrade_visuals_front.trigger_muzzle("rear_gunner")

## Instantiates and configures a single player bullet. Applies auto-aim
## nudge toward nearest enemy (skipped for rear bullets), positions the
## bullet at the ship's barrel, and applies all active modifiers: bullet
## scale, piercing, explosive, and zigzag.
func _spawn_bullet(
	dir: Vector2,
	local_muzzle: Vector2 = Vector2(0.0, -35.0),
	skip_auto_aim: bool = false,
	auto_aim_dir: Vector2 = Vector2.ZERO
) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bullet = ObjectPool.acquire(BULLET_SCENE, scene_root)
	if bullet == null:
		return
	# Auto-aim: nudge direction toward nearest enemy (skipped for rear-facing bullets)
	if has_auto_aim and not skip_auto_aim and not auto_aim_dir.is_zero_approx():
		dir = dir.lerp(auto_aim_dir, 0.35).normalized()
	# Apply bullet scale upgrade
	var bs := 1.0
	if bullet_scale_level > 0:
		bs = 1.0 + bullet_scale_level * 0.5
	var spawn_position := to_global(local_muzzle) + dir * WeaponTuning.MUZZLE_CLEARANCE
	bullet.pool_activate(
		spawn_position,
		dir,
		bs,
		_piercing_active(),
		_explosive_rounds_active(),
		zigzag_stacks
	)

## Re-enables shooting after the fire rate cooldown timer expires.
func _on_shoot_timer_timeout() -> void:
	can_shoot = true

# --- Taking damage ---

## Default post-hit invincibility (seconds), also used for try-again respawns.
const RESPAWN_INVINCIBILITY := 3.0
## Duration of the invincibility granted by the next hit. Set by the hit
## source just before _take_hit(): 3s for enemy contact, 2s for bullets and
## hostile ordnance.
var respawn_invincibility: float = RESPAWN_INVINCIBILITY

## Handles collision with enemies and enemy bullets. Ignores hits during
## invincibility or god mode. Enemy contact grants longer invincibility
## (3s) than bullet hits (2s). Attempts projectile deflection if boosting.
func _on_area_entered(area: Area2D) -> void:
	if not GameManager.is_game_active:
		return
	if is_invincible or dev_god_mode:
		return
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		respawn_invincibility = 3.0
		_take_hit()
	elif area.is_in_group("enemy_bullets"):
		if can_deflect_projectiles():
			_try_deflect_projectile(area)
			return
		respawn_invincibility = 2.0
		_take_hit()
	elif area.is_in_group("hostile_ordnance") or area.is_in_group("rail_beams"):
		if is_boosting and area.is_in_group("hostile_ordnance") and area.has_method("clear_ordnance"):
			area.clear_ordnance()
			return
		receive_hostile_hit(2.0)


func receive_hostile_hit(invincibility_duration: float = 2.0) -> void:
	if not GameManager.is_game_active or is_invincible or dev_god_mode:
		return
	respawn_invincibility = invincibility_duration
	_take_hit()

## Processes a damage hit. If a shield is active, consumes it instead of
## taking damage and grants brief invincibility. Otherwise, emits the
## player_hit signal (which triggers life loss in GameManager) and grants
## invincibility for respawn_invincibility seconds (set by the hit source:
## 3s for enemy contact, 2s for bullets/ordnance) if the player still has
## lives.
func _take_hit() -> void:
	if has_shield:
		has_shield = false
		shield_sprite.visible = false
		AudioManager.play_shield()
		_start_invincibility(1.5)
		return

	AudioManager.play_player_hit()
	# Decide invincibility BEFORE emitting: the hit costs a life, so grant it
	# only when at least one life remains after this one (lives > 1 now).
	# Checking before the emit keeps this independent of signal ordering.
	var survives_hit := GameManager.lives > 1
	SignalBus.player_hit.emit()
	if survives_hit:
		_start_invincibility(respawn_invincibility)

## Activates temporary invincibility for the given duration. Starts the
## invincibility timer and plays a repeating alpha blink animation on the
## sprite to visually indicate the immune state.
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

## Ends the invincibility period and restores full sprite opacity.
func _on_invincibility_ended() -> void:
	is_invincible = false
	sprite.modulate.a = 1.0

# --- Power-ups ---
# Types are the PowerUp.Type enum (entities/powerups/power_up.gd).

## Routes a collected power-up to the appropriate handler based on its type.
func _on_power_up_collected(type: int, pos: Vector2) -> void:
	_spawn_sparkle_effect(pos)
	AudioManager.play_powerup()
	match type:
		PowerUp.Type.SCALE_UP:
			_apply_scale_up()
		PowerUp.Type.RAPID_FIRE:
			_apply_rapid_fire()
		PowerUp.Type.SHIELD:
			_apply_shield()
		PowerUp.Type.SPREAD_SHOT:
			_apply_spread_shot()
		PowerUp.Type.MAGNET:
			_apply_magnet()
		PowerUp.Type.NUKE:
			_apply_nuke()

## Increments the bullet scale level (up to 3), increasing the visual size
## and hitbox of all fired bullets. Plays a brief cyan flash on the sprite.
func _apply_scale_up() -> void:
	if bullet_scale_level < 3:
		bullet_scale_level += 1
		# Brief flash on the player to indicate the upgrade
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.2, 0.8, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

## Activates rapid fire: reduces fire rate to 40% of base for 8 seconds.
## Restarts the timer if already active (extending the duration).
## The shoot cooldown itself is recomputed every frame in _physics_process,
## which honors rapid fire, overclock, and fire-rate bonuses together.
func _apply_rapid_fire() -> void:
	has_rapid_fire = true
	rapid_fire_timer.start()

## Deactivates the rapid fire power-up when its timer expires.
func _on_rapid_fire_ended() -> void:
	has_rapid_fire = false

## Activates the shield: absorbs one hit before the player takes damage.
## Shows the shield visual indicator.
func _apply_shield() -> void:
	has_shield = true
	shield_sprite.visible = true

## Activates the temporary spread shot power-up for 8 seconds: fires a
## 3-way fan of bullets instead of a single shot.
func _apply_spread_shot() -> void:
	has_spread_shot = true
	spread_shot_timer.start()

## Deactivates the temporary spread shot power-up when its timer expires.
func _on_spread_shot_ended() -> void:
	has_spread_shot = false

## Activates the magnet power-up for 10 seconds: attracts nearby
## power-ups and XP orbs toward the player.
func _apply_magnet() -> void:
	has_magnet = true
	magnet_timer.start()

## Deactivates the magnet power-up when its timer expires.
func _on_magnet_ended() -> void:
	has_magnet = false

## Activates a nuke: instantly kills all enemies and destroys all tempest
## sections on screen.
func _apply_nuke() -> void:
	get_tree().call_group("enemies", "take_damage", 9999)
	get_tree().call_group("tempest_sections", "take_damage", 9999)
	get_tree().call_group("hostile_ordnance", "clear_ordnance")

## Pulls all power-ups and XP orbs toward the player. Used by the temporary
## magnet power-up (350 px/s) and the permanent magnet field upgrade
## (500 px/s).
func _attract_powerups(delta: float, pull_speed: float = 350.0) -> void:
	var tree := get_tree()
	for group_name in ["powerups", "xp_orbs"]:
		for node in tree.get_nodes_in_group(group_name):
			if is_instance_valid(node):
				var dir: Vector2 = (global_position - node.global_position).normalized()
				node.global_position += dir * pull_speed * delta


# --- Canonical upgrade state ---

func get_active_elite_upgrade_ids() -> Array[String]:
	return active_elite_upgrade_ids.duplicate()


func is_elite_upgrade_enabled(upgrade_id: String) -> bool:
	return active_elite_upgrade_ids.has(upgrade_id)


func set_elite_upgrade_enabled(upgrade_id: String, enabled: bool, grant_one_time_reward: bool = false) -> void:
	var was_enabled := active_elite_upgrade_ids.has(upgrade_id)
	if was_enabled == enabled:
		return

	if enabled:
		active_elite_upgrade_ids.append(upgrade_id)
	else:
		active_elite_upgrade_ids.erase(upgrade_id)

	match upgrade_id:
		"twin_cannons":
			has_twin_cannons = enabled
		"auto_aim":
			has_auto_aim = enabled
		"drone_escort":
			if enabled:
				_spawn_drone()
			else:
				_remove_drone()
		"hull_plating":
			has_hull_plating = enabled
			if enabled and grant_one_time_reward:
				GameManager.lives += 1
				SignalBus.lives_changed.emit(GameManager.lives)
		"afterburner":
			has_afterburner = enabled
			_apply_afterburner_stats()
		"spread_shot_elite":
			has_spread_shot_elite = enabled
		"shield_burst":
			has_shield_burst = enabled
			shield_burst_cooldown = SHIELD_BURST_PERIOD if enabled else 0.0
		"magnet_field":
			has_magnet_field = enabled
		"overclock":
			has_overclock = enabled
			overclock_active = false
			overclock_timer = 0.0
			overclock_cooldown = 3.0 if enabled else 0.0
		"rear_gunner":
			has_rear_gunner = enabled
		# Meta-unlockable elites — they reuse the dormant RPG upgrade systems.
		"orbitals":
			if enabled:
				grant_orbitals()
			else:
				_remove_orbitals()
		"piercing":
			has_piercing = enabled
		"explosive_rounds":
			has_explosive_rounds = enabled
		_:
			if enabled:
				active_elite_upgrade_ids.erase(upgrade_id)
			return

	_sync_upgrade_visuals()


func clear_elite_upgrades() -> void:
	var installed := active_elite_upgrade_ids.duplicate()
	for id in installed:
		set_elite_upgrade_enabled(id, false)


func set_visual_debug(flag: String, enabled: bool) -> void:
	upgrade_visuals_front.set_debug_flag(flag, enabled)


func set_dev_god_mode(enabled: bool) -> void:
	dev_god_mode = enabled
	sprite.modulate = Color(1.2, 1.2, 0.2) if enabled else Color.WHITE


func set_dev_power_override(power_id: String, enabled: bool) -> void:
	match power_id:
		"rapid_fire":
			dev_rapid_fire = enabled
		"spread_shot":
			dev_spread_shot = enabled
		"orbitals":
			dev_orbitals = enabled
			if _orbitals_active():
				_ensure_orbitals()
			else:
				_clear_orbital_nodes()
		"piercing":
			dev_piercing = enabled
		"explosive_rounds":
			dev_explosive_rounds = enabled


func get_dev_power_override(power_id: String) -> bool:
	match power_id:
		"rapid_fire":
			return dev_rapid_fire
		"spread_shot":
			return dev_spread_shot
		"orbitals":
			return dev_orbitals
		"piercing":
			return dev_piercing
		"explosive_rounds":
			return dev_explosive_rounds
	return false


func _rapid_fire_active() -> bool:
	return has_rapid_fire or dev_rapid_fire


func _spread_shot_active() -> bool:
	return has_spread_shot or dev_spread_shot or has_spread_shot_elite


func _orbitals_active() -> bool:
	return has_orbitals or dev_orbitals


func _piercing_active() -> bool:
	return has_piercing or dev_piercing

## Public accessor for the piercing modifier, used by the drone escort's
## bullets to inherit piercing.
func is_piercing_active() -> bool:
	return _piercing_active()


func _explosive_rounds_active() -> bool:
	return has_explosive_rounds or dev_explosive_rounds


func _apply_afterburner_stats() -> void:
	speed = _base_speed_without_afterburner * (1.20 if has_afterburner else 1.0)
	acceleration = _base_acceleration_without_afterburner * (1.15 if has_afterburner else 1.0)


func _sync_upgrade_visuals() -> void:
	if is_instance_valid(upgrade_visuals_back):
		upgrade_visuals_back.set_active_upgrades(active_elite_upgrade_ids)
	if is_instance_valid(upgrade_visuals_front):
		upgrade_visuals_front.set_active_upgrades(active_elite_upgrade_ids)
	if is_instance_valid(afterimage_cache):
		afterimage_cache.rebuild(sprite.texture, active_elite_upgrade_ids)
	var ship_renderer := get_tree().get_first_node_in_group(&"ship_render_layer_3d")
	if (
		ship_renderer != null
		and ship_renderer.has_method(&"request_render_refresh")
	):
		ship_renderer.call(&"request_render_refresh")


## Cached results of the expensive visual scans (nearest enemy, group
## queries), refreshed at 10 Hz — plenty fast for indicator visuals.
var _visual_scan_timer: float = 0.0
var _cached_auto_dir: Vector2 = Vector2.ZERO
var _cached_magnet_active: bool = false
## Reused runtime-state dictionary (set_runtime_state copies per-key, so a
## fresh Dictionary per frame would be pure GC churn).
var _visual_state: Dictionary = {}

func _update_upgrade_visual_runtime(delta: float) -> void:
	if not is_instance_valid(upgrade_visuals_front):
		return
	_visual_scan_timer -= delta
	if _visual_scan_timer <= 0.0:
		_visual_scan_timer = 0.1
		_cached_auto_dir = _get_nearest_enemy_direction(global_position, 500.0) if has_auto_aim else Vector2.ZERO
		_cached_magnet_active = has_magnet_field and (
			not get_tree().get_nodes_in_group("xp_orbs").is_empty()
			or not get_tree().get_nodes_in_group("powerups").is_empty()
		)
	var auto_dir := _cached_auto_dir
	var local_auto_angle := 0.0
	if not auto_dir.is_zero_approx():
		local_auto_angle = auto_dir.rotated(-rotation).angle() + PI / 2.0
	var shield_charge := 0.0
	if has_shield_burst:
		shield_charge = 1.0 - clampf(shield_burst_cooldown / SHIELD_BURST_PERIOD, 0.0, 1.0)
	_visual_state["afterburner_boost"] = has_afterburner and is_boosting
	_visual_state["overclock_active"] = has_overclock and overclock_active
	_visual_state["overclock_phase"] = (
		1.0 - clampf(overclock_timer / OVERCLOCK_DURATION, 0.0, 1.0)
		if has_overclock and overclock_active else 0.0
	)
	_visual_state["shield_charge"] = shield_charge
	_visual_state["magnet_active"] = _cached_magnet_active
	_visual_state["auto_aim_angle"] = local_auto_angle
	_visual_state["auto_aim_locked"] = not auto_dir.is_zero_approx()
	upgrade_visuals_back.set_runtime_state(_visual_state)
	upgrade_visuals_front.set_runtime_state(_visual_state)

## Called by level-up popup for shield upgrade.
func grant_shield() -> void:
	_apply_shield()

## Called by level-up popup for extended magnet upgrade (15s duration
## instead of the default 10s).
func grant_magnet_extended() -> void:
	has_magnet = true
	magnet_timer.wait_time = 15.0
	magnet_timer.start()

# --- RPG Permanent Upgrades ---

## Grants the rear gun upgrade: fires bullets backward as well as forward.
func grant_rear_gun() -> void:
	has_rear_gun = true

## Grants the piercing upgrade: bullets pass through enemies instead of
## being destroyed on contact.
func grant_piercing() -> void:
	has_piercing = true

## Grants the explosive rounds upgrade: bullets deal area damage on impact.
func grant_explosive_rounds() -> void:
	has_explosive_rounds = true

## Grants one zigzag stack (up to 10): bullets oscillate perpendicular to
## their travel direction with increasing frequency and amplitude per stack.
func grant_zigzag() -> void:
	zigzag_stacks = mini(zigzag_stacks + 1, 10)

## Grants the orbital weapon upgrade: spawns 3 orbiting projectile nodes
## around the player that damage enemies on contact.
func grant_orbitals() -> void:
	if has_orbitals:
		return  # Already active
	has_orbitals = true
	_ensure_orbitals()


func _ensure_orbitals() -> void:
	if not orbital_nodes.is_empty():
		return
	_spawn_orbitals()

## Creates 3 orbital Area2D nodes with small glowing sprites, collision
## shapes, and damage-on-contact handlers, then adds them to the scene.
func _spawn_orbitals() -> void:
	for node in orbital_nodes:
		if is_instance_valid(node):
			node.queue_free()
	orbital_nodes.clear()
	var scene_root := get_tree().current_scene
	var count := 3
	for i in range(count):
		var orb_node := Area2D.new()
		orb_node.collision_layer = 4  # player_bullets layer
		orb_node.collision_mask = 2   # enemies layer
		orb_node.add_to_group("player_orbitals")
		# Visual — small glowing circle
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		var orbital_material := ShaderMaterial.new()
		var voxel_enabled := ShipCatalog.voxel_style_enabled()
		orbital_material.shader = (
			VOXEL_ORBITAL_PROJECTILE_SHADER if voxel_enabled else PIXEL_ORBITAL_PROJECTILE_SHADER
		)
		if voxel_enabled:
			orbital_material.set_shader_parameter(&"voxel_cell_scale", 8.0)
			orbital_material.set_shader_parameter(&"voxel_face_contrast", 0.14)
		orbital_material.set_shader_parameter(&"phase_offset", TAU * float(i) / float(count))
		spr.material = orbital_material
		spr.modulate = Color.WHITE
		spr.texture = _get_orbital_texture()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		orb_node.add_child(spr)
		# Collision
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		orb_node.add_child(shape)
		# Damage on contact
		orb_node.area_entered.connect(_on_orbital_hit.bind(orb_node))
		scene_root.add_child(orb_node)
		orbital_nodes.append(orb_node)

## Returns the cached orbital texture used by the three orbiting player
## projectiles. Lazily builds it once, then reuses it for every spawn.
func _get_orbital_texture() -> Texture2D:
	if _orbital_texture == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for y in range(24):
			for x in range(24):
				var dist := Vector2(float(x) - 11.5, float(y) - 11.5).length()
				if dist < 6.0:
					var t := dist / 6.0
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 - t * 0.4))
		_orbital_texture = ImageTexture.create_from_image(img)
	return _orbital_texture

## Rotates all orbital nodes around the player at a fixed radius and
## evenly spaced angles.
func _update_orbitals(delta: float) -> void:
	orbital_angle += delta * 3.0  # rotation speed
	var radius := 60.0
	var count := orbital_nodes.size()
	for i in range(count):
		if is_instance_valid(orbital_nodes[i]):
			var angle := orbital_angle + (TAU / count) * i
			orbital_nodes[i].global_position = global_position + Vector2(cos(angle), sin(angle)) * radius

## Handles orbital collision: deals 1 + bonus damage to enemies and
## tempest sections.
func _on_orbital_hit(area: Area2D, _orb: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("tempest_sections"):
		area.take_damage(1 + GameManager.bonus_damage)

## Removes all orbital nodes from the scene and clears the tracking array.
func _remove_orbitals() -> void:
	has_orbitals = false
	if not dev_orbitals:
		_clear_orbital_nodes()


func _clear_orbital_nodes() -> void:
	orbital_angle = 0.0
	for node in orbital_nodes:
		if is_instance_valid(node):
			node.queue_free()
	orbital_nodes.clear()

# --- Elite Upgrades ---

## Grants twin cannons: fires 2 additional parallel bullets alongside
## the main shot (stacks with spread shot for 5 total).
func grant_twin_cannons() -> void:
	set_elite_upgrade_enabled("twin_cannons", true)

## Grants auto-aim: bullets nudge 35% toward the nearest enemy within
## 500px (skipped for rear-facing bullets).
func grant_auto_aim() -> void:
	set_elite_upgrade_enabled("auto_aim", true)

## Grants the afterburner upgrade: permanently increases base speed by
## 20% and acceleration by 15%.
func grant_afterburner() -> void:
	set_elite_upgrade_enabled("afterburner", true)

## Grants hull plating: immediately adds +1 life and updates the HUD.
func grant_hull_plating() -> void:
	set_elite_upgrade_enabled("hull_plating", true, true)

# --- New Elite Upgrades ---

## Grants permanent 3-way spread shot. Stacks with twin_cannons (→ 5
## bullets), auto_aim, piercing, explosive, and zigzag modifiers.
func grant_spread_shot_elite() -> void:
	set_elite_upgrade_enabled("spread_shot_elite", true)

## Grants periodic shield burst: destroys all enemy bullets within 160px
## and damages nearby enemies every 10 seconds. Independent of fire upgrades.
func grant_shield_burst() -> void:
	set_elite_upgrade_enabled("shield_burst", true)

## Grants permanent magnetic pull on orbs and power-ups at 500 px/s
## (faster than the temporary magnet power-up's 350 px/s).
func grant_magnet_field() -> void:
	set_elite_upgrade_enabled("magnet_field", true)

## Grants overclock: triples fire rate for 2.5s every 16s. Stacks with
## rapid-fire powerups and other bullet modifiers.
func grant_overclock() -> void:
	set_elite_upgrade_enabled("overclock", true)

## Grants a permanent rear-facing cannon that fires backward with each
## shot. Inherits piercing, explosive, and zigzag from _spawn_bullet.
## Auto-aim is intentionally skipped for rear bullets.
func grant_rear_gunner() -> void:
	set_elite_upgrade_enabled("rear_gunner", true)

# --- Shield Burst implementation ---

## Executes the shield burst ability: destroys all enemy bullets within
## a 160px radius, deals 1 + bonus damage to nearby enemies and tempest
## sections, and spawns an expanding ring visual effect.
func _trigger_shield_burst() -> void:
	AudioManager.play_shield()
	var burst_radius := 160.0
	var burst_radius_sq := burst_radius * burst_radius
	var damage := 1 + GameManager.bonus_damage
	var tree := get_tree()
	# Destroy nearby enemy bullets
	for b in tree.get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b) and global_position.distance_squared_to(b.global_position) < burst_radius_sq:
			if b.has_method("despawn"):
				b.despawn()
			else:
				b.queue_free()
	for ordnance in tree.get_nodes_in_group("hostile_ordnance"):
		if is_instance_valid(ordnance) and global_position.distance_squared_to(ordnance.global_position) < burst_radius_sq:
			if ordnance.has_method("clear_ordnance"):
				ordnance.clear_ordnance()
	# Damage enemies and exposed boss systems caught in the burst.
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and global_position.distance_squared_to(e.global_position) < burst_radius_sq:
			e.take_damage(damage)
	for section in tree.get_nodes_in_group("tempest_sections"):
		if is_instance_valid(section) and global_position.distance_squared_to(section.global_position) < burst_radius_sq:
			section.take_damage(damage)
	# Visual flash ring
	_spawn_burst_ring(burst_radius)

## Creates an expanding cyan ring visual effect at the player's position,
## scaling outward and fading over 0.35 seconds. Used by shield burst.
func _spawn_burst_ring(radius: float) -> void:
	var ring := Node2D.new()
	ring.global_position = global_position
	var scene_root := get_tree().current_scene
	scene_root.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(radius / 40.0, radius / 40.0), 0.35)\
		.from(Vector2.ONE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(ring.queue_free)
	# Draw a simple ring using a canvas draw pass on a custom node
	var spr := Sprite2D.new()
	spr.texture = _get_burst_ring_texture()
	ring.add_child(spr)

## Returns the cached shield burst ring texture so the flash effect does
## not rebuild its image every time the shield clears bullets.
func _get_burst_ring_texture() -> Texture2D:
	if _burst_ring_texture == null:
		var img := Image.create(80, 80, false, Image.FORMAT_RGBA8)
		for y in range(80):
			for x in range(80):
				var d := Vector2(float(x) - 40.0, float(y) - 40.0).length()
				if d >= 36.0 and d <= 40.0:
					img.set_pixel(x, y, Color(0.4, 0.9, 1.0, 0.85))
		_burst_ring_texture = ImageTexture.create_from_image(img)
	return _burst_ring_texture

## Emits non-transform feedback when Overclock activates. The ship's shared
## presentation state is left untouched so boost, invincibility, and developer
## tinting remain authoritative.
func _flash_overclock() -> void:
	_spawn_sparkle_effect(global_position)
	AudioManager.play_powerup()

func _spawn_warp_effect(effect_position: Vector2, direction: Vector2) -> void:
	var effect := _acquire_pixel_effect()
	if effect != null and effect.has_method("play_warp_at"):
		effect.play_warp_at(effect_position, direction)

func _spawn_sparkle_effect(effect_position: Vector2) -> void:
	var effect := _acquire_pixel_effect()
	if effect != null and effect.has_method("play_sparkle_at"):
		effect.play_sparkle_at(effect_position)

func _acquire_pixel_effect() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return ObjectPool.acquire(PIXEL_EFFECT_SCENE, scene_root)

## Grants the drone escort upgrade: spawns a combat drone that hovers
## near the player and auto-fires at the nearest enemy. Only one drone
## can be active at a time.
func grant_drone_escort() -> void:
	set_elite_upgrade_enabled("drone_escort", true)

## Spawns the combat drone as a top-level scene node (not parented to the
## player). The ShipDrone component manages its own hover, fire cooldown,
## and contact damage.
func _spawn_drone() -> void:
	if is_instance_valid(drone_node):
		drone_node.queue_free()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		drone_node = null
		return
	drone_node = ShipDrone.new()
	drone_node.setup(self)
	scene_root.add_child(drone_node)

## Removes the drone from the scene.
func _remove_drone() -> void:
	if is_instance_valid(drone_node):
		drone_node.queue_free()
	drone_node = null
