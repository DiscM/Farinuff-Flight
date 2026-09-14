extends RefCounted
class_name ShipMotion3D
## Plays Blender's rigid-bone clips on the actor's physics clock. Gameplay
## remains the authority for release frames, sockets, pause and cancellation.

var animation_player: AnimationPlayer
var model_root: Node3D
var skeleton: Skeleton3D
var current_clip: StringName = &"cruise"
var rest_clip: StringName = &"cruise"
var _remaining := 0.0
var _hold := false
var _clips: Dictionary[StringName, StringName] = {}


func _init(model: Node3D) -> void:
	model_root = model
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	if animation_player == null:
		return
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for full_name in animation_player.get_animation_list():
		var clip := StringName(String(full_name).get_file())
		_clips[clip] = full_name
		var animation := animation_player.get_animation(full_name)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in [&"cruise", &"boost"] else Animation.LOOP_NONE
	reset()


func reset() -> void:
	rest_clip = &"cruise"
	play(&"cruise", 0.0, false, 0.0)


func play(clip: StringName, seconds: float = 0.0, hold: bool = false, blend: float = 0.045) -> void:
	if animation_player == null or not _clips.has(clip):
		return
	# Damage never masks a telegraphed release; shader hit feedback still runs.
	if clip == &"hit" and current_clip == &"windup":
		return
	current_clip = clip
	_hold = hold
	var length := animation_player.get_animation(_clips[clip]).length
	_remaining = seconds if seconds > 0.0 else length
	var rate := length / seconds if seconds > 0.0 else 1.0
	animation_player.play(_clips[clip], blend, rate)
	# Explicit restart makes repeated volleys responsive instead of queuing.
	animation_player.seek(0.0, true)
	_update_bones()


func set_boost(enabled: bool) -> void:
	var desired: StringName = &"boost" if enabled else &"cruise"
	if rest_clip == desired:
		return
	rest_clip = desired
	play(rest_clip)


func shot() -> void:
	play(&"boost_attack" if rest_clip == &"boost" else &"attack")


func advance(delta: float) -> void:
	if animation_player == null:
		return
	animation_player.advance(delta)
	_update_bones()
	if current_clip == rest_clip:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0 and not _hold:
		play(rest_clip)


func follow(source: ShipMotion3D) -> void:
	if skeleton == null or source.skeleton == null:
		return
	rest_clip = source.rest_clip
	current_clip = source.current_clip
	if animation_player.is_playing():
		animation_player.stop(true)
	# Copy the blended pose, not just the clip time: mounted modules must also
	# follow the short transition between cruise, recoil and folded boost wings.
	for index in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(index, source.skeleton.get_bone_pose_position(index))
		skeleton.set_bone_pose_rotation(index, source.skeleton.get_bone_pose_rotation(index))
		skeleton.set_bone_pose_scale(index, source.skeleton.get_bone_pose_scale(index))
	_update_bones()


func _update_bones() -> void:
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()


static func socket_transform(socket: Node3D) -> Transform3D:
	var attachment := socket.get_parent() as BoneAttachment3D
	if attachment != null:
		var rig := attachment.get_parent() as Skeleton3D
		if rig != null and attachment.bone_idx >= 0:
			# BoneAttachment notifications can be deferred until rendering. Resolve
			# the current physics pose now so projectiles leave the actual barrel.
			return rig.global_transform * rig.get_bone_global_pose(attachment.bone_idx) * socket.transform
	return socket.global_transform
