extends Node2D
## Main game scene — contains the player, spawners, HUD, camera, and background.

const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")
const POINT_ALLOCATION_SCENE := preload("res://ui/point_allocation_popup.tscn")
const ELITE_UPGRADE_SCENE := preload("res://ui/elite_upgrade_popup.tscn")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const TRY_AGAIN_SCENE := preload("res://ui/try_again_popup.tscn")

@onready var player: Area2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var enemy_spawner: Node = $EnemySpawner
@onready var powerup_spawner: Node = $PowerUpSpawner

var game_over_shown: bool = false
var allocation_active: bool = false
var elite_upgrade_active: bool = false
var pause_active: bool = false
var try_again_active: bool = false
var _final_score_cache: int = 0

# Pending allocation: stored when elite and allocation trigger simultaneously
var _pending_allocation_points: int = -1

# Screen shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var _bg_time: float = 0.0
var _crt_layer: CanvasLayer = null
var _distort_layer: CanvasLayer = null

# --- Background planet continuous spawning ---
var _planet_container: Node2D = null   # Plain Node2D, moves with _process
var _planet_spawn_timer: float = 0.0
var _planet_spawn_interval: float = 6.0   # seconds between planet spawns
var _planet_scene_ref = null              # cached preloaded script

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
	SignalBus.allocation_triggered.connect(_on_allocation_triggered)
	SignalBus.elite_upgrade_triggered.connect(_on_elite_upgrade_triggered)
	SaveManager.settings_changed.connect(_apply_visual_settings)

	# Position player at bottom center
	var viewport_size := get_viewport().get_visible_rect().size
	player.position = Vector2(viewport_size.x / 2.0, viewport_size.y - 80.0)

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
	
	# Layer configs: [scroll_speed_y, star_count, min_size, max_size, color, show_nebulae, nebula_count]
	var layer_configs := [
		# Layer 1 — Deep (slowest, tiny dim stars, faint nebulae)
		{"speed": 15.0, "stars": 120, "min_sz": 0.5, "max_sz": 1.2,
		 "color": Color(0.6, 0.7, 1.0), "nebulae": true, "neb_count": 5},
		# Layer 2 — Mid (medium speed, normal stars)
		{"speed": 40.0, "stars": 80, "min_sz": 1.0, "max_sz": 2.2,
		 "color": Color(0.8, 0.88, 1.0), "nebulae": false, "neb_count": 0},
		# Layer 3 — Near (fastest, large bright stars with subtle color)
		{"speed": 80.0, "stars": 35, "min_sz": 1.8, "max_sz": 3.5,
		 "color": Color(0.9, 0.95, 1.0), "nebulae": true, "neb_count": 3},
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

	# --- Background Planets (continuous spawner) ---
	_planet_scene_ref = preload("res://effects/planet_background.gd")

	# Use a plain Node2D so we control position entirely via _process.
	# It sits behind the star parallax layers.
	_planet_container = Node2D.new()
	_planet_container.name = "PlanetContainer"
	add_child(_planet_container)
	move_child(_planet_container, 1) # Behind stars
	
	# Pre-seed a few planets spread across the visible screen so it isn't empty at start
	# var viewport_size := get_viewport().get_visible_rect().size
	for i in range(randi_range(3, 5)):
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

## Per-frame update: handles camera shake decay, feeds time to the background
## shader, scrolls background planets downward, cleans up off-screen planets,
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
	if is_instance_valid($Background) and $Background.material:
		($Background.material as ShaderMaterial).set_shader_parameter("u_time", _bg_time)

	# --- Background planet continuous spawning ---
	if is_instance_valid(_planet_container):
		var vp_size := get_viewport().get_visible_rect().size
		var scroll_speed := 10.0  # must match planet_parallax autoscroll Y

		# Move all planets downward
		for child in _planet_container.get_children():
			child.position.y += scroll_speed * delta
			# Clean up planets that have fully scrolled past the bottom
			if child.position.y > vp_size.y + 200.0:
				child.queue_free()

		# Timer-based spawn
		_planet_spawn_timer -= delta
		if _planet_spawn_timer <= 0.0:
			_planet_spawn_timer = randf_range(_planet_spawn_interval * 0.6, _planet_spawn_interval * 1.4)
			_spawn_background_planet(-150.0)  # just above the viewport

## Spawns a single background planet at the given Y position (random X).
## Creates a Node2D with the planet_background script attached and adds it
## to the planet container at a random scale for depth variation.
func _spawn_background_planet(y_pos: float) -> void:
	if not is_instance_valid(_planet_container) or _planet_scene_ref == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var node := Node2D.new()
	node.set_script(_planet_scene_ref)
	node.position = Vector2(randf_range(60.0, vp_size.x - 60.0), y_pos)
	var s := randf_range(0.25, 1.0)
	node.scale = Vector2(s, s)
	_planet_container.add_child(node)

## Consolidates all pause sources (pause menu, allocation popup, elite upgrade,
## try-again screen) into a single paused state for the scene tree.
func _update_pause_state() -> void:
	get_tree().paused = pause_active or allocation_active or elite_upgrade_active or try_again_active

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
	shake_duration = duration
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
		player._start_invincibility(player.respawn_invincibility)
		
	# Clear regular enemies and bullets from the scene, but spare the Boss
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not (enemy is BossEnemy):
			enemy.queue_free()
	get_tree().call_group("enemy_bullets", "queue_free")
	get_tree().call_group("powerups", "queue_free")
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
	get_tree().paused = true
	await get_tree().create_timer(0.8, false, false, true).timeout
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

	# If the elite upgrade is already active (Wave 10), defer and show side-by-side
	if elite_upgrade_active:
		_pending_allocation_points = points
		return

	# If the elite upgrade hasn't triggered yet but will this same frame, wait one frame
	# (boss_died emits elite_upgrade_triggered BEFORE allocation_triggered at Wave 10)
	# So we check on the next frame whether elite is also pending.
	_pending_allocation_points = points
	await get_tree().process_frame
	if elite_upgrade_active:
		# Elite already handled — it will call _show_combined when it opens
		return

	# Solo allocation
	_pending_allocation_points = -1
	get_tree().paused = true
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

## Handles the elite upgrade popup trigger. Pauses immediately, waits one
## frame to check for a simultaneous allocation trigger, and either shows
## both panels side-by-side or the elite popup solo.
func _on_elite_upgrade_triggered() -> void:
	if elite_upgrade_active:
		return
	elite_upgrade_active = true

	# Pause immediately
	get_tree().paused = true

	# Wait one frame so allocation_triggered (emitted right after) can set its flag
	await get_tree().process_frame

	if _pending_allocation_points >= 0:
		# Both active — show side by side
		_show_combined(_pending_allocation_points)
		_pending_allocation_points = -1
		return

	# Solo elite upgrade
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
	_update_pause_state()

## Shows the elite upgrade and point allocation panels side by side.
## Creates a shared overlay with an HBoxContainer holding both panels.
## Each panel independently signals completion; the overlay is freed
## only when both are done. Includes a fade-in animation.
func _show_combined(alloc_points: int) -> void:
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	# Single shared dark background
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Side-by-side HBox
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	root.add_child(hbox)

	# Left: elite upgrade panel
	var elite_panel := ELITE_UPGRADE_SCENE.instantiate()
	elite_panel.panel_only = true
	elite_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elite_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(elite_panel)
	elite_panel.upgrade_chosen.connect(func():
		_on_elite_upgrade_closed()
		if not allocation_active:
			overlay.queue_free()
	)

	# Right: allocation panel
	var alloc_panel := POINT_ALLOCATION_SCENE.instantiate()
	alloc_panel.panel_only = true
	alloc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alloc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(alloc_panel)
	alloc_panel.allocation_done.connect(func():
		_on_allocation_closed()
		if not elite_upgrade_active:
			overlay.queue_free()
	)
	alloc_panel.set_points(alloc_points)

	# Animate the whole root in
	root.modulate.a = 0.0
	var tween := root.create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
