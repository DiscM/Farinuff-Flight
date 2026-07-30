extends RefCounted
class_name ShipVisualProxy3D
## Runtime state for one synchronized 2D ship -> 3D visual binding.
##
## The render layer owns proxy lifetimes. This object owns the bookkeeping
## needed to restore suppressed 2D fallback visuals when a binding ends.

var source_ref: WeakRef
var root: Node3D
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var outlines: Array[MeshInstance3D] = []
var source_materials: Dictionary = {}
var engine_trail: MeshInstance3D
var source_visual: CanvasItem
var player_assembly: PlayerShipAssembly3D
var suppressed_visuals: Array[CanvasItem] = []
var suppressed_self_modulates: Array[Color] = []
var archetype: StringName
var generation: int
var phase_offset: float


func suppress_visual(visual: CanvasItem) -> void:
	if not is_instance_valid(visual):
		return
	suppressed_visuals.append(visual)
	suppressed_self_modulates.append(visual.self_modulate)
	var hidden_modulate := visual.self_modulate
	hidden_modulate.a = 0.0
	visual.self_modulate = hidden_modulate


func restore_suppressed_visuals() -> void:
	for index in range(suppressed_visuals.size()):
		var visual := suppressed_visuals[index]
		if is_instance_valid(visual):
			visual.self_modulate = suppressed_self_modulates[index]
	suppressed_visuals.clear()
	suppressed_self_modulates.clear()


func collect_meshes(node: Node) -> void:
	if node is MeshInstance3D and not node.name.ends_with("_NeonOutline"):
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		collect_meshes(child)
