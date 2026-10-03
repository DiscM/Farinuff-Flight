extends RefCounted
## A committed curved flight path with velocity continuity at both ends.
## The actor supplies bounded points and applies collision-envelope clamping.

const Tactics := preload("res://systems/enemy_tactics_3d.gd")
var duration := 0.0
var target := Vector3.ZERO
var exit_velocity := Vector3.ZERO
var _origin := Vector3.ZERO
var _control := Vector3.ZERO
var _entry_velocity := Vector3.ZERO


func begin(origin: Vector3, control: Vector3, destination: Vector3, seconds: float, entry: Vector3, exit: Vector3) -> void:
	_origin = origin
	_control = control
	target = destination
	duration = seconds
	_entry_velocity = entry
	exit_velocity = exit


func sample(remaining: float, dodge: bool) -> Vector3:
	if duration <= 0.0:
		return target
	var progress := clampf(1.0 - remaining / duration, 0.0, 1.0)
	var t := 1.0 - pow(1.0 - progress, 3.0) if dodge else smoothstep(0.0, 1.0, progress)
	var point := _origin.lerp(_control, t).lerp(_control.lerp(target, t), t)
	var initial_velocity := (_control - _origin) * 6.0 / duration if dodge else Vector3.ZERO
	return Tactics.carry_path_velocity(point, progress, duration, _entry_velocity, exit_velocity, initial_velocity, 0.08 if dodge else 0.18)
