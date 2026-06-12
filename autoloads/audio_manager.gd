extends Node
## Lightweight pooled SFX playback with simple cooldowns for noisy events.

const HIT_MARKER := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BLLTImpt_Hit Marker_07.wav")
const EXPLOSION := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/EXPLDsgn_Explosion Impact_14.wav")
const POWERUP := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Energy Orb_05.wav")
const SHIELD := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Shield Activate Deactivate_02.wav")
const BOOST := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Spacecraft Preview/Thruster Ignite Oneshot_02.wav")
const DEFLECT := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BLLTRico_Ricochet Metallic_04.wav")
const PLAYER_HIT := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Spacecraft Preview/Impact Asteroid Debris Tail_03.wav")
const XP_ORB := preload("res://assets/Shapeforms Audio Free Sound Effects/Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/UIBeep_Lock On_05.wav")

const POOL_SIZE: int = 16

var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

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
	return _players[0] if not _players.is_empty() else null
