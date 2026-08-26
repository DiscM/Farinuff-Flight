extends Node
class_name Player3DAssetReview
## Runtime-scale visual review for the native Player Craft wrapper contract.

const PlayerCraft := preload("res://entities/player/player_3d.gd")
const SOCKET_GUIDE_COLORS := {
	&"muzzle": Color(1.0, 0.08, 0.58),
	&"engine": Color(0.05, 0.82, 1.0),
	&"upgrade": Color(1.0, 0.78, 0.08),
	&"effect": Color(0.35, 1.0, 0.48),
}

@onready var player: PlayerCraft = $World3D/Player3D
@onready var review_camera: Camera3D = $World3D/CameraRig3D/ShakeOffset/Camera3D
@onready var hitbox_guide: MeshInstance3D = $World3D/ReviewGuides3D/HitboxEnvelope
@onready var socket_guides: Node3D = $World3D/ReviewGuides3D/SocketGuides
@onready var socket_status: Label = $ReviewHUD/SocketStatus

var _previous_hdr_2d: bool = false
var _guide_mesh: SphereMesh
var _guide_materials: Dictionary = {}


func _enter_tree() -> void:
	_previous_hdr_2d = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _ready() -> void:
	add_to_group(&"native_3d_asset_review")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_configure_hitbox_guide()
	_create_socket_guides()
	_update_guide_status()


func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().use_hdr_2d = _previous_hdr_2d


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_H:
		hitbox_guide.visible = not hitbox_guide.visible
		_update_guide_status()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S:
		socket_guides.visible = not socket_guides.visible
		_update_guide_status()
		get_viewport().set_input_as_handled()


func _update_guide_status() -> void:
	var hitbox_pixels := _get_hitbox_pixel_size()
	socket_status.text = (
		"%d SOCKETS  •  %d×%d SCREEN PX HITBOX  •  H HITBOX: %s  •  S SOCKETS: %s"
		% [
			player.get_socket_names().size(),
			hitbox_pixels.x,
			hitbox_pixels.y,
			"ON" if hitbox_guide.visible else "OFF",
			"ON" if socket_guides.visible else "OFF",
		]
	)


func _get_hitbox_pixel_size() -> Vector2i:
	var source_shape := player.collision_shape.shape as CapsuleShape3D
	if source_shape == null or review_camera == null:
		return Vector2i.ZERO
	var shape_transform := player.collision_shape.global_transform
	var center := shape_transform.origin
	var horizontal_offset := shape_transform.basis.x.normalized() * source_shape.radius
	var longitudinal_offset := shape_transform.basis.y.normalized() * (source_shape.height * 0.5)
	var screen_left := review_camera.unproject_position(center - horizontal_offset)
	var screen_right := review_camera.unproject_position(center + horizontal_offset)
	var screen_front := review_camera.unproject_position(center - longitudinal_offset)
	var screen_back := review_camera.unproject_position(center + longitudinal_offset)
	return Vector2i(
		roundi(screen_left.distance_to(screen_right)),
		roundi(screen_front.distance_to(screen_back))
	)


func _configure_hitbox_guide() -> void:
	var source_shape := player.collision_shape.shape as CapsuleShape3D
	if source_shape == null:
		push_error("Player3D asset review requires a CapsuleShape3D hitbox")
		return
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 1.0, 0.38, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.04, 0.5, 0.12)
	material.emission_energy_multiplier = 0.35
	var mesh := CapsuleMesh.new()
	mesh.material = material
	mesh.radius = source_shape.radius
	mesh.height = source_shape.height
	mesh.radial_segments = 24
	mesh.rings = 8
	hitbox_guide.mesh = mesh
	hitbox_guide.global_transform = player.collision_shape.global_transform


func _create_socket_guides() -> void:
	_guide_mesh = SphereMesh.new()
	_guide_mesh.radius = 0.16
	_guide_mesh.height = 0.32
	_guide_mesh.radial_segments = 12
	_guide_mesh.rings = 6
	for socket_name in player.get_socket_names():
		var socket := player.get_socket(socket_name)
		if socket == null:
			push_error("Player3D asset review is missing socket %s" % socket_name)
			continue
		var guide := MeshInstance3D.new()
		guide.name = "Guide_%s" % socket_name
		guide.mesh = _guide_mesh
		guide.material_override = _get_guide_material(socket_name)
		guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket_guides.add_child(guide)
		guide.global_position = socket.global_position


func _get_guide_material(socket_name: StringName) -> StandardMaterial3D:
	var role := &"effect"
	if String(socket_name).begins_with("Muzzle"):
		role = &"muzzle"
	elif String(socket_name).begins_with("Engine"):
		role = &"engine"
	elif String(socket_name).begins_with("Upgrade"):
		role = &"upgrade"
	if _guide_materials.has(role):
		return _guide_materials[role] as StandardMaterial3D
	var color := SOCKET_GUIDE_COLORS[role] as Color
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	_guide_materials[role] = material
	return material
