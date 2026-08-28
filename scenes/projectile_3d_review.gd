extends Node
class_name Projectile3DReview
## Manual incoming-projectile review, composed around the actual native scene.
## Repeatable volleys count contacts only; this is not an enemy AI or damage port.

const NativeGame := preload("res://scenes/native_3d_gameplay.gd")
const EnemyTuning := preload("res://entities/projectiles/enemy_projectile_tuning.gd")
const GUIDE_SEGMENTS := 64

@onready var gameplay: NativeGame = $Gameplay
@onready var volley_timer: Timer = $VolleyTimer
@onready var auto_volleys: CheckButton = $ReviewHUD/Panel/Controls/AutoVolleys
@onready var contact_status: Label = $ReviewHUD/Panel/ContactStatus
@onready var interaction_guide: Line2D = $ReviewHUD/InteractionGuide
@onready var hysteresis_guide: Line2D = $ReviewHUD/HysteresisGuide

var _review_ready := false
var _contacts := 0
var _show_guides := true
var _inner_offsets := PackedVector3Array()
var _outer_offsets := PackedVector3Array()
var _inner_points := PackedVector2Array()
var _outer_points := PackedVector2Array()


func _ready() -> void:
	$ReviewHUD/Panel/Controls/NormalVolley.pressed.connect(fire_normal_volley)
	$ReviewHUD/Panel/Controls/FastVolley.pressed.connect(fire_fast_volley)
	auto_volleys.toggled.connect(_set_auto_volleys)
	volley_timer.timeout.connect(fire_normal_volley)
	if gameplay.projectile_manager.is_ready:
		_begin_review()
	else:
		gameplay.gameplay_ready.connect(_begin_review, CONNECT_ONE_SHOT)


func _begin_review() -> void:
	_review_ready = true
	gameplay.projectile_manager.enemy_projectile_hit.connect(_on_enemy_projectile_hit)
	_prepare_guides()
	_set_auto_volleys(auto_volleys.button_pressed)
	_update_contact_status()


func _process(_delta: float) -> void:
	if not _review_ready or not _show_guides:
		return
	var player_position := gameplay.player.global_position
	for index in range(GUIDE_SEGMENTS + 1):
		_inner_points[index] = gameplay.flight_space.combat_to_screen(player_position + _inner_offsets[index])
		_outer_points[index] = gameplay.flight_space.combat_to_screen(player_position + _outer_offsets[index])
	interaction_guide.points = _inner_points
	hysteresis_guide.points = _outer_points


func _unhandled_input(event: InputEvent) -> void:
	if not _review_ready or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			fire_normal_volley()
		KEY_2:
			fire_fast_volley()
		KEY_V:
			auto_volleys.button_pressed = not auto_volleys.button_pressed
		KEY_H:
			_show_guides = not _show_guides
			interaction_guide.visible = _show_guides
			hysteresis_guide.visible = _show_guides
		_:
			return
	get_viewport().set_input_as_handled()


func fire_normal_volley() -> void:
	_fire_volley(EnemyTuning.DEFAULT_SPEED)


func fire_fast_volley() -> void:
	# Deliberate manual collision stress, not a change to enemy balance.
	_fire_volley(EnemyTuning.DEFAULT_SPEED * 6.0)


func _fire_volley(speed_pixels: float) -> void:
	if not _review_ready or not GameManager.is_game_active or get_tree().paused:
		return
	var bounds := gameplay.flight_space.get_combat_bounds()
	var top_inset := gameplay.flight_space.screen_motion_to_combat(Vector2(0.0, 24.0))
	var origin := Vector3(bounds.get_center().x, 0.0, bounds.position.y + top_inset.z)
	for lane in range(-3, 4):
		var offset := gameplay.flight_space.screen_motion_to_combat(Vector2(float(lane) * 100.0, 0.0))
		gameplay.projectile_manager.fire_enemy_projectile(origin + offset, Vector3.BACK, speed_pixels)


func _set_auto_volleys(enabled: bool) -> void:
	if _review_ready and enabled:
		volley_timer.start()
	else:
		volley_timer.stop()


func _on_enemy_projectile_hit(_target: Area3D, _combat_position: Vector3) -> void:
	_contacts += 1
	_update_contact_status()


func _update_contact_status() -> void:
	contact_status.text = "CONTACTS %d  •  1 NORMAL  •  2 FAST (6×)  •  V AUTO  •  H RANGE GUIDES" % _contacts


func _prepare_guides() -> void:
	var radius := gameplay.projectile_manager.interaction_range_pixels
	var outer_radius := radius + gameplay.projectile_manager.interaction_hysteresis_pixels
	$ReviewHUD/Panel/Legend.text = "%.0f PX BASE RANGE  •  %.0f PX HYSTERESIS  •  SPEED MARGIN ADDED WHEN MOVING" % [
		radius, gameplay.projectile_manager.interaction_hysteresis_pixels,
	]
	_inner_offsets.resize(GUIDE_SEGMENTS + 1)
	_outer_offsets.resize(GUIDE_SEGMENTS + 1)
	_inner_points.resize(GUIDE_SEGMENTS + 1)
	_outer_points.resize(GUIDE_SEGMENTS + 1)
	for index in range(GUIDE_SEGMENTS + 1):
		var direction := Vector2.from_angle(TAU * float(index) / float(GUIDE_SEGMENTS))
		_inner_offsets[index] = gameplay.flight_space.screen_motion_to_combat(direction * radius)
		_outer_offsets[index] = gameplay.flight_space.screen_motion_to_combat(direction * outer_radius)
