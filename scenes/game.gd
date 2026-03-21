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

# Screen shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	GameManager.start_game()
	hud.update_all()

	enemy_spawner.start_spawning()
	powerup_spawner.start_spawning()

	SignalBus.game_over.connect(_on_game_over)
	SignalBus.screen_shake.connect(_on_screen_shake)
	SignalBus.allocation_triggered.connect(_on_allocation_triggered)
	SignalBus.elite_upgrade_triggered.connect(_on_elite_upgrade_triggered)

	# Position player at bottom center
	var viewport_size := get_viewport().get_visible_rect().size
	player.position = Vector2(viewport_size.x / 2.0, viewport_size.y - 80.0)

	# --- Shader Injection ---
	# Dynamically generating shaders explicitly forces Godot to compile and attach them safely
	var bg_shader := preload("res://effects/shaders/scrolling_bg.gdshader")
	if bg_shader:
		var bg_mat := ShaderMaterial.new()
		bg_mat.shader = bg_shader
		$Background.material = bg_mat

	var crt_shader := preload("res://effects/shaders/crt_overlay.gdshader")
	if crt_shader:
		var crt_mat := ShaderMaterial.new()
		crt_mat.shader = crt_shader
		var crt_rect := ColorRect.new()
		crt_rect.color = Color.WHITE
		crt_rect.material = crt_mat
		crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Using a CanvasLayer at index 100 guarantees it draws over the HUD AND the game world
		var crt_layer := CanvasLayer.new()
		crt_layer.layer = 100
		crt_layer.add_child(crt_rect)
		add_child(crt_layer)

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

var _pause_overlay: CanvasLayer = null

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

func _open_pause_menu() -> void:
	if pause_active:
		return
	pause_active = true
	get_tree().paused = true
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)
	var menu := PAUSE_MENU_SCENE.instantiate()
	menu.resumed.connect(_on_pause_resumed)
	_pause_overlay.add_child(menu)

func _close_pause_menu() -> void:
	get_tree().paused = false
	pause_active = false
	if is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null

func _on_pause_resumed() -> void:
	_close_pause_menu()

func _on_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _on_game_over(final_score: int) -> void:
	if game_over_shown:
		return
	_final_score_cache = final_score

	if GameManager.try_again_stocks > 0 and not try_again_active:
		# Intercept — offer a try-again before the true game over
		try_again_active = true
		await get_tree().create_timer(0.6).timeout
		get_tree().paused = true
		var overlay := CanvasLayer.new()
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(overlay)
		var popup := TRY_AGAIN_SCENE.instantiate()
		popup.try_again_accepted.connect(_on_try_again_accepted)
		popup.try_again_declined.connect(_on_try_again_declined)
		overlay.add_child(popup)
	else:
		_show_game_over(final_score)

func _on_try_again_accepted() -> void:
	try_again_active = false
	game_over_shown = false  # allow future deaths to trigger the popup again
	
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

func _on_try_again_declined() -> void:
	try_again_active = false
	_show_game_over(_final_score_cache)

func _show_game_over(final_score: int) -> void:
	if game_over_shown:
		return
	game_over_shown = true
	await get_tree().create_timer(0.8).timeout
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var game_over_screen := GAME_OVER_SCENE.instantiate()
	overlay.add_child(game_over_screen)
	game_over_screen.show_score(final_score)

func _on_allocation_triggered(points: int) -> void:
	if allocation_active:
		return
	allocation_active = true

	# Pause the game immediately
	get_tree().paused = true

	# Show the popup on a CanvasLayer that processes while paused
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var popup := POINT_ALLOCATION_SCENE.instantiate()
	popup.allocation_done.connect(_on_allocation_closed)
	overlay.add_child(popup)
	popup.set_points(points)

func _on_allocation_closed() -> void:
	allocation_active = false

func _on_elite_upgrade_triggered() -> void:
	if elite_upgrade_active:
		return
	elite_upgrade_active = true

	# Pause the game
	get_tree().paused = true

	# Show the elite upgrade picker on its own always-process CanvasLayer
	var overlay := CanvasLayer.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var popup := ELITE_UPGRADE_SCENE.instantiate()
	popup.upgrade_chosen.connect(_on_elite_upgrade_closed)
	overlay.add_child(popup)

func _on_elite_upgrade_closed() -> void:
	elite_upgrade_active = false
