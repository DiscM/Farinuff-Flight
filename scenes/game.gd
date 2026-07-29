extends Node2D
## Main game scene — contains the player, spawners, HUD, camera, and background.

const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")
const POINT_ALLOCATION_SCENE := preload("res://ui/point_allocation_popup.tscn")
const ELITE_UPGRADE_SCENE := preload("res://ui/elite_upgrade_popup.tscn")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const TRY_AGAIN_SCENE := preload("res://ui/try_again_popup.tscn")

const BACKGROUND_PALETTE_TRANSITION_DURATION := 2.4
const BACKGROUND_EVOLUTION_PALETTES: Array[Dictionary] = [
	# Generation I — Standard: cold, open deep space.
	{
		&"space_color": Color(0.003, 0.009, 0.042),
		&"nebula_blue": Color(0.02, 0.32, 0.82),
		&"nebula_violet": Color(0.08, 0.12, 0.62),
		&"nebula_pink": Color(0.12, 0.72, 0.92),
	},
	# Generation II — Augmented: synthetic green with warning-amber filaments.
	{
		&"space_color": Color(0.004, 0.025, 0.025),
		&"nebula_blue": Color(0.02, 0.58, 0.42),
		&"nebula_violet": Color(0.06, 0.72, 0.25),
		&"nebula_pink": Color(1.0, 0.38, 0.025),
	},
	# Generation III — Warform: hot crimson and furnace orange.
	{
		&"space_color": Color(0.04, 0.002, 0.008),
		&"nebula_blue": Color(0.52, 0.012, 0.035),
		&"nebula_violet": Color(0.88, 0.025, 0.018),
		&"nebula_pink": Color(1.0, 0.2, 0.018),
	},
	# Generation IV — Apex: ultraviolet and high-energy magenta.
	{
		&"space_color": Color(0.02, 0.002, 0.045),
		&"nebula_blue": Color(0.18, 0.012, 0.76),
		&"nebula_violet": Color(0.64, 0.018, 0.96),
		&"nebula_pink": Color(1.0, 0.018, 0.52),
	},
]

@onready var player: Area2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var enemy_spawner: Node = $EnemySpawner
@onready var powerup_spawner: Node = $PowerUpSpawner
@onready var background: ColorRect = $Background

var game_over_shown: bool = false
var allocation_active: bool = false
var elite_upgrade_active: bool = false
var pause_active: bool = false
var try_again_active: bool = false
var _final_score_cache: int = 0

# Pending allocation: stored when elite and allocation trigger simultaneously
var _pending_allocation_points: int = -1
var _pending_evolution_generation: int = 0
var _pending_evolution_name: String = ""
var _evolution_banner_active: bool = false

# Screen shake state
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
## Sequence id for overlapping hit-stop calls — the latest call wins the
## time_scale restore.
var _hit_stop_seq: int = 0
var _bg_time: float = 0.0
var _background_palette_tween: Tween = null
var _crt_layer: CanvasLayer = null
var _distort_layer: CanvasLayer = null

# --- Foreground planet continuous spawning ---
var _planet_container: Node2D = null   # Plain Node2D, moves with _process
var _planet_spawn_timer: float = 0.0
var _planet_spawn_interval: float = 16.0  # seconds between planet spawns
var _planet_scene_ref = null              # cached preloaded script
var _planets_suspended: bool = false      # true during boss fights (black hole owns the sky)

# --- Boss black hole set piece ---
const BOSS_BLACK_HOLE_SCRIPT := preload("res://effects/boss_black_hole.gd")
var _boss_black_hole: Node2D = null

## Initializes the game scene: starts the game via GameManager, sets up spawners,
## connects signals, positions the player, builds the parallax star field with
## three depth layers, seeds the background planet spawner, and injects CRT/distortion
## shader post-processing layers.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.start_game()
	hud.update_all()
	hud.layer = 10 # Lift above post-processing

	enemy_spawner.start_spawning()
	powerup_spawner.start_spawning()

	SignalBus.game_over.connect(_on_game_over)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_died.connect(_on_boss_died_resume_planets)
	SignalBus.allocation_triggered.connect(_on_allocation_triggered)
	SignalBus.elite_upgrade_triggered.connect(_on_elite_upgrade_triggered)
	SignalBus.power_up_collected.connect(_on_power_up_collected_hit_stop)
	SignalBus.evolution_transition_pending.connect(_on_evolution_transition_pending)
	SaveManager.settings_changed.connect(_apply_visual_settings)

	# Position player at bottom center
	var viewport_size := get_viewport().get_visible_rect().size
	player.position = Vector2(viewport_size.x / 2.0, viewport_size.y - 80.0)
	get_viewport().size_changed.connect(_resize_background)
	_resize_background()
	_apply_background_evolution_palette(GameManager.get_enemy_generation(), true)

	# Dedicated container for boost afterimage sprites.
	# Parenting afterimages here (rather than the scene root) prevents
	# child-tree modifications from invalidating the star field's draw calls,
	# which was causing the star flicker during boost.
	var afterimage_container := Node2D.new()
	afterimage_container.name = "AfterimageContainer"
	afterimage_container.add_to_group("afterimage_container")
	add_child(afterimage_container)

	# --- Parallax Background ---
	var parallax_scene := preload("res://effects/parallax_layer.gd")
	
	# The shader owns the nebula so these layers only add crisp parallax stars.
	# Layer configs: [scroll_speed_y, star_count, min_size, max_size, color, show_nebulae, nebula_count]
	var layer_configs := [
		# Layer 1 — Deep (slowest, tiny dim stars)
		{"speed": 15.0, "stars": 120, "min_sz": 0.5, "max_sz": 1.2,
		 "color": Color(0.6, 0.7, 1.0), "nebulae": false, "neb_count": 0},
		# Layer 2 — Mid (medium speed, normal stars)
		{"speed": 40.0, "stars": 80, "min_sz": 1.0, "max_sz": 2.2,
		 "color": Color(0.8, 0.88, 1.0), "nebulae": false, "neb_count": 0},
		# Layer 3 — Near (fastest, large bright stars with subtle color)
		{"speed": 80.0, "stars": 35, "min_sz": 1.8, "max_sz": 3.5,
		 "color": Color(0.9, 0.95, 1.0), "nebulae": false, "neb_count": 0},
	]
	
	for cfg in layer_configs:
		var p2d := Parallax2D.new()
		p2d.autoscroll = Vector2(0.0, cfg["speed"])
		p2d.repeat_size = Vector2(720.0, 1024.0)
		
		var layer_renderer := parallax_scene.new()
		layer_renderer.star_count = cfg["stars"]
		layer_renderer.min_size = cfg["min_sz"]
		layer_renderer.max_size = cfg["max_sz"]
		layer_renderer.base_color = cfg["color"]
		layer_renderer.show_nebulae = cfg["nebulae"]
		layer_renderer.nebula_count = cfg["neb_count"]
		layer_renderer.repeat_size = p2d.repeat_size  # match repeat region so stars tile seamlessly
		
		p2d.add_child(layer_renderer)
		# Insert before the player/enemies so they draw over the background
		add_child(p2d)
		move_child(p2d, 1) # After Background ColorRect

	# --- Foreground Planets (continuous spawner) ---
	_planet_scene_ref = preload("res://effects/planet_background.gd")

	# Use a plain Node2D so we control position entirely via _process.
	# Planets are a foreground feature: they draw above the star parallax
	# layers (indices 1–3) instead of hiding behind them.
	_planet_container = Node2D.new()
	_planet_container.name = "PlanetContainer"
	add_child(_planet_container)
	move_child(_planet_container, 4) # Above stars

	# Pre-seed a planet or two so the screen isn't empty at start
	for i in range(randi_range(1, 2)):
		_spawn_background_planet(randf_range(-50.0, viewport_size.y + 50.0))

	# --- Shader Injection ---
	var crt_shader := preload("res://effects/shaders/crt_overlay.gdshader")
	var distort_shader := preload("res://effects/shaders/distortion_only.gdshader")
	
	if crt_shader:
		var crt_mat := ShaderMaterial.new()
		crt_mat.shader = crt_shader
		crt_mat.set_shader_parameter("apply_distortion", false) # Scanlines only on world
		
		var crt_rect := ColorRect.new()
		crt_rect.color = Color.WHITE
		crt_rect.material = crt_mat
		crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		_crt_layer = CanvasLayer.new()
		_crt_layer.layer = 1
		_crt_layer.add_child(crt_rect)
		add_child(_crt_layer)

	if distort_shader:
		var distort_mat := ShaderMaterial.new()
		distort_mat.shader = distort_shader
		
		var distort_rect := ColorRect.new()
		distort_rect.color = Color.WHITE
		distort_rect.material = distort_mat
		distort_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		distort_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Universal distortion layer (affects everything below it i.e. game world + scanlines + HUD)
		_distort_layer = CanvasLayer.new()
		_distort_layer.layer = 100
		_distort_layer.add_child(distort_rect)
		add_child(_distort_layer)

	_apply_visual_settings()


## Sizes the shader host explicitly because its parent is a Node2D, which
## cannot provide Control anchors with a layout rectangle. A small border
## keeps the galaxy covering the screen during camera shake.
func _resize_background() -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var overscan := Vector2(32.0, 32.0)
	background.position = viewport_rect.position - overscan
	background.size = viewport_rect.size + overscan * 2.0


## Crossfades the galaxy's four color uniforms to the palette associated with
## the active enemy generation. Starting from the material's current colors
## makes repeated or interrupted transitions remain visually continuous.
func _apply_background_evolution_palette(generation: int, immediate: bool = false) -> void:
	var material := background.material as ShaderMaterial
	if material == null:
		return
	var palette := BACKGROUND_EVOLUTION_PALETTES[clampi(generation, 1, 4) - 1]

	if _background_palette_tween != null and _background_palette_tween.is_valid():
		_background_palette_tween.kill()

	if immediate:
		for parameter: StringName in palette:
			material.set_shader_parameter(parameter, palette[parameter])
		return

	_background_palette_tween = create_tween()
	_background_palette_tween.set_parallel(true)
	_background_palette_tween.set_trans(Tween.TRANS_SINE)
	_background_palette_tween.set_ease(Tween.EASE_IN_OUT)
	for parameter: StringName in palette:
		var current_color: Color = material.get_shader_parameter(parameter)
		var target_color: Color = palette[parameter]
		_background_palette_tween.tween_method(
			_set_background_shader_color.bind(parameter),
			current_color,
			target_color,
			BACKGROUND_PALETTE_TRANSITION_DURATION
		)


func _set_background_shader_color(color: Color, parameter: StringName) -> void:
	var material := background.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(parameter, color)


## Per-frame update: handles camera shake decay, feeds time to the background
## shader, scrolls foreground planets downward, cleans up off-screen planets,
## and periodically spawns new planets above the viewport.
func _process(delta: float) -> void:
	# Camera shake
	if shake_timer > 0:
		shake_timer -= delta
		var offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera.offset = offset
		shake_intensity = lerpf(shake_intensity, 0.0, delta * 5.0)
	else:
		camera.offset = Vector2.ZERO
		
	# Feed paused time to the background shader
	_bg_time += delta
	if is_instance_valid(background) and background.material:
		(background.material as ShaderMaterial).set_shader_parameter("u_time", _bg_time)

	# --- Foreground planet continuous spawning ---
	if is_instance_valid(_planet_container):
		var vp_size := get_viewport().get_visible_rect().size
		var scroll_speed := 10.0  # must match planet_parallax autoscroll Y

		# Move all planets downward
		for child in _planet_container.get_children():
			child.position.y += scroll_speed * delta
			# Clean up planets that have fully scrolled past the bottom
			# (generous margin — planets are large now and must exit fully)
			if child.position.y > vp_size.y + 450.0:
				child.queue_free()

		# Timer-based spawn. Suspended during boss fights; the timer value is
		# deliberately left untouched while suspended so generation continues
		# from exactly where it was once the boss is defeated.
		if not _planets_suspended:
			_planet_spawn_timer -= delta
			if _planet_spawn_timer <= 0.0:
				_planet_spawn_timer = randf_range(_planet_spawn_interval * 0.6, _planet_spawn_interval * 1.4)
				_spawn_background_planet(-250.0)  # just above the viewport

## Spawns a single foreground planet at the given Y position (random X).
## Creates a Node2D with the planet_background script attached and adds it
## to the planet container at a large, screen-dominating scale.
func _spawn_background_planet(y_pos: float) -> void:
	if not is_instance_valid(_planet_container) or _planet_scene_ref == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var node := Node2D.new()
	node.set_script(_planet_scene_ref)
	node.position = Vector2(randf_range(60.0, vp_size.x - 60.0), y_pos)
	var s := randf_range(0.9, 1.8)
	node.scale = Vector2(s, s)
	_planet_container.add_child(node)

## Spawns the boss-fight black hole when a boss arrives. The hole phases in
## and grows for the whole fight, and frees itself on boss_died. Also
## suspends planet generation and fizzles out any live planets so the black
## hole owns the sky for the duration of the fight.
func _on_boss_spawned(_health: int, _max_health: int, _boss_name: String) -> void:
	_planets_suspended = true
	_fizzle_out_planets()
	if is_instance_valid(_boss_black_hole):
		return
	_boss_black_hole = Node2D.new()
	_boss_black_hole.set_script(BOSS_BLACK_HOLE_SCRIPT)
	add_child(_boss_black_hole)
	# Draw above the foreground planets, below the gameplay nodes.
	move_child(_boss_black_hole, _planet_container.get_index() + 1)

## Fades and shrinks every live planet away (with slight per-planet timing
## variation so they don't all vanish in lockstep), then frees them.
func _fizzle_out_planets() -> void:
	if not is_instance_valid(_planet_container):
		return
	for child in _planet_container.get_children():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "modulate:a", 0.0, randf_range(1.0, 1.8)).set_ease(Tween.EASE_IN)
		tween.tween_property(child, "scale", child.scale * 0.15, randf_range(1.2, 2.0)).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(child.queue_free)

## Resumes planet generation when the boss dies. The spawn timer kept its
## pre-fight value, so generation continues right where it left off.
func _on_boss_died_resume_planets(_points: int) -> void:
	_planets_suspended = false
	_hit_stop(0.25, 0.05)

## Adds a small hit-stop punch to nuke pickups.
func _on_power_up_collected_hit_stop(type: int, _pos: Vector2) -> void:
	if type == PowerUp.Type.NUKE:
		_hit_stop(0.15, 0.1)

## Briefly freezes the action for impact emphasis ("hit-stop"). The timer
## ignores the slowed time scale and always processes, so it resolves even
## if a popup pauses the tree mid-effect. Overlapping calls: latest wins.
func _hit_stop(duration: float, time_scale: float) -> void:
	_hit_stop_seq += 1
	var seq := _hit_stop_seq
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if seq == _hit_stop_seq:
		Engine.time_scale = 1.0

## Consolidates all pause sources (pause menu, allocation popup, elite upgrade,
## try-again screen) into a single paused state for the scene tree.
## Single choke point for tree pausing. Every pause source is a flag OR'd
## here — never write get_tree().paused directly elsewhere, or a later
## recompute from these flags would silently stomp it.
func _update_pause_state() -> void:
	get_tree().paused = pause_active or allocation_active or elite_upgrade_active or try_again_active or game_over_shown
	_sync_hud_visibility()

## Keeps the gameplay HUD out of modal upgrade/allocation screens so it
## cannot overlap the card UI, while leaving pause/game-over behavior alone.
func _sync_hud_visibility() -> void:
	if is_instance_valid(hud):
		hud.visible = not (allocation_active or elite_upgrade_active)

var _pause_overlay: CanvasLayer = null

## Handles the ESC key press: opens or closes the pause menu, but only when
## the game is active and no modal popup (allocation / elite upgrade / try-again)
## is already open.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not GameManager.is_game_active:
			return
		if allocation_active or elite_upgrade_active or try_again_active:
			return
		if pause_active:
			_close_pause_menu()
			return
		_open_pause_menu()
		get_viewport().set_input_as_handled()

## Creates and displays the pause menu overlay. Pauses the game tree and
## connects the menu's "resumed" signal to close it.
func _open_pause_menu() -> void:
	if pause_active:
		return
	pause_active = true
	_update_pause_state()
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)
	var menu := PAUSE_MENU_SCENE.instantiate()
	menu.resumed.connect(_on_pause_resumed)
	_pause_overlay.add_child(menu)

## Tears down the pause menu overlay and unpauses the game.
func _close_pause_menu() -> void:
	pause_active = false
	_update_pause_state()
	if is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null

## Signal callback from the pause menu's "Resume" button.
func _on_pause_resumed() -> void:
	_close_pause_menu()

## Initiates a screen shake effect with the given intensity and duration,
## unless screen shake has been disabled in the settings.
func _on_screen_shake(intensity: float, duration: float) -> void:
	if not bool(SaveManager.get_setting("screen_shake", true)):
		camera.offset = Vector2.ZERO
		shake_timer = 0.0
		return
	shake_intensity = intensity
	shake_timer = duration

## Reads visual preferences from SaveManager and shows/hides the CRT
## scanline layer and distortion layer accordingly. Also clears any
## active shake if the setting has been turned off.
func _apply_visual_settings() -> void:
	if is_instance_valid(_crt_layer):
		_crt_layer.visible = bool(SaveManager.get_setting("crt_effect", true))
	if is_instance_valid(_distort_layer):
		_distort_layer.visible = bool(SaveManager.get_setting("screen_distortion", true))
	if not bool(SaveManager.get_setting("screen_shake", true)):
		shake_timer = 0.0
		camera.offset = Vector2.ZERO

## Handles the game over flow: if the player has try-again stocks, shows
## the try-again popup first; otherwise shows the final game over screen.
## Guards against duplicate calls.
func _on_game_over(final_score: int) -> void:
	if game_over_shown:
		return
	_final_score_cache = final_score
	_hit_stop(0.3, 0.15)

	if GameManager.try_again_stocks > 0 and not try_again_active:
		# Intercept — offer a try-again before the true game over
		try_again_active = true
		await get_tree().create_timer(0.6).timeout
		_update_pause_state()
		var overlay := CanvasLayer.new()
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(overlay)
		var popup := TRY_AGAIN_SCENE.instantiate()
		popup.try_again_accepted.connect(_on_try_again_accepted)
		popup.try_again_declined.connect(_on_try_again_declined)
		overlay.add_child(popup)
	else:
		_show_game_over(final_score)

## Called when the player accepts the try-again offer. Restores lives,
## grants invincibility, clears non-boss enemies and bullets from the
## scene, and resumes spawning.
func _on_try_again_accepted() -> void:
	try_again_active = false
	game_over_shown = false  # allow future deaths to trigger the popup again
	_update_pause_state()
	
	if is_instance_valid(player):
		# Reset to the respawn default — respawn_invincibility still holds
		# whatever duration the killing hit set (2s or 3s).
		player.respawn_invincibility = player.RESPAWN_INVINCIBILITY
		player._start_invincibility(player.respawn_invincibility)
		
	# Clear regular enemies and bullets from the scene, but spare the Boss
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not (enemy is BossEnemy):
			enemy.queue_free()
	# Pooled objects must be returned to the pool, not queue_freed
	get_tree().call_group("enemy_bullets", "despawn")
	get_tree().call_group("powerups", "despawn")
	# Restart enemy spawning
	enemy_spawner._on_try_again_accepted()

## Called when the player declines the try-again offer or the countdown
## expires. Proceeds to the true game over screen.
func _on_try_again_declined() -> void:
	try_again_active = false
	_update_pause_state()
	_show_game_over(_final_score_cache)

## Displays the final game over screen with the player's score.
## Pauses the tree and waits a brief delay before instantiating the screen.
func _show_game_over(final_score: int) -> void:
	if game_over_shown:
		return
	game_over_shown = true
	_update_pause_state()
	# process_always must stay true: the tree is paused, so a pausable
	# timer would never fire and the game-over screen would never appear.
	await get_tree().create_timer(0.8, true, false, true).timeout
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var game_over_screen := GAME_OVER_SCENE.instantiate()
	overlay.add_child(game_over_screen)
	game_over_screen.show_score(final_score)

## Handles the stat allocation popup trigger. Defers showing it if an
## elite upgrade popup is already active (so both can be shown side-by-side),
## or waits one frame to check for simultaneous triggers before showing
## it solo.
func _on_allocation_triggered(points: int) -> void:
	if allocation_active:
		return
	allocation_active = true
	_sync_hud_visibility()

	# At combined milestones, elite selection always resolves before allocation.
	if elite_upgrade_active:
		_pending_allocation_points = points
		return

	# If the elite upgrade hasn't triggered yet but will this same frame, wait one frame
	# (boss_died emits elite_upgrade_triggered BEFORE allocation_triggered at Wave 10)
	# So we check on the next frame whether elite is also pending.
	_pending_allocation_points = points
	await get_tree().process_frame
	if elite_upgrade_active:
		# The elite completion callback will open allocation next.
		return

	_pending_allocation_points = -1
	_show_allocation_popup(points)


func _show_allocation_popup(points: int) -> void:
	# allocation_active is always already set by the callers, so this is
	# equivalent to a direct pause write but goes through the choke point.
	_update_pause_state()
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var popup := POINT_ALLOCATION_SCENE.instantiate()
	popup.allocation_done.connect(_on_allocation_closed)
	overlay.add_child(popup)
	popup.set_points(points)

## Signal callback when the allocation popup is closed. Clears the active
## flag and updates the pause state.
func _on_allocation_closed() -> void:
	allocation_active = false
	_update_pause_state()
	_maybe_show_evolution_banner()

## Handles the elite upgrade popup trigger. Pauses immediately, waits one
## frame for a simultaneous allocation trigger to set its flag, and shows
## the elite popup solo. A pending allocation is deferred and shown right
## after the elite popup closes (see _on_elite_upgrade_closed).
func _on_elite_upgrade_triggered() -> void:
	if elite_upgrade_active:
		return
	elite_upgrade_active = true
	# Pauses via the flag-based choke point
	_update_pause_state()

	# Wait one frame so allocation_triggered (emitted right after) can set its flag
	await get_tree().process_frame

	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var popup := ELITE_UPGRADE_SCENE.instantiate()
	popup.upgrade_chosen.connect(_on_elite_upgrade_closed)
	overlay.add_child(popup)

## Signal callback when the elite upgrade popup is closed. Clears the
## active flag and updates the pause state.
func _on_elite_upgrade_closed() -> void:
	elite_upgrade_active = false
	if _pending_allocation_points >= 0:
		var points := _pending_allocation_points
		_pending_allocation_points = -1
		_show_allocation_popup(points)
		return
	_update_pause_state()
	_maybe_show_evolution_banner()

func _on_evolution_transition_pending(generation: int, generation_name: String) -> void:
	_pending_evolution_generation = generation
	_pending_evolution_name = generation_name
	enemy_spawner.set_evolution_hold(true)
	await get_tree().process_frame
	_maybe_show_evolution_banner()


func _maybe_show_evolution_banner() -> void:
	if _pending_evolution_generation <= 0 or _evolution_banner_active:
		return
	if allocation_active or elite_upgrade_active or try_again_active or pause_active:
		return
	_show_evolution_banner()


func _show_evolution_banner() -> void:
	_evolution_banner_active = true
	var generation := _pending_evolution_generation
	var generation_name := _pending_evolution_name
	_pending_evolution_generation = 0
	_pending_evolution_name = ""

	# Evolution is immediate and clean: no old projectiles or pressure cross the boundary.
	get_tree().call_group("enemy_bullets", "despawn")
	get_tree().call_group("hostile_ordnance", "clear_ordnance")
	get_tree().call_group("rail_beams", "despawn")
	enemy_spawner.clear_for_transition()
	_apply_background_evolution_palette(generation)

	var overlay := CanvasLayer.new()
	overlay.layer = 30
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 116)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.015, 0.075, 0.94)
	style.border_color = [
		Color(0.45, 0.8, 1.0),
		Color(1.0, 0.62, 0.12),
		Color(1.0, 0.18, 0.16),
		Color(1.0, 0.05, 0.75),
	][generation - 1]
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(labels)
	var title := Label.new()
	title.text = "HOSTILE EVOLUTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", style.border_color)
	labels.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "GEN %s  //  %s" % [_roman_generation(generation), generation_name.to_upper()]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	labels.add_child(subtitle)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.12)
	tween.tween_property(panel, "modulate:a", 0.0, 0.30)
	await tween.finished
	overlay.queue_free()
	_evolution_banner_active = false
	SignalBus.evolution_transition_finished.emit(generation)


func _roman_generation(generation: int) -> String:
	return ["I", "II", "III", "IV"][clampi(generation, 1, 4) - 1]
