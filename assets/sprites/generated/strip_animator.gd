extends Sprite2D

@export var fps: float = 8.0
@export var frame_count: int = 4
@export var loop: bool = true
@export var start_frame: int = 0

var _time: float = 0.0


## Called when the node enters the scene tree for the first time.
## Initializes frame count/hframes alignment and starts or stops processing based on configuration.
func _ready() -> void:
	if frame_count <= 1 and hframes > 1:
		frame_count = hframes
	if hframes <= 1 and frame_count > 1:
		hframes = frame_count
	frame = clampi(start_frame, 0, max(frame_count - 1, 0))
	set_process(fps > 0.0 and frame_count > 1)


## Called every frame. Updates the current frame based on elapsed time, FPS, and loop settings.
func _process(delta: float) -> void:
	if fps <= 0.0 or frame_count <= 1:
		return
	_time += delta
	var idx := int(floor(_time * fps)) + start_frame
	if loop:
		frame = posmod(idx, frame_count)
	else:
		frame = min(idx, frame_count - 1)
