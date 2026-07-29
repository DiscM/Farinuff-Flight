extends Node
## Lightweight pooled SFX playback with simple cooldowns for noisy events,
## plus a looping music bed on its own "Music" bus.

const HIT_MARKER := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BLLTImpt_Hit Marker_07.wav")
const EXPLOSION := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/EXPLDsgn_Explosion Impact_14.wav")
const POWERUP := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Energy Orb_05.wav")
const SHIELD := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Shield Activate Deactivate_02.wav")
const BOOST := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Spacecraft Preview/Thruster Ignite Oneshot_02.wav")
const DEFLECT := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BLLTRico_Ricochet Metallic_04.wav")
const PLAYER_HIT := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Spacecraft Preview/Impact Asteroid Debris Tail_03.wav")
const XP_ORB := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/UIBeep_Lock On_05.wav")
const MUSIC_LOOP := preload("res://assets/Shapeforms Audio Free Sound Effects/Dystopia – Ambience and Drone Preview/AUDIO/AMBIENCE_SPACECRAFT_HOLD_LOOP.wav")
const UI_CLICK := preload("res://assets/Shapeforms Audio Free Sound Effects/Future UI Preview/Audio/FUI Button Beep Clean.wav")

const POOL_SIZE: int = 16
## Baseline music loudness before the music_volume setting is applied.
const MUSIC_VOLUME_DB := -16.0

var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_start_music()
	# SaveManager._ready runs before ours and applies volumes while the Music
	# bus doesn't exist yet — re-apply now that the bus has been created.
	SaveManager._apply_audio_settings()

## Creates the "Music" audio bus (routed to Master) if it doesn't exist yet,
## so the music volume can be mixed independently of the SFX.
func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")

## Starts the looping ambient music bed. The Music bus volume (applied from
## the music_volume setting by SaveManager) mixes it against the SFX.
func _start_music() -> void:
	var music_stream := MUSIC_LOOP.duplicate() as AudioStreamWAV
	if music_stream != null:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = music_stream
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	_music_player.play()

func play_hit_marker() -> void:
	_play_rate_limited("hit_marker", HIT_MARKER, -27.0, 0.045, 0.92, 1.08)

func play_explosion(small: bool = false) -> void:
	var volume := -22.0 if small else -17.0
	_play_rate_limited("explosion", EXPLOSION, volume, 0.055, 0.9, 1.04)

func play_powerup() -> void:
	_play(POWERUP, -9.0, 0.94, 1.08)

func play_shield() -> void:
	_play_rate_limited("shield", SHIELD, -8.0, 0.08, 0.94, 1.04)

func play_boost() -> void:
	_play_rate_limited("boost", BOOST, -24.0, 0.12, 0.9, 1.05)

func play_deflect() -> void:
	_play_rate_limited("deflect", DEFLECT, -10.0, 0.06, 0.92, 1.1)

func play_player_hit() -> void:
	_play_rate_limited("player_hit", PLAYER_HIT, -23.0, 0.12, 0.92, 1.04)

func play_xp_orb() -> void:
	_play_rate_limited("xp_orb", XP_ORB, -20.0, 0.035, 1.08, 1.32)

func play_ui_click() -> void:
	_play(UI_CLICK, -12.0, 0.98, 1.02)

func _play_rate_limited(key: String, stream: AudioStream, volume_db: float, cooldown: float, pitch_min: float, pitch_max: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var last_time: float = _last_played.get(key, -999.0)
	if now - last_time < cooldown:
		return
	_last_played[key] = now
	_play(stream, volume_db, pitch_min, pitch_max)

func _play(stream: AudioStream, volume_db: float, pitch_min: float, pitch_max: float) -> void:
	var player := _get_available_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	# All voices busy: steal the one nearest completion — its cutoff is the
	# least audible, unlike always clipping the same oldest slot.
	var best: AudioStreamPlayer = null
	var best_pos := -1.0
	for player in _players:
		var pos := player.get_playback_position()
		if pos > best_pos:
			best_pos = pos
			best = player
	return best
