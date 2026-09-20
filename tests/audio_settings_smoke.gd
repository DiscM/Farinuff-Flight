extends Node
## Real settings controls change the combat bus without muting music or menus.

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var disk_snapshot := preload("res://tests/save_file_snapshot.gd").new()
	await ResourceCache.wait_for_scene(ResourceCache.NATIVE_RUN_PATH)
	var settings := preload("res://ui/settings_menu.gd").new()
	add_child(settings)
	await get_tree().process_frame
	var slider := settings.find_child("SFXVolume", true, false) as HSlider
	_expect(slider != null, "Settings exposes the sound effects control")
	if slider != null:
		var sfx := AudioServer.get_bus_index("SFX")
		_expect(sfx >= 0, "Combat bus exists after autoload startup")
		slider.value = 0.0
		_expect(AudioServer.is_bus_mute(sfx), "Zero sound effects volume mutes combat")
		for name in ["Master", "Music", "UI"]:
			_expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index(name)), name + " remains audible")
		slider.value = 0.35
		_expect(not AudioServer.is_bus_mute(sfx), "Increasing sound effects volume unmutes combat")
		_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx)), 0.35), "Slider applies the selected level")
		# Load a fresh SaveManager instance through its normal startup path.
		var reloaded := preload("res://autoloads/save_manager.gd").new()
		add_child(reloaded)
		_expect(is_equal_approx(float(reloaded.get_setting("sfx_volume")), 0.35), "Sound effects level survives reopening")
		reloaded.queue_free()
		AudioManager.play_boost()
		var combat_voice_found := false
		for voice in AudioManager.get_children():
			if voice is AudioStreamPlayer and voice.stream == AudioManager.BOOST:
				combat_voice_found = true
				_expect(voice.bus == &"SFX", "Boost playback reaches the combat bus")
		_expect(combat_voice_found, "The public boost cue starts a combat voice")
	_check_player_preferences(settings)
	settings.queue_free()
	await get_tree().process_frame
	disk_snapshot.restore()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("AUDIO_SETTINGS_SMOKE_PASS")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_player_preferences(panel: Control) -> void:
	var quality := panel.find_child("GraphicsQuality", true, false) as OptionButton
	quality.select(0)
	quality.item_selected.emit(0)
	_expect(get_tree().root.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(get_tree().root.scaling_3d_scale, 0.75), "Low quality changes only the 3D render settings")
	quality.item_selected.emit(1)
	_expect(get_tree().root.msaa_3d == Viewport.MSAA_2X and is_equal_approx(get_tree().root.scaling_3d_scale, 1.0), "Medium quality renders at native resolution with 2x MSAA")
	quality.item_selected.emit(2)
	_expect(get_tree().root.msaa_3d == Viewport.MSAA_4X, "High quality restores the original 4x MSAA")
	var cap := panel.find_child("FrameCap", true, false) as OptionButton
	cap.item_selected.emit(2)
	_expect(Engine.max_fps == 60, "Frame limit applies immediately")
	cap.item_selected.emit(0)
	_expect(Engine.max_fps == 0, "Unlimited frame rate restores the engine default")
	var hud := panel.find_child("HUDScale", true, false) as OptionButton
	hud.item_selected.emit(2)
	var fire := panel.find_child("toggle_fire", true, false) as CheckButton
	fire.button_pressed = true
	var reloaded := preload("res://autoloads/save_manager.gd").new()
	add_child(reloaded)
	_expect(is_equal_approx(float(reloaded.get_setting("hud_scale")), 1.3) and reloaded.get_setting("toggle_fire"), "HUD scale and toggle fire persist through the real controls")
	reloaded.queue_free()
