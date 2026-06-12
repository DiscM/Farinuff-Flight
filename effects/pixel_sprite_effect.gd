extends Node2D
## Reusable one-shot spritesheet effect for small combat feedback.

const WARP_TEXTURE := preload("res://assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Sci-fi/scifi_warp_003/scifi_warp_003_small_blue/spritesheet.png")
const SPARKLE_TEXTURE := preload("res://assets/Super Pixel Effects Gigapack (Free Version)/spritesheet/Magic Bursts/round_sparkle_burst_001/round_sparkle_burst_001_small_blue/spritesheet.png")

const FRAME_TIME: float = 1.0 / 24.0

enum EffectKind { WARP, SPARKLE }

var _sprite: Sprite2D
var _frame_count: int = 1
var _frame_index: int = 0
var _frame_timer: float = 0.0
var _play_token: int = 0

func _ready() -> void:
	_ensure_nodes()
	_set_idle_state()

func _process(delta: float) -> void:
	if not visible:
		return
	_frame_timer += delta
	while _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_frame_index += 1
		if _frame_index >= _frame_count:
			_set_idle_state()
			ObjectPool.release(self)
			return
		_sprite.frame = _frame_index

func play_at(effect_position: Vector2, kind: EffectKind, effect_rotation: float = 0.0) -> void:
	_ensure_nodes()
	_play_token += 1
	global_position = effect_position
	rotation = effect_rotation
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	_configure(kind)

	var token := _play_token
	get_tree().create_timer(float(_frame_count) * FRAME_TIME + 0.08).timeout.connect(_release_if_current.bind(token))

func play_warp_at(effect_position: Vector2, direction: Vector2) -> void:
	var angle := direction.angle() + PI / 2.0 if not direction.is_zero_approx() else 0.0
	play_at(effect_position, EffectKind.WARP, angle)

func play_sparkle_at(effect_position: Vector2) -> void:
	play_at(effect_position, EffectKind.SPARKLE)

func _ensure_nodes() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.centered = true
		add_child(_sprite)

func _configure(kind: EffectKind) -> void:
	match kind:
		EffectKind.WARP:
			_set_sprite(WARP_TEXTURE, 12, 1, 12, 1.35)
		EffectKind.SPARKLE:
			_set_sprite(SPARKLE_TEXTURE, 14, 1, 14, 1.4)

func _set_sprite(texture: Texture2D, hframes: int, vframes: int, frame_count: int, sprite_scale: float) -> void:
	_sprite.texture = texture
	_sprite.hframes = hframes
	_sprite.vframes = vframes
	_sprite.frame = 0
	_sprite.scale = Vector2.ONE * sprite_scale
	_sprite.modulate = Color.WHITE
	_frame_count = frame_count
	_frame_index = 0
	_frame_timer = 0.0

func _release_if_current(token: int) -> void:
	if token != _play_token or not visible:
		return
	_set_idle_state()
	ObjectPool.release(self)

func _set_idle_state() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
