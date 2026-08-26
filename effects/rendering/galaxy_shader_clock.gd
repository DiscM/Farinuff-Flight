extends Node
class_name GalaxyShaderClock
## Advances the shared galaxy shader's time parameter for any CanvasItem host.

@export_node_path("CanvasItem") var shader_host_path: NodePath

@onready var shader_host: CanvasItem = get_node_or_null(shader_host_path) as CanvasItem

var _elapsed_seconds: float = 0.0


func _ready() -> void:
	if shader_host == null:
		push_error("GalaxyShaderClock requires a CanvasItem shader host")


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	if shader_host == null:
		return
	var shader_material := shader_host.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("u_time", _elapsed_seconds)
