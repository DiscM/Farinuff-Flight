extends Node
## Real settings controls change the combat bus without muting music or menus.

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
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
	settings.queue_free()
	await get_tree().process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("AUDIO_SETTINGS_SMOKE_PASS")
	get_tree().quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
